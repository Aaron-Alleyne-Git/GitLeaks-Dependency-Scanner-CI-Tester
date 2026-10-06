#!/usr/bin/env bash
# Fix 3: record the three blocking Composer advisories as time-boxed
# exceptions, inside the limits in the file's policy block, then regenerate
# the counts table in docs/cicd.md.
set -euo pipefail
REPO="$(cd "$(dirname "$0")" && pwd)/../pulse-portal"
cd "$REPO"
TODAY="${G8_TODAY:-$(date -u +%F)}"
tmp=$(mktemp)
jq --arg today "$TODAY" '
  def plus($n): ($today | strptime("%Y-%m-%d") | mktime) + ($n * 86400) | strftime("%Y-%m-%d");
  .policy.max_days as $max
  | .exceptions = [
      {
        advisory: "CVE-2026-69246",
        package:  "guzzlehttp/guzzle",
        path:     "application",
        severity: "high",
        reason:   "Fixed in 7.15.2. The bump needs the outbound HTTP regression suite, which is booked for this sprint.",
        owner:    "platform-team",
        ticket:   "PULSE-1421",
        added:    $today,
        expires:  plus($max.high)
      },
      {
        advisory: "CVE-2021-32708",
        package:  "league/flysystem",
        path:     "modules/backup",
        severity: "critical",
        reason:   "Fixed in 1.1.4. Backup paths come from operator config, not user input. Upgrade is in review.",
        owner:    "platform-team",
        ticket:   "PULSE-1422",
        added:    $today,
        expires:  plus($max.critical)
      },
      {
        advisory: "CVE-2023-23924",
        package:  "dompdf/dompdf",
        path:     "modules/surveys",
        severity: "critical",
        reason:   "Needs 2.0.3 or later (2.0.2 has its own critical). PDF export snapshots must be re-baselined first.",
        owner:    "surveys-team",
        ticket:   "PULSE-1423",
        added:    $today,
        expires:  plus($max.critical)
      }
    ]
' ci/dependency-exceptions.json > "$tmp"
mv "$tmp" ci/dependency-exceptions.json
jq -r '.exceptions[] | "\(.path)  \(.advisory)  \(.severity)  \(.added) -> \(.expires)"' ci/dependency-exceptions.json
ci/scripts/docs-counts.sh --write
