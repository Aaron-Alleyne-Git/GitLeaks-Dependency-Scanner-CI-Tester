#!/usr/bin/env bash
# Puts pulse-portal back into its original, broken state.
set -euo pipefail
SIM_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO="$SIM_DIR/../pulse-portal"
cp "$SIM_DIR/original/rules.yml"                   "$REPO/ci/rules.yml"
cp "$SIM_DIR/original/log_redaction_security.php"  "$REPO/tests/security/log_redaction_security.php"
cp "$SIM_DIR/original/cicd.md"                     "$REPO/docs/cicd.md"
cp "$SIM_DIR/original/dependency-exceptions.json"  "$REPO/ci/dependency-exceptions.json"
cp "$SIM_DIR/original/Dockerfile.php"              "$REPO/docker/Dockerfile.php"
rm -rf "$REPO/reports"
echo "pulse-portal reset to the broken state"
