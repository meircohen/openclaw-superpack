#!/usr/bin/env bash
# WHOOP API integration template
# Requires: WHOOP_ACCESS_TOKEN in environment or auth-profiles.json

TOKEN="${WHOOP_ACCESS_TOKEN:-}"
BASE="https://api.prod.whoop.com/developer/v1"

case "${1:-summary}" in
  summary)
    curl -s -H "Authorization: Bearer $TOKEN" "$BASE/cycle" | python3 -c "
import sys, json
data = json.load(sys.stdin)
if 'records' in data and data['records']:
    r = data['records'][0]
    print(f'Recovery: {r.get(\"score\",{}).get(\"recovery_score\",\"N/A\")}%')
    print(f'HRV: {r.get(\"score\",{}).get(\"hrv_rmssd_milli\",\"N/A\")}ms')
    print(f'Strain: {r.get(\"score\",{}).get(\"strain\",\"N/A\")}')
"
    ;;
  refresh)
    echo "Run WHOOP token refresh via OAuth"
    ;;
  *)
    echo "Usage: whoop.sh [summary|refresh]"
    ;;
esac
