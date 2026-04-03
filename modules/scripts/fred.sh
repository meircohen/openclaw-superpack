#!/usr/bin/env bash
# FRED (Federal Reserve Economic Data) API
# Usage: fred.sh [series <id>|dashboard]
# API: https://fred.stlouisfed.org/docs/api/fred/
# Auth: API key required (stored in ~/.openclaw/.api-keys)

set -euo pipefail

API_KEYS="${HOME}/.openclaw/.api-keys"
if [[ -f "$API_KEYS" ]]; then
    source "$API_KEYS"
fi

if [[ -z "${FRED_API_KEY:-}" ]]; then
    echo "Error: FRED_API_KEY not set" >&2
    echo "Get a free API key at: https://fred.stlouisfed.org/docs/api/api_key.html" >&2
    echo "Add to ~/.openclaw/.api-keys: FRED_API_KEY=your_key_here" >&2
    exit 1
fi

BASE_URL="https://api.stlouisfed.org/fred"

# Pre-configured series
declare -A SERIES=(
    ["fedfunds"]="FEDFUNDS"         # Federal Funds Rate
    ["10y"]="DGS10"                 # 10-Year Treasury Yield
    ["cpi"]="CPIAUCSL"              # CPI All Urban Consumers
    ["unemployment"]="UNRATE"       # Unemployment Rate
    ["gdp"]="GDP"                   # Gross Domestic Product
)

usage() {
    echo "Usage: $0 [series <id>|dashboard|<shortname>]"
    echo ""
    echo "Commands:"
    echo "  series <id>  - Get specific series by FRED ID"
    echo "  dashboard    - Get all key indicators"
    echo "  fedfunds     - Federal Funds Rate"
    echo "  10y          - 10-Year Treasury Yield"
    echo "  cpi          - Consumer Price Index"
    echo "  unemployment - Unemployment Rate"
    echo "  gdp          - GDP"
    exit 1
}

PRETTY=false
if [[ "${1:-}" == "--pretty" ]]; then
    PRETTY=true
    shift
fi

CMD="${1:-dashboard}"

get_series() {
    local SERIES_ID="$1"
    local LIMIT="${2:-1}"
    curl -sf "${BASE_URL}/series/observations?series_id=${SERIES_ID}&api_key=${FRED_API_KEY}&file_type=json&limit=${LIMIT}&sort_order=desc" | \
        jq -c "{series_id: \"${SERIES_ID}\", observations: [.observations[] | {date, value}]}"
}

case "$CMD" in
    dashboard)
        echo "{"
        for name in fedfunds 10y cpi unemployment gdp; do
            ID="${SERIES[${name}]}"
            DATA=$(get_series "$ID" 1)
            echo "  \"${name}\": ${DATA},"
        done | sed '$ s/,$//'
        echo "}"
        ;;
    series)
        SERIES_ID="${2:-}"
        [[ -z "$SERIES_ID" ]] && usage
        get_series "$SERIES_ID" 10 | if [[ "$PRETTY" == true ]]; then jq '.'; else cat; fi
        ;;
    fedfunds|10y|cpi|unemployment|gdp)
        ID="${SERIES[${CMD}]}"
        get_series "$ID" 10 | if [[ "$PRETTY" == true ]]; then jq '.'; else cat; fi
        ;;
    *)
        usage
        ;;
esac
