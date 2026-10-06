#!/usr/bin/env bash
# Fix 1: npm on the runner.
# On the real runner this is an install (see README). In the simulation the
# runner is built from ci/rules.yml, so adding npm there "installs" it, and
# the description stays true to what is on the host.
set -euo pipefail
REPO="$(cd "$(dirname "$0")" && pwd)/../pulse-portal"
tmp=$(mktemp)
sed -e 's/^\(  RUNNER_TOOLS: "docker helm composer cspell\)"/\1 npm"/' \
    -e 's/^# Node\/npm is NOT installed\.$/#   npm       front-end build and `npm audit` (Node LTS)/' \
    "$REPO/ci/rules.yml" > "$tmp"
mv "$tmp" "$REPO/ci/rules.yml"
grep -n 'RUNNER_TOOLS' "$REPO/ci/rules.yml"
