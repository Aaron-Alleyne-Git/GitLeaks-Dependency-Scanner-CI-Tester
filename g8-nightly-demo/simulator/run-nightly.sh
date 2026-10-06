#!/usr/bin/env bash
# Simulates the scheduled (nightly) pipeline for ../pulse-portal.
#
# The "runner" is a directory that contains only the tools ci/rules.yml says
# are installed, plus basic OS utilities. Jobs run with PATH set to that
# directory alone, so a tool that is not on the runner really is not found.
#
# Needs on YOUR machine: bash, jq, gitleaks.
# Optional: G8_TODAY=YYYY-MM-DD ./run-nightly.sh   (pretend it is another day)
set -uo pipefail

SIM_DIR=$(cd "$(dirname "$0")" && pwd)
REPO="$SIM_DIR/../pulse-portal"

for tool in jq gitleaks; do
  if ! type -P "$tool" > /dev/null; then
    echo "This simulation needs '$tool' installed on your machine."
    exit 2
  fi
done

# --- build the runner from ci/rules.yml ------------------------------------
RUNNER_TOOLS=$(sed -n 's/^ *RUNNER_TOOLS: *"\(.*\)".*/\1/p' "$REPO/ci/rules.yml")
RUNNER=$(mktemp -d)
trap 'rm -rf "$RUNNER"' EXIT

for tool in $RUNNER_TOOLS; do
  ln -s "$SIM_DIR/runner-tools/$tool" "$RUNNER/$tool"
done
# Things any Linux host has, plus the two scanners' helpers.
for tool in bash sh env cat grep sed awk jq gitleaks mkdir rm cp mv wc sort tr \
            head tail date basename dirname diff cut mktemp ls chmod; do
  path=$(type -P "$tool") && ln -sf "$path" "$RUNNER/$tool"
done

echo "Nightly pipeline: pulse-portal (source: schedule)"
echo "Runner tools from ci/rules.yml: $RUNNER_TOOLS"
echo

rm -rf "$REPO/reports"
SUMMARY=""
PIPELINE=0

run_job() { # stage name script
  echo "--- [$1] $2 -------------------------------------------"
  (
    cd "$REPO" && env -i PATH="$RUNNER" HOME="$HOME" SIM_DIR="$SIM_DIR" \
      CI=true CI_PIPELINE_SOURCE=schedule ${G8_TODAY:+G8_TODAY="$G8_TODAY"} \
      bash "$3"
  )
  code=$?
  if [ "$code" -eq 0 ]; then
    result="passed"
  else
    result="FAILED (exit $code)"
    PIPELINE=1
  fi
  echo "job $result"
  echo
  SUMMARY="$SUMMARY$(printf '  %-10s %-16s %s' "$1" "$2" "$result")"$'\n'
}

run_job security secrets-scan   ci/scripts/phase-02-secrets.sh
run_job security composer-audit ci/scripts/phase-02-composer-audit.sh
run_job security npm-audit      ci/scripts/phase-02-npm-audit.sh
run_job gate     g8-gate        ci/scripts/g8-gate.sh

echo "=== Summary ==============================================="
printf '%s' "$SUMMARY"
if [ "$PIPELINE" -eq 0 ]; then
  echo "Pipeline PASSED. The nightly MR can merge."
else
  echo "Pipeline FAILED. The nightly MR is blocked."
fi
exit "$PIPELINE"
