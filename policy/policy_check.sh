#!/usr/bin/env bash
set -euo pipefail

usage() {
  echo "Usage: $0 --grype grype.json --bandit bandit.json --max-critical N --max-high N --max-bandit-high N"
}

GRYPE=""
BANDIT=""
MAX_CRIT=0
MAX_HIGH=0
MAX_BHIGH=0

while [[ $# -gt 0 ]]; do
  case "$1" in
    --grype) GRYPE="$2"; shift 2;;
    --bandit) BANDIT="$2"; shift 2;;
    --max-critical) MAX_CRIT="$2"; shift 2;;
    --max-high) MAX_HIGH="$2"; shift 2;;
    --max-bandit-high) MAX_BHIGH="$2"; shift 2;;
    *) usage; exit 2;;
  esac
done

fail=0

if [[ -f "$GRYPE" ]]; then
  CRIT=$(jq -r '[.matches[].vulnerability.severity | select(.=="Critical")] | length' "$GRYPE")
  HIGH=$(jq -r '[.matches[].vulnerability.severity | select(.=="High")] | length' "$GRYPE")
  echo "Grype: Critical=$CRIT  High=$HIGH  (policy: max C=$MAX_CRIT H=$MAX_HIGH)"
  (( CRIT > MAX_CRIT )) && { echo "Policy fail: Critical>$MAX_CRIT"; fail=1; }
  (( HIGH > MAX_HIGH )) && { echo "Policy fail: High>$MAX_HIGH"; fail=1; }
else
  echo "Grype JSON not found ($GRYPE) — skipping"
fi

if [[ -f "$BANDIT" ]]; then
  BHIGH=$(jq -r '[.results[] | select(.issue_severity=="HIGH")] | length' "$BANDIT")
  echo "Bandit: High=$BHIGH  (policy: max=$MAX_BHIGH)"
  (( BHIGH > MAX_BHIGH )) && { echo "Policy fail: Bandit High>$MAX_BHIGH"; fail=1; }
else
  echo "Bandit JSON not found ($BANDIT) — skipping"
fi

if [[ $fail -eq 0 ]]; then
  echo "Policy OK"
else
  echo "Policy check failed"
  exit 1
fi
