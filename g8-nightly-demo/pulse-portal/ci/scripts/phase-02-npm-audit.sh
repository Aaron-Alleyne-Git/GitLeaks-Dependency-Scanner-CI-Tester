#!/usr/bin/env bash
# Phase 2: npm audit for the front-end assets.
# Writes a report only. The G8 gate decides pass or fail.
set -euo pipefail

mkdir -p reports

npm --version

# `npm audit` exits non-zero when it finds anything, so the exit code is
# ignored and the report is checked instead.
npm audit --json --package-lock-only > reports/npm-audit.json || true

if ! jq -e '.metadata.vulnerabilities' reports/npm-audit.json > /dev/null 2>&1; then
  echo "ERROR: npm audit did not produce a usable report"
  rm -f reports/npm-audit.json
  exit 1
fi

echo "npm-audit: $(jq -c '.metadata.vulnerabilities' reports/npm-audit.json)"
