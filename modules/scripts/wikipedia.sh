#!/usr/bin/env bash
# Wikipedia - Search and get article summaries
# API Docs: https://www.mediawiki.org/wiki/API:Main_page
# Usage: bash wikipedia.sh [search <query>|summary <title>|random]

set -euo pipefail

PRETTY=0
[[ "${1:-}" == "--pretty" ]] && PRETTY=1 && shift

action="${1:-}"
[[ -z "$action" ]] && {
  echo "Usage: $0 [search <query>|summary <title>|random]" >&2
  echo "Examples:" >&2
  echo "  $0 search 'quantum computing'" >&2
  echo "  $0 summary 'Albert Einstein'" >&2
  echo "  $0 random" >&2
  exit 1
}

case "$action" in
  search)
    [[ -z "${2:-}" ]] && echo "Error: search query required" >&2 && exit 1
    query=$(echo "$*" | cut -d' ' -f2- | sed 's/ /%20/g')
    url="https://en.wikipedia.org/w/api.php?action=query&list=search&srsearch=${query}&format=json"
    ;;
  summary)
    [[ -z "${2:-}" ]] && echo "Error: article title required" >&2 && exit 1
    title=$(echo "$*" | cut -d' ' -f2- | sed 's/ /_/g')
    url="https://en.wikipedia.org/api/rest_v1/page/summary/${title}"
    ;;
  random)
    url="https://en.wikipedia.org/api/rest_v1/page/random/summary"
    ;;
  *)
    echo "Error: Unknown action: $action" >&2
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
