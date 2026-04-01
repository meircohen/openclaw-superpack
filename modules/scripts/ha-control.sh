#!/bin/bash
# ha-control.sh - Control Home Assistant devices
# Usage: bash scripts/ha-control.sh "turn off pool lights"
set -e

source ~/.zshrc 2>/dev/null
HASS_SERVER="${HASS_SERVER:-http://localhost:8123}"
HASS_TOKEN="${HA_ACCESS_TOKEN}"

if [ -z "$1" ]; then
  echo "Usage: bash scripts/ha-control.sh <natural language command>"
  exit 0
fi

RESPONSE=$(curl -s -X POST "$HASS_SERVER/api/conversation/process" \
  -H "Authorization: Bearer $HASS_TOKEN" \
  -H "Content-Type: application/json" \
  -d "{\"text\": \"$1\", \"language\": \"en\"}")

echo "$RESPONSE" | python3 -c "
import json, sys
try:
    data = json.load(sys.stdin)
    speech = data.get('response', {}).get('speech', {}).get('plain', {}).get('speech', 'No response')
    print(speech)
except:
    print('Error parsing HA response')
"
