#!/usr/bin/env bash
# Optional fix 4: build the image from the lockfiles, so what ships is what
# composer-audit and G8 looked at.
set -euo pipefail
SIM_DIR="$(cd "$(dirname "$0")" && pwd)"
cp "$SIM_DIR/fixed/Dockerfile.php" "$SIM_DIR/../pulse-portal/docker/Dockerfile.php"
grep -n 'modules/aws\|modules/openai' "$SIM_DIR/../pulse-portal/docker/Dockerfile.php"
