#!/usr/bin/env bash
# WolframAlpha API - Computational knowledge engine
# Usage: wolfram.sh "<query>"
# API: https://products.wolframalpha.com/api/documentation
# Auth: App ID required (stored in ~/.openclaw/.api-keys)

set -euo pipefail

API_KEYS="${HOME}/.openclaw/.api-keys"
if [[ -f "$API_KEYS" ]]; then
    source "$API_KEYS"
fi

if [[ -z "${WOLFRAM_APP_ID:-}" ]]; then
    echo "Error: WOLFRAM_APP_ID not set" >&2
    echo "Get a free App ID at: https://products.wolframalpha.com/api" >&2
    echo "Add to ~/.openclaw/.api-keys: WOLFRAM_APP_ID=your_app_id_here" >&2
    exit 1
fi

BASE_URL="https://api.wolframalpha.com/v2/query"

usage() {
    echo "Usage: $0 \"<query>\""
    echo ""
    echo "Examples:"
    echo "  $0 \"population of Miami\""
    echo "  $0 \"derivative of x^2\""
    echo "  $0 \"weather in Surfside FL\""
    exit 1
}

PRETTY=false
if [[ "${1:-}" == "--pretty" ]]; then
    PRETTY=true
    shift
fi

QUERY="${1:-}"
[[ -z "$QUERY" ]] && usage

# URL encode the query
ENCODED=$(echo -n "$QUERY" | jq -sRr @uri)

# Get XML response (simpler than JSON for this API)
DATA=$(curl -sf "${BASE_URL}?input=${ENCODED}&appid=${WOLFRAM_APP_ID}&output=json")

if [[ "$PRETTY" == true ]]; then
    echo "$DATA" | jq '.'
else
    # Extract primary result pods
    echo "$DATA" | jq -c '.queryresult | {success, input: .inputstring, result: [.pods[]? | select(.primary == true or .title == "Result" or .title == "Value") | {title, text: .subpods[0].plaintext}]}'
fi
