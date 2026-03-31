#!/bin/bash
# WHOOP CLI wrapper -- Template for pulling health data from WHOOP API
#
# SETUP:
# 1. Create a WHOOP developer account at https://developer.whoop.com
# 2. Register an app to get client_id and client_secret
# 3. Run the OAuth flow (see whoop-oauth.py or use the WHOOP developer portal)
# 4. Save tokens to ~/.openclaw/.whoop-tokens.json with format:
#    {
#      "access_token": "...",
#      "refresh_token": "...",
#      "expires_in": 3600,
#      "obtained_at": <unix_timestamp>
#    }
# 5. Create a refresh script (whoop-refresh.sh) that uses the refresh_token
#    to obtain new access tokens when they expire.
#
# Usage: bash whoop-template.sh [recovery|sleep|cycle|profile|body|summary]

set -euo pipefail

TOKEN_FILE="$HOME/.openclaw/.whoop-tokens.json"
BASE_URL="https://api.prod.whoop.com/developer"

# Load token
if [[ ! -f "$TOKEN_FILE" ]]; then
  echo "ERROR: No WHOOP tokens found at $TOKEN_FILE"
  echo "Complete the OAuth flow first. See setup instructions in this script."
  exit 1
fi

OBTAINED_AT=$(python3 -c "import json; print(json.load(open('$TOKEN_FILE')).get('obtained_at', 0))")
EXPIRES_IN=$(python3 -c "import json; print(json.load(open('$TOKEN_FILE')).get('expires_in', 3600))")
NOW=$(date +%s)

# Auto-refresh if token expired or expiring soon
if (( NOW - OBTAINED_AT > EXPIRES_IN - 120 )); then
  SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
  # Point this at your refresh script
  bash "$SCRIPT_DIR/whoop-refresh.sh" >/dev/null 2>&1 || {
    echo "ERROR: Token expired and refresh failed. Re-run OAuth flow."
    exit 1
  }
fi

ACCESS_TOKEN=$(python3 -c "import json; print(json.load(open('$TOKEN_FILE'))['access_token'])")

api() {
  curl -s "$BASE_URL$1" -H "Authorization: Bearer $ACCESS_TOKEN"
}

case "${1:-summary}" in
  recovery)
    api "/v2/recovery?limit=${2:-5}" | python3 -m json.tool
    ;;
  sleep)
    api "/v2/activity/sleep?limit=${2:-5}" | python3 -m json.tool
    ;;
  cycle)
    api "/v1/cycle?limit=${2:-5}" | python3 -m json.tool
    ;;
  profile)
    api "/v1/user/profile/basic" | python3 -m json.tool
    ;;
  body)
    api "/v1/user/measurement/body" | python3 -m json.tool
    ;;
  summary)
    echo "WHOOP Summary -- $(date '+%Y-%m-%d %I:%M %p')"
    echo "========================================"

    # Recovery
    RECOVERY=$(api "/v2/recovery?limit=1")
    echo "$RECOVERY" | python3 -c "
import json, sys
data = json.load(sys.stdin)
if data.get('records'):
    r = data['records'][0]
    s = r.get('score', {})
    state = r.get('score_state', 'N/A')
    if state == 'SCORED':
        print(f\"Recovery: {s.get('recovery_score', 'N/A')}%\")
        print(f\"  Resting HR: {s.get('resting_heart_rate', 'N/A')} bpm\")
        print(f\"  HRV: {s.get('hrv_rmssd_milli', 'N/A'):.1f} ms\")
        print(f\"  SpO2: {s.get('spo2_percentage', 'N/A'):.1f}%\")
        print(f\"  Skin Temp: {s.get('skin_temp_celsius', 'N/A'):.1f} C\")
    else:
        print(f'Recovery: {state}')
else:
    print('Recovery: No data')
"

    echo ""

    # Current cycle
    CYCLE=$(api "/v1/cycle?limit=1")
    echo "$CYCLE" | python3 -c "
import json, sys
data = json.load(sys.stdin)
if data.get('records'):
    c = data['records'][0]
    s = c.get('score', {})
    print(f\"Strain: {s.get('strain', 'N/A'):.1f}\")
    print(f\"  Avg HR: {s.get('average_heart_rate', 'N/A')} bpm\")
    print(f\"  Max HR: {s.get('max_heart_rate', 'N/A')} bpm\")
    print(f\"  Calories: {s.get('kilojoule', 0) * 0.239006:.0f} kcal\")
else:
    print('Strain: No data')
"

    echo ""

    # Latest sleep
    SLEEP=$(api "/v2/activity/sleep?limit=1")
    echo "$SLEEP" | python3 -c "
import json, sys
data = json.load(sys.stdin)
if data.get('records'):
    sl = data['records'][0]
    s = sl.get('score', {})
    ss = s.get('stage_summary', {})
    nap = sl.get('nap', False)
    label = 'Nap' if nap else 'Sleep'
    total_ms = ss.get('total_in_bed_time_milli', 0)
    hours = total_ms / 3600000
    perf = s.get('sleep_performance_percentage', 0)
    eff = s.get('sleep_efficiency_percentage', 0)
    rr = s.get('respiratory_rate', 0)

    # Stage breakdown
    light = ss.get('total_light_sleep_time_milli', 0) / 60000
    deep = ss.get('total_slow_wave_sleep_time_milli', 0) / 60000
    rem = ss.get('total_rem_sleep_time_milli', 0) / 60000
    awake = ss.get('total_awake_time_milli', 0) / 60000

    print(f\"Last {label}: {hours:.1f} hrs ({perf:.0f}% performance)\")
    print(f\"  Efficiency: {eff:.1f}%\")
    print(f\"  Light: {light:.0f}m | Deep: {deep:.0f}m | REM: {rem:.0f}m | Awake: {awake:.0f}m\")
    print(f\"  Respiratory Rate: {rr:.1f} breaths/min\")
    print(f\"  Disturbances: {ss.get('disturbance_count', 'N/A')}\")
else:
    print('Sleep: No data')
"
    ;;
  *)
    echo "Usage: whoop-template.sh [recovery|sleep|cycle|profile|body|summary]"
    ;;
esac
