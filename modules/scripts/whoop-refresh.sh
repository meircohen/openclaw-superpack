#!/bin/bash
# Refresh WHOOP OAuth token
set -euo pipefail

TOKEN_FILE="$HOME/.openclaw/.whoop-tokens.json"
source "$HOME/.openclaw/.api-keys"

REFRESH_TOKEN=$(python3 -c "import json; print(json.load(open('$TOKEN_FILE')).get('refresh_token', ''))")

if [[ -z "$REFRESH_TOKEN" ]]; then
  echo "ERROR: No refresh_token. Re-run whoop-oauth.py"
  exit 1
fi

RESPONSE=$(curl -s -X POST "https://api.prod.whoop.com/oauth/oauth2/token" \
  -H "Content-Type: application/x-www-form-urlencoded" \
  -d "grant_type=refresh_token&refresh_token=${REFRESH_TOKEN}&client_id=${WHOOP_CLIENT_ID}&client_secret=${WHOOP_CLIENT_SECRET}&scope=offline+read%3Arecovery+read%3Asleep+read%3Aworkout+read%3Acycles+read%3Aprofile+read%3Abody_measurement")

ERROR=$(echo "$RESPONSE" | python3 -c "import json,sys; print(json.load(sys.stdin).get('error',''))" 2>/dev/null || echo "parse_error")
if [[ -n "$ERROR" && "$ERROR" != "" ]]; then
  echo "ERROR: $RESPONSE"
  exit 1
fi

python3 -c "
import json, time
response = json.loads('''$RESPONSE''')
response['obtained_at'] = int(time.time())
with open('$TOKEN_FILE', 'w') as f:
    json.dump(response, f, indent=2)
print(f'Refreshed. Expires in {response.get(\"expires_in\", \"?\")}s')
"
