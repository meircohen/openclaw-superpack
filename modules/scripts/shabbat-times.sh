#!/bin/bash
# Shabbat/Yom Tov times for Fort Lauderdale, FL
# Usage: bash shabbat-times.sh [json|summary]
# Uses Hebcal API - zip 33301, 18 min before sunset

set -euo pipefail

RESPONSE=$(curl -s "https://www.hebcal.com/shabbat?cfg=json&zip=33301&m=18")

case "${1:-summary}" in
  json)
    echo "$RESPONSE" | python3 -m json.tool
    ;;
  summary)
    echo "$RESPONSE" | python3 -c "
import json, sys
from datetime import datetime

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

print('🕯️ Shabbat Times — Fort Lauderdale, FL')
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
et = timezone(timedelta(hours=-4))
now = datetime.now(et)

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
    echo "Usage: shabbat-times.sh [json|summary|check]"
    ;;
esac
