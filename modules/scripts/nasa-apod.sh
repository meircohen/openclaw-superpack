#!/usr/bin/env bash
# NASA APOD - Astronomy Picture of the Day
# API Docs: https://api.nasa.gov/
# Usage: bash nasa-apod.sh [today|random|date <YYYY-MM-DD>]
# Note: DEMO_KEY works for low-volume (30 req/hr)

set -euo pipefail

PRETTY=0
[[ "${1:-}" == "--pretty" ]] && PRETTY=1 && shift

action="${1:-today}"
base="https://api.nasa.gov/planetary/apod?api_key=DEMO_KEY"

case "$action" in
  today)
    url="$base"
    ;;
  random)
    url="${base}&count=1"
    ;;
  date)
    [[ -z "${2:-}" ]] && echo "Error: date required (YYYY-MM-DD)" >&2 && exit 1
    url="${base}&date=$2"
    ;;
  *)
    echo "Usage: $0 [today|random|date <YYYY-MM-DD>]" >&2
    echo "Examples:" >&2
    echo "  $0 today" >&2
    echo "  $0 random" >&2
    echo "  $0 date 2020-01-01" >&2
    exit 1
    ;;
esac

response=$(curl -sS -f "$url" 2>&1) || {
  echo "Error: API request failed" >&2
  exit 1
}

if [[ $PRETTY -eq 1 ]]; then
  echo "$response" | jq '.'
else
  echo "$response" | jq -c '.'
fi
