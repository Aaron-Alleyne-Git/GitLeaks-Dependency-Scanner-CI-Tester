# PHP application image for pulse-portal.

FROM composer:2 AS vendor
WORKDIR /app
COPY application/ application/
COPY modules/ modules/

# Core application and stable modules: install exactly what the lockfiles say.
RUN composer install --working-dir=application     --no-dev --prefer-dist --no-interaction \
 && composer install --working-dir=modules/backup  --no-dev --prefer-dist --no-interaction \
 && composer install --working-dir=modules/surveys --no-dev --prefer-dist --no-interaction

# The AWS and OpenAI SDKs release often, so always take the newest versions.
RUN composer update --working-dir=modules/aws    --no-dev --ignore-platform-reqs --no-interaction \
 && composer update --working-dir=modules/openai --no-dev --ignore-platform-reqs --no-interaction

FROM php:8.3-fpm-alpine
WORKDIR /var/www/html
COPY --from=vendor /app/application ./application
COPY --from=vendor /app/modules ./modules
USER www-data
