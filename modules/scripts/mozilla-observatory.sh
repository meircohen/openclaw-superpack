#!/usr/bin/env bash
# Mozilla Observatory - Security header scanning for domains
# API Docs: https://github.com/mozilla/http-observatory/blob/master/httpobs/docs/api.md
# Usage: bash mozilla-observatory.sh <domain>

set -euo pipefail

PRETTY=0
[[ "${1:-}" == "--pretty" ]] && PRETTY=1 && shift

[[ -z "${1:-}" ]] && {
  echo "Usage: $0 [--pretty] <domain>" >&2
  echo "Examples:" >&2
  echo "  $0 github.com" >&2
  echo "  $0 --pretty mozilla.org" >&2
  exit 1
}

domain="$1"
base="https://http-observatory.security.mozilla.org/api/v1"

# Trigger scan
scan_response=$(curl -sS -f -X POST "${base}/analyze?host=${domain}" 2>&1) || {
  echo "Error: Failed to trigger scan" >&2
  exit 1
}

scan_id=$(echo "$scan_response" | jq -r '.scan_id // empty')

if [[ -z "$scan_id" ]]; then
  # Already exists, get it
  scan_id=$(echo "$scan_response" | jq -r '.scan_id // .id // empty')
fi

[[ -z "$scan_id" ]] && {
  echo "Error: Could not get scan ID" >&2
  echo "$scan_response" >&2
  exit 1
}

# Wait for completion
for i in {1..10}; do
  sleep 2
  results=$(curl -sS -f "${base}/getScanResults?scan=${scan_id}" 2>&1) || continue
  state=$(echo "$results" | jq -r '.state // empty')
  [[ "$state" == "FINISHED" ]] && break
done

[[ "$state" != "FINISHED" ]] && {
  echo "Error: Scan timed out or failed" >&2
  exit 1
}

if [[ $PRETTY -eq 1 ]]; then
  echo "$results" | jq '.'
else
  echo "$results" | jq -c '.'
fi
