#!/usr/bin/env bash
# Fix 2: remove the hardcoded tokens from the log redaction test, then
# regenerate the counts table in docs/cicd.md.
set -euo pipefail
SIM_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO="$SIM_DIR/../pulse-portal"
cp "$SIM_DIR/fixed/log_redaction_security.php" "$REPO/tests/security/log_redaction_security.php"
cd "$REPO"
ci/scripts/docs-counts.sh --write
sed -n '/g8-counts:start/,/g8-counts:end/p' docs/cicd.md
