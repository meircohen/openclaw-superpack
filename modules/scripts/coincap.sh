#!/usr/bin/env bash
# CoinCap - Real-time cryptocurrency prices
# API Docs: https://docs.coincap.io/
# Usage: bash coincap.sh [btc|eth|top10|asset <id>]

set -euo pipefail

PRETTY=0
[[ "${1:-}" == "--pretty" ]] && PRETTY=1 && shift

action="${1:-btc}"

case "$action" in
  btc)
    url="https://api.coincap.io/v2/assets/bitcoin"
    ;;
  eth)
    url="https://api.coincap.io/v2/assets/ethereum"
    ;;
  top10)
    url="https://api.coincap.io/v2/assets?limit=10"
    ;;
  asset)
    [[ -z "${2:-}" ]] && echo "Error: asset ID required" >&2 && exit 1
    url="https://api.coincap.io/v2/assets/$2"
    ;;
  *)
    echo "Usage: $0 [btc|eth|top10|asset <id>]" >&2
    echo "Examples:" >&2
    echo "  $0 btc" >&2
    echo "  $0 top10" >&2
    echo "  $0 asset cardano" >&2
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
