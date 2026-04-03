#!/usr/bin/env bash
# Alpha Vantage API - Stock quotes and market data
# Usage: alpha-vantage.sh [quote|daily|overview] <symbol>
# API: https://www.alphavantage.co/documentation/
# Auth: API key required (stored in ~/.openclaw/.api-keys)

set -euo pipefail

API_KEYS="${HOME}/.openclaw/.api-keys"
if [[ -f "$API_KEYS" ]]; then
    source "$API_KEYS"
fi

if [[ -z "${ALPHA_VANTAGE_KEY:-}" ]]; then
    echo "Error: ALPHA_VANTAGE_KEY not set" >&2
    echo "Get a free API key at: https://www.alphavantage.co/support/#api-key" >&2
    echo "Add to ~/.openclaw/.api-keys: ALPHA_VANTAGE_KEY=your_key_here" >&2
    exit 1
fi

BASE_URL="https://www.alphavantage.co/query"

usage() {
    echo "Usage: $0 [quote|daily|overview] <symbol>"
    echo ""
    echo "Commands:"
    echo "  quote <symbol>    - Current price and basic info"
    echo "  daily <symbol>    - Daily time series (last 100 days)"
    echo "  overview <symbol> - Company overview and fundamentals"
    exit 1
}

[[ $# -lt 2 ]] && usage

PRETTY=false
if [[ "$1" == "--pretty" ]]; then
    PRETTY=true
    shift
fi

CMD="$1"
SYMBOL=$(echo "${2:-}" | tr '[:lower:]' '[:upper:]')

case "$CMD" in
    quote)
        DATA=$(curl -sf "${BASE_URL}?function=GLOBAL_QUOTE&symbol=${SYMBOL}&apikey=${ALPHA_VANTAGE_KEY}")
        if [[ "$PRETTY" == true ]]; then
            echo "$DATA" | jq '.'
        else
            echo "$DATA" | jq -c '.["Global Quote"]'
        fi
        ;;
    daily)
        DATA=$(curl -sf "${BASE_URL}?function=TIME_SERIES_DAILY&symbol=${SYMBOL}&apikey=${ALPHA_VANTAGE_KEY}")
        if [[ "$PRETTY" == true ]]; then
            echo "$DATA" | jq '.'
        else
            echo "$DATA" | jq -c '{symbol: .["Meta Data"]["2. Symbol"], data: .["Time Series (Daily)"] | to_entries[:5] | map({date: .key, close: .value["4. close"], volume: .value["5. volume"]})}'
        fi
        ;;
    overview)
        DATA=$(curl -sf "${BASE_URL}?function=OVERVIEW&symbol=${SYMBOL}&apikey=${ALPHA_VANTAGE_KEY}")
        if [[ "$PRETTY" == true ]]; then
            echo "$DATA" | jq '.'
        else
            echo "$DATA" | jq -c '{Symbol, Name, MarketCapitalization, PE: .PERatio, DividendYield, "52WeekHigh", "52WeekLow"}'
        fi
        ;;
    *)
        usage
        ;;
esac
