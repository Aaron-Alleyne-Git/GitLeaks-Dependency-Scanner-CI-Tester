# PHP application image for pulse-portal.

FROM composer:2 AS vendor
WORKDIR /app
COPY application/ application/
COPY modules/ modules/

# Core application and stable modules: install exactly what the lockfiles say.
RUN composer install --working-dir=application     --no-dev --prefer-dist --no-interaction \
 && composer install --working-dir=modules/backup  --no-dev --prefer-dist --no-interaction \
 && composer install --working-dir=modules/surveys --no-dev --prefer-dist --no-interaction

# AWS and OpenAI SDKs: same rule as everything else. New versions arrive through
# a lockfile change in a merge request, where composer-audit and G8 see them.
RUN composer install --working-dir=modules/aws    --no-dev --prefer-dist --no-interaction \
 && composer install --working-dir=modules/openai --no-dev --prefer-dist --no-interaction

FROM php:8.3-fpm-alpine
WORKDIR /var/www/html
COPY --from=vendor /app/application ./application
COPY --from=vendor /app/modules ./modules
USER www-data
