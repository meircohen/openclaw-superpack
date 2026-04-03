#!/usr/bin/env bash
# HaveIBeenPwned API - Check for data breaches
# Usage: hibp.sh <email>
# API: https://haveibeenpwned.com/API/v3
# Auth: API key required (stored in ~/.openclaw/.api-keys)

set -euo pipefail

API_KEYS="${HOME}/.openclaw/.api-keys"
if [[ -f "$API_KEYS" ]]; then
    source "$API_KEYS"
fi

if [[ -z "${HIBP_API_KEY:-}" ]]; then
    echo "Error: HIBP_API_KEY not set" >&2
    echo "Get an API key at: https://haveibeenpwned.com/API/Key" >&2
    echo "Add to ~/.openclaw/.api-keys: HIBP_API_KEY=your_key_here" >&2
    exit 1
fi

BASE_URL="https://haveibeenpwned.com/api/v3"

usage() {
    echo "Usage: $0 <email>"
    echo ""
    echo "Check if an email address appears in any known data breaches"
    exit 1
}

PRETTY=false
if [[ "${1:-}" == "--pretty" ]]; then
    PRETTY=true
    shift
fi

EMAIL="${1:-}"
[[ -z "$EMAIL" ]] && usage

# HIBP requires rate limiting - add delay
sleep 1.5

DATA=$(curl -sf -H "hibp-api-key: ${HIBP_API_KEY}" \
    -H "user-agent: OpenClaw" \
    "${BASE_URL}/breachedaccount/${EMAIL}?truncateResponse=false" || echo "[]")

if [[ "$PRETTY" == true ]]; then
    echo "$DATA" | jq '.'
else
    echo "$DATA" | jq -c 'map({Name, BreachDate, PwnCount, DataClasses})'
fi
