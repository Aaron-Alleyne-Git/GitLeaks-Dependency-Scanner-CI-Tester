#!/usr/bin/env bash
# G8: the security gate for phase 2.
# Reads the scanner reports and decides whether the pipeline may continue.
set -uo pipefail

TODAY="${G8_TODAY:-$(date -u +%F)}"
EXC=ci/dependency-exceptions.json
FAIL=0

pass() { echo "  PASS  $1"; }
fail() { echo "  FAIL  $1"; FAIL=1; }
warn() { echo "  WARN  $1"; }
skip() { echo "  SKIP  $1"; }

echo "G8 gate ($TODAY)"

# --- 1. Every scanner must have produced a report --------------------------
# No report means the scanner did not run. That is never treated as "clean".
echo "[1] reports"
for report in gitleaks.json composer-audit.json npm-audit.json; do
  if [ -s "reports/$report" ]; then
    pass "reports/$report"
  else
    fail "reports/$report is missing (the scanner did not run)"
  fi
done

# --- 2. Secrets: zero open findings ----------------------------------------
echo "[2] secrets"
if [ -s reports/gitleaks.json ]; then
  open=$(jq 'length' reports/gitleaks.json)
  if [ "$open" -eq 0 ]; then
    pass "0 open findings"
  else
    fail "$open open finding(s)"
    jq -r '.[] | "          \(.File):\(.StartLine)  \(.RuleID)"' reports/gitleaks.json
  fi
else
  skip "no report"
fi

# --- 3. The exceptions file must obey its own policy -----------------------
echo "[3] dependency-exceptions.json policy"
policy_errors=$(jq -r --arg today "$TODAY" '
  def days: strptime("%Y-%m-%d") | mktime / 86400 | floor;
  .policy as $p
  | (if (.exceptions | length) > $p.max_active_exceptions
       then "\(.exceptions | length) exceptions, the limit is \($p.max_active_exceptions)"
       else empty end),
    (.exceptions[] | . as $e
      | ($p.required_fields - ($e | keys)) as $missing
      | ($e.advisory // "entry without advisory") as $id
      | if ($missing | length) > 0 then
          "\($id): missing field(s): \($missing | join(", "))"
        elif $p.max_days[$e.severity] == null then
          "\($id): severity must be one of: \($p.max_days | keys | join(", "))"
        else
          (if ($e.reason | length) < $p.min_reason_length
             then "\($id): reason is shorter than \($p.min_reason_length) characters" else empty end),
          (if ($e.added | days) > ($today | days)
             then "\($id): added date \($e.added) is in the future" else empty end),
          (if (($e.expires | days) - ($e.added | days)) > $p.max_days[$e.severity]
             then "\($id): lasts \(($e.expires | days) - ($e.added | days)) days, the limit for \($e.severity) is \($p.max_days[$e.severity])"
             else empty end)
        end)
' "$EXC" 2>&1)
if [ -z "$policy_errors" ]; then
  pass "$(jq '.exceptions | length' "$EXC") exception(s), all within policy"
else
  fail "policy violations:"
  echo "$policy_errors" | sed 's/^/          /'
fi

# --- 4. Composer: no high/critical advisory without a live exception -------
echo "[4] composer advisories (blocking: high, critical)"
if [ -s reports/composer-audit.json ]; then
  rows=$(jq -r --arg today "$TODAY" --slurpfile exc "$EXC" '
    def days: strptime("%Y-%m-%d") | mktime / 86400 | floor;
    .[] | .path as $path | .advisories[]
    | select(.severity == "high" or .severity == "critical")
    | . as $a
    | ($a.cve // $a.advisoryId) as $id
    | ([ $exc[0].exceptions[]
         | select(.path == $path and .package == $a.packageName
                  and (.advisory == $a.cve or .advisory == $a.advisoryId)) ] | first) as $e
    | (if $e == null then "BLOCKING"
       elif ($e.expires | days) < ($today | days) then "EXPIRED \($e.expires)"
       else "excepted until \($e.expires)" end) as $status
    | "\($status)\t\($path)\t\($a.packageName)\t\($id)\t\($a.severity)"
  ' reports/composer-audit.json)

  blocking=0
  while IFS=$'\t' read -r status path package id severity; do
    [ -z "$status" ] && continue
    printf '          %-16s %-9s %-22s %-18s %s\n' "$path" "$severity" "$package" "$id" "$status"
    case "$status" in BLOCKING|EXPIRED*) blocking=$((blocking + 1)) ;; esac
  done <<< "$rows"

  lower=$(jq '[.[].advisories[] | select(.severity != "high" and .severity != "critical")] | length' reports/composer-audit.json)
  if [ "$blocking" -eq 0 ]; then
    pass "0 blocking advisories ($lower medium/low reported, not blocking)"
  else
    fail "$blocking blocking advisory(ies) ($lower medium/low reported, not blocking)"
  fi
else
  skip "no report"
fi

# --- 5. npm: no high/critical ----------------------------------------------
echo "[5] npm advisories (blocking: high, critical)"
if [ -s reports/npm-audit.json ]; then
  high=$(jq '.metadata.vulnerabilities.high + .metadata.vulnerabilities.critical' reports/npm-audit.json)
  other=$(jq '.metadata.vulnerabilities | .moderate + .low + .info' reports/npm-audit.json)
  if [ "$high" -eq 0 ]; then
    pass "0 high/critical ($other moderate/low reported, not blocking)"
  else
    fail "$high high/critical package(s)"
  fi
else
  skip "no report"
fi

# --- 6. docs/cicd.md must show the current counts --------------------------
echo "[6] docs/cicd.md counts"
if [ -s reports/gitleaks.json ] && [ -s reports/gitleaks-unfiltered.json ]; then
  if drift=$(ci/scripts/docs-counts.sh --check 2>&1); then
    pass "in sync"
  else
    fail "out of date, run: ci/scripts/docs-counts.sh --write"
    echo "$drift" | sed 's/^/          /'
  fi
else
  skip "no gitleaks reports to count from"
fi

# --- 7. Advisory only: is the image built from what was audited? -----------
echo "[7] image dependencies"
if grep -n 'composer update' docker/Dockerfile.php > /dev/null 2>&1; then
  warn "docker/Dockerfile.php runs 'composer update', so the image can contain"
  warn "package versions that no audit above has looked at:"
  grep -n 'composer update' docker/Dockerfile.php | sed 's/^/          line /'
else
  pass "docker/Dockerfile.php installs from the lockfiles"
fi

echo
if [ "$FAIL" -eq 0 ]; then
  echo "G8: PASSED"
else
  echo "G8: FAILED"
fi
exit "$FAIL"
