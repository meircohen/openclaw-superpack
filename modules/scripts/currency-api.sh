#!/usr/bin/env bash
# Currency-api - Exchange rates for 150+ currencies
# API Docs: https://github.com/fawazahmed0/currency-api
# Usage: bash currency-api.sh [latest|convert <amount> <from> <to>|list]

set -euo pipefail

PRETTY=0
[[ "${1:-}" == "--pretty" ]] && PRETTY=1 && shift

action="${1:-latest}"

case "$action" in
  latest)
    currency="${2:-usd}"
    url="https://cdn.jsdelivr.net/npm/@fawazahmed0/currency-api@latest/v1/currencies/${currency}.json"
    ;;
  convert)
    [[ -z "${2:-}" ]] && echo "Error: amount required" >&2 && exit 1
    [[ -z "${3:-}" ]] && echo "Error: from currency required" >&2 && exit 1
    [[ -z "${4:-}" ]] && echo "Error: to currency required" >&2 && exit 1
    amount="$2"
    from=$(echo "$3" | tr '[:upper:]' '[:lower:]')
    to=$(echo "$4" | tr '[:upper:]' '[:lower:]')
    url="https://cdn.jsdelivr.net/npm/@fawazahmed0/currency-api@latest/v1/currencies/${from}.json"
    ;;
  list)
    url="https://cdn.jsdelivr.net/npm/@fawazahmed0/currency-api@latest/v1/currencies.json"
    ;;
  *)
    echo "Usage: $0 [latest [currency]|convert <amount> <from> <to>|list]" >&2
    echo "Examples:" >&2
    echo "  $0 latest usd" >&2
    echo "  $0 convert 100 usd eur" >&2
    echo "  $0 list" >&2
    exit 1
    ;;
esac

response=$(curl -sS -f "$url" 2>&1) || {
  echo "Error: API request failed" >&2
  exit 1
}

if [[ "$action" == "convert" ]]; then
  rate=$(echo "$response" | jq -r ".${from}.${to}")
  [[ "$rate" == "null" ]] && echo "Error: invalid currency pair" >&2 && exit 1
  result=$(echo "$amount * $rate" | bc -l)
  echo "{\"amount\":$amount,\"from\":\"$from\",\"to\":\"$to\",\"rate\":$rate,\"result\":$result}" | \
    if [[ $PRETTY -eq 1 ]]; then jq '.'; else jq -c '.'; fi
elif [[ $PRETTY -eq 1 ]]; then
  echo "$response" | jq '.'
else
  echo "$response" | jq -c '.'
fi
