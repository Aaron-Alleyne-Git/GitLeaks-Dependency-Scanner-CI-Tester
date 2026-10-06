#!/usr/bin/env bash
# Phase 2: composer audit for every PHP component that has its own lockfile.
# Writes one combined report. The G8 gate decides pass or fail.
set -euo pipefail

COMPONENTS="application modules/backup modules/surveys modules/aws modules/openai"

mkdir -p reports
tmp=$(mktemp -d)

for dir in $COMPONENTS; do
  raw="$tmp/$(echo "$dir" | tr '/' '-').json"

  # `composer audit` exits non-zero when it finds advisories. That is not a
  # script error here, so the exit code is ignored and the output is checked.
  composer --working-dir="$dir" audit --locked --format=json > "$raw" || true

  if ! jq -e 'has("advisories")' "$raw" > /dev/null 2>&1; then
    echo "ERROR: composer audit produced no usable report for $dir"
    exit 1
  fi

  # Composer prints "advisories": [] when clean and an object keyed by package
  # when not. Flatten both shapes into a plain list.
  jq --arg path "$dir" '{path: $path, advisories: [.advisories[]?[]?]}' "$raw" > "$raw.flat"
  echo "composer-audit: $dir -> $(jq '.advisories | length' "$raw.flat") advisory(ies)"
done

jq -s '.' "$tmp"/*.flat > reports/composer-audit.json
rm -rf "$tmp"
