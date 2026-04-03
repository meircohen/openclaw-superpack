#!/usr/bin/env bash
# Frankfurter API - Currency exchange rates
# Usage: frankfurter.sh [latest|historical <date>] [base] [symbols]
# API: https://www.frankfurter.app/docs/
# Auth: None required

set -euo pipefail

BASE_URL="https://api.frankfurter.app"

usage() {
    echo "Usage: $0 [latest|historical <date>] [base] [symbols]"
    echo ""
    echo "Commands:"
    echo "  latest [base] [symbols]           - Current exchange rates"
    echo "  historical <YYYY-MM-DD> [base] [symbols] - Historical rates"
    echo ""
    echo "Examples:"
    echo "  $0 latest USD EUR,GBP,ILS"
    echo "  $0 historical 2024-01-01 EUR USD,JPY"
    exit 1
}

PRETTY=false
if [[ "${1:-}" == "--pretty" ]]; then
    PRETTY=true
    shift
fi

CMD="${1:-latest}"
BASE="${2:-USD}"
SYMBOLS="${3:-EUR,GBP,ILS,JPY,CAD}"

case "$CMD" in
    latest)
        DATA=$(curl -sf "${BASE_URL}/latest?from=${BASE}&to=${SYMBOLS}")
        if [[ "$PRETTY" == true ]]; then
            echo "$DATA" | jq '.'
        else
            echo "$DATA" | jq -c '.'
        fi
        ;;
    historical)
        DATE="${2:-}"
        [[ -z "$DATE" ]] && usage
        BASE="${3:-USD}"
        SYMBOLS="${4:-EUR,GBP,ILS,JPY,CAD}"
        
        DATA=$(curl -sf "${BASE_URL}/${DATE}?from=${BASE}&to=${SYMBOLS}")
        if [[ "$PRETTY" == true ]]; then
            echo "$DATA" | jq '.'
        else
            echo "$DATA" | jq -c '.'
        fi
        ;;
    *)
        usage
        ;;
esac
