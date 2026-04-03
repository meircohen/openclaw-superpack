#!/usr/bin/env bash
# NewsAPI - Top headlines and news search
# Usage: news.sh [headlines|search <query>|morning-brief]
# API: https://newsapi.org/docs/endpoints
# Auth: API key required (stored in ~/.openclaw/.api-keys)

set -euo pipefail

API_KEYS="${HOME}/.openclaw/.api-keys"
if [[ -f "$API_KEYS" ]]; then
    source "$API_KEYS"
fi

if [[ -z "${NEWS_API_KEY:-}" ]]; then
    echo "Error: NEWS_API_KEY not set" >&2
    echo "Get a free API key at: https://newsapi.org/register" >&2
    echo "Add to ~/.openclaw/.api-keys: NEWS_API_KEY=your_key_here" >&2
    exit 1
fi

BASE_URL="https://newsapi.org/v2"

usage() {
    echo "Usage: $0 [headlines|search <query>|morning-brief]"
    echo ""
    echo "Commands:"
    echo "  headlines [category]  - Top headlines (default: business)"
    echo "  search <query>        - Search news articles"
    echo "  morning-brief         - Top 5 business + 3 tech + 3 bitcoin"
    exit 1
}

PRETTY=false
if [[ "${1:-}" == "--pretty" ]]; then
    PRETTY=true
    shift
fi

CMD="${1:-headlines}"

get_headlines() {
    local CATEGORY="${1:-business}"
    curl -sf "${BASE_URL}/top-headlines?country=us&category=${CATEGORY}&apiKey=${NEWS_API_KEY}" | \
        jq -c '.articles[:5] | map({title, source: .source.name, url, publishedAt})'
}

case "$CMD" in
    headlines)
        CATEGORY="${2:-business}"
        DATA=$(curl -sf "${BASE_URL}/top-headlines?country=us&category=${CATEGORY}&apiKey=${NEWS_API_KEY}")
        if [[ "$PRETTY" == true ]]; then
            echo "$DATA" | jq '.'
        else
            echo "$DATA" | jq -c '.articles[:10] | map({title, source: .source.name, url})'
        fi
        ;;
    search)
        QUERY="${2:-}"
        [[ -z "$QUERY" ]] && usage
        DATA=$(curl -sf "${BASE_URL}/everything?q=${QUERY}&sortBy=publishedAt&apiKey=${NEWS_API_KEY}")
        if [[ "$PRETTY" == true ]]; then
            echo "$DATA" | jq '.'
        else
            echo "$DATA" | jq -c '.articles[:10] | map({title, source: .source.name, url, publishedAt})'
        fi
        ;;
    morning-brief)
        echo "{"
        echo "  \"business\": $(get_headlines business),"
        echo "  \"technology\": $(get_headlines technology | jq -c '.[:3]'),"
        
        # Bitcoin news via search
        BTC=$(curl -sf "${BASE_URL}/everything?q=bitcoin&sortBy=publishedAt&apiKey=${NEWS_API_KEY}" | \
            jq -c '.articles[:3] | map({title, source: .source.name, url})')
        echo "  \"bitcoin\": ${BTC}"
        echo "}"
        ;;
    *)
        usage
        ;;
esac
