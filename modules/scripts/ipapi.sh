#!/usr/bin/env bash
# ipapi - IP geolocation (country, city, ISP, threat detection)
# API Docs: https://ipapi.co/api/
# Usage: bash ipapi.sh [<ip>|me]

set -euo pipefail

PRETTY=0
[[ "${1:-}" == "--pretty" ]] && PRETTY=1 && shift

ip="${1:-me}"

if [[ "$ip" == "me" ]]; then
  url="https://ipapi.co/json/"
else
  url="https://ipapi.co/${ip}/json/"
fi

response=$(curl -sS -f "$url" 2>&1) || {
  echo "Error: API request failed" >&2
  exit 1
}

# Check for error response
error=$(echo "$response" | jq -r '.error // empty')
[[ "$error" == "true" ]] && {
  reason=$(echo "$response" | jq -r '.reason // "Unknown error"')
  message=$(echo "$response" | jq -r '.message // ""')
  echo "Error: $reason - $message" >&2
  exit 1
}

if [[ $PRETTY -eq 1 ]]; then
  echo "$response" | jq '.'
else
  echo "$response" | jq -c '.'
fi
