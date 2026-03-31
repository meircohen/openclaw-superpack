#!/bin/bash
# Shabbat/Yom Tov times -- Template
# Uses the free Hebcal API to check Shabbat times for your location.
#
# SETUP:
# 1. Find your ZIP code (US) or set latitude/longitude for international
# 2. Set the ZIP variable below (or modify the API URL for geo coordinates)
# 3. Adjust candle lighting minutes (default: 18 minutes before sunset)
# 4. Adjust timezone offset in the check function if not US Eastern
#
# Usage: bash shabbat-times-template.sh [json|summary|check]
#
# The 'check' mode returns either 'shabbat' or 'weekday', which the
# heartbeat uses to suppress non-emergency notifications during Shabbat.

set -euo pipefail

# CUSTOMIZE: Your ZIP code and candle lighting minutes
ZIP="${SHABBAT_ZIP:-10001}"
CANDLE_MINUTES="${SHABBAT_CANDLE_MINUTES:-18}"

# CUSTOMIZE: Your UTC offset (e.g., -5 for EST, -4 for EDT)
UTC_OFFSET="${SHABBAT_UTC_OFFSET:--5}"

RESPONSE=$(curl -s "https://www.hebcal.com/shabbat?cfg=json&zip=${ZIP}&m=${CANDLE_MINUTES}")

case "${1:-summary}" in
  json)
    echo "$RESPONSE" | python3 -m json.tool
    ;;
  summary)
    echo "$RESPONSE" | python3 -c "
import json, sys

data = json.load(sys.stdin)
items = data.get('items', [])

candles = None
havdalah = None
parasha = None
holidays = []

for item in items:
    cat = item.get('category', '')
    if cat == 'candles':
        candles = item
    elif cat == 'havdalah':
        havdalah = item
    elif cat == 'parashat':
        parasha = item
    elif cat == 'holiday':
        holidays.append(item.get('title', ''))

location = data.get('location', {}).get('title', 'Your Location')
print(f'Shabbat Times -- {location}')
print('=' * 40)
if candles:
    print(f\"Candle Lighting: {candles['title'].replace('Candle lighting: ', '')}\")
    print(f\"  Date: {candles['date'][:10]}\")
if havdalah:
    print(f\"Havdalah: {havdalah['title'].replace('Havdalah: ', '')}\")
if parasha:
    print(f\"Parasha: {parasha['title'].replace('Parashat ', '')}\")
if holidays:
    print(f\"Special: {', '.join(holidays)}\")

# Output machine-readable times for escalation protocol
if candles:
    print(f\"\n[MACHINE] candle_lighting={candles['date']}\")
if havdalah:
    print(f\"[MACHINE] havdalah={havdalah['date']}\")
"
    ;;
  check)
    # Returns 'shabbat' if currently Shabbat/Yom Tov, 'weekday' otherwise
    echo "$RESPONSE" | python3 -c "
import json, sys
from datetime import datetime, timezone, timedelta

data = json.load(sys.stdin)
items = data.get('items', [])
tz = timezone(timedelta(hours=${UTC_OFFSET}))
now = datetime.now(tz)

candle_time = None
havdalah_time = None

for item in items:
    cat = item.get('category', '')
    if cat == 'candles' and 'date' in item and 'T' in item['date']:
        candle_time = datetime.fromisoformat(item['date'])
    elif cat == 'havdalah' and 'date' in item and 'T' in item['date']:
        havdalah_time = datetime.fromisoformat(item['date'])

if candle_time and havdalah_time and candle_time <= now <= havdalah_time:
    print('shabbat')
else:
    print('weekday')
"
    ;;
  *)
    echo "Usage: shabbat-times-template.sh [json|summary|check]"
    ;;
esac
