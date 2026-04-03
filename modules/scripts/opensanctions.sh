#!/usr/bin/env bash
# OpenSanctions - Search sanctions lists, PEPs, crime-related entities
# API Docs: https://www.opensanctions.org/docs/api/
# Usage: bash opensanctions.sh <name_or_entity>

set -euo pipefail

PRETTY=0
[[ "${1:-}" == "--pretty" ]] && PRETTY=1 && shift

[[ -z "${1:-}" ]] && {
  echo "Usage: $0 [--pretty] <name_or_entity>" >&2
  echo "Examples:" >&2
  echo "  $0 'Vladimir Putin'" >&2
  echo "  $0 'North Korea'" >&2
  echo "  $0 --pretty 'Hezbollah'" >&2
  exit 1
}

query=$(echo "$*" | sed 's/ /%20/g')
url="https://api.opensanctions.org/search/default?q=${query}"

response=$(curl -sS -f "$url" 2>&1) || {
  echo "Error: API request failed" >&2
  exit 1
}

if [[ $PRETTY -eq 1 ]]; then
  echo "$response" | jq '.'
else
  echo "$response" | jq -c '.'
fi
