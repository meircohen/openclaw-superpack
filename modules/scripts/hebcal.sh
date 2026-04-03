#!/usr/bin/env bash
# Hebcal API - Jewish calendar and Shabbos times
# Usage: hebcal.sh [today|shabbat|holidays|zmanim]
# API: https://www.hebcal.com/home/developer-apis
# Auth: None required

set -euo pipefail

ZIP="33154"  # Surfside, FL
BASE_URL="https://www.hebcal.com"

usage() {
    echo "Usage: $0 [today|shabbat|holidays|zmanim]"
    echo ""
    echo "Commands:"
    echo "  today     - Today's Hebrew date and info"
    echo "  shabbat   - This week's Shabbos times (candle lighting, havdalah)"
    echo "  holidays  - Upcoming holidays and special days"
    echo "  zmanim    - Today's halachic times (dawn, sunrise, sunset, etc.)"
    exit 1
}

PRETTY=false
if [[ "${1:-}" == "--pretty" ]]; then
    PRETTY=true
    shift
fi

CMD="${1:-shabbat}"

case "$CMD" in
    today)
        curl -sf "${BASE_URL}/converter?cfg=json&date=$(date +%Y-%m-%d)&g2h=1&strict=1"
        ;;
    shabbat)
        DATA=$(curl -sf "${BASE_URL}/shabbat?cfg=json&zip=${ZIP}&M=on")
        if [[ "$PRETTY" == true ]]; then
            echo "$DATA" | jq '.'
        else
            echo "$DATA" | jq -c '{location: .location, items: [.items[] | select(.category == "candles" or .category == "havdalah") | {title, date, category}]}'
        fi
        ;;
    holidays)
        YEAR=$(date +%Y)
        curl -sf "${BASE_URL}/hebcal?v=1&cfg=json&year=${YEAR}&month=x&ss=on&mf=on&c=on&geo=zip&zip=${ZIP}&M=on" | \
            if [[ "$PRETTY" == true ]]; then jq '.'; else jq -c '.items[:10]'; fi
        ;;
    zmanim)
        DATE=$(date +%Y-%m-%d)
        DATA=$(curl -sf "${BASE_URL}/zmanim?cfg=json&zip=${ZIP}&date=${DATE}")
        if [[ "$PRETTY" == true ]]; then
            echo "$DATA" | jq '.'
        else
            echo "$DATA" | jq -c '{date, times: {dawn: .times.alotHaShachar, sunrise: .times.sunrise, sunset: .times.sunset, tzeit: .times.tzeit7083deg, chatzot: .times.chatzot}}'
        fi
        ;;
    *)
        usage
        ;;
esac
