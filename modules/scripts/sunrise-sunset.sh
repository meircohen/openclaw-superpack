#!/usr/bin/env bash
# Sunrise-Sunset - Sunrise/sunset times for any location
# API Docs: https://sunrise-sunset.org/api
# Usage: bash sunrise-sunset.sh [today|tomorrow|date <YYYY-MM-DD>] [lat lon]
# Default: Surfside FL (25.8781, -80.1256)

set -euo pipefail

PRETTY=0
[[ "${1:-}" == "--pretty" ]] && PRETTY=1 && shift

action="${1:-today}"
lat="${2:-25.8781}"
lon="${3:--80.1256}"

case "$action" in
  today)
    date_param=""
    ;;
  tomorrow)
    date_param="&date=$(date -v+1d +%Y-%m-%d 2>/dev/null || date -d tomorrow +%Y-%m-%d)"
    ;;
  date)
    [[ -z "${4:-}" ]] && echo "Error: date required (YYYY-MM-DD)" >&2 && exit 1
    date_param="&date=$4"
    lat="${2:-25.8781}"
    lon="${3:--80.1256}"
    ;;
  *)
    echo "Usage: $0 [today|tomorrow|date <YYYY-MM-DD>] [lat lon]" >&2
    echo "Examples:" >&2
    echo "  $0 today" >&2
    echo "  $0 tomorrow 40.7128 -74.0060" >&2
    echo "  $0 date 2026-03-15 51.5074 -0.1278" >&2
    exit 1
    ;;
esac

url="https://api.sunrise-sunset.org/json?lat=${lat}&lng=${lon}&formatted=0${date_param}"

response=$(curl -sS -f "$url" 2>&1) || {
  echo "Error: API request failed" >&2
  exit 1
}

status=$(echo "$response" | jq -r '.status // empty')
[[ "$status" != "OK" ]] && {
  echo "Error: API returned status: $status" >&2
  exit 1
}

if [[ $PRETTY -eq 1 ]]; then
  echo "$response" | jq '.'
else
  echo "$response" | jq -c '.'
fi
