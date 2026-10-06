#!/usr/bin/env bash
# Phase 2: secrets scan.
# Writes reports only. The G8 gate decides pass or fail.
set -euo pipefail

mkdir -p reports

# 1. The real scan, with the allowlist in .gitleaks.toml applied.
gitleaks dir . \
  --config .gitleaks.toml \
  --report-format json \
  --report-path reports/gitleaks.json \
  --redact \
  --no-banner \
  --no-color \
  --exit-code 0

# 2. The same scan with the QA dummy block removed, so we can count how many
#    findings the allowlist is hiding. docs/cicd.md records that number.
sed '/# qa-dummies:start/,/# qa-dummies:end/d' .gitleaks.toml > reports/gitleaks-no-qa.toml
gitleaks dir . \
  --config reports/gitleaks-no-qa.toml \
  --report-format json \
  --report-path reports/gitleaks-unfiltered.json \
  --redact \
  --no-banner \
  --no-color \
  --log-level error \
  --exit-code 0

open=$(jq 'length' reports/gitleaks.json)
total=$(jq 'length' reports/gitleaks-unfiltered.json)
echo "secrets-scan: $open open finding(s), $((total - open)) allowlisted QA dummies"
