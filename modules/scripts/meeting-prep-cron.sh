#!/bin/bash
# Meeting Prep Cron — Check calendar for upcoming meetings, send briefs
# Runs every 5 minutes, sends brief 5 min before each meeting

set -euo pipefail

WORKSPACE="$HOME/.openclaw/workspace"
STATE_FILE="$WORKSPACE/state/meeting-prep-sent-today.json"
LOG_FILE="$WORKSPACE/logs/meeting-prep-cron.log"

mkdir -p "$WORKSPACE/logs"

# Initialize state file for today
TODAY=$(date +%Y-%m-%d)
if [[ ! -f "$STATE_FILE" ]] || [[ $(jq -r '.date // empty' "$STATE_FILE" 2>/dev/null) != "$TODAY" ]]; then
    echo "{\"date\": \"$TODAY\", \"sent\": []}" > "$STATE_FILE"
fi

# Log function
log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $*" | tee -a "$LOG_FILE"
}

log "Checking calendar for upcoming meetings..."

# Get meetings for next 15 minutes (window to catch 5-min-before timing)
NOW_UNIX=$(date +%s)
WINDOW_END=$(date -v+15M +%s)

# Fetch today's calendar events (both accounts)
EVENTS_PRIMARY=$(gog calendar list --from "$TODAY" --account primary 2>/dev/null || echo "")
EVENTS_WORK=$(gog calendar list --from "$TODAY" --account work 2>/dev/null || echo "")

# Combine events
ALL_EVENTS=$(cat <<EOF
$EVENTS_PRIMARY
$EVENTS_WORK
EOF
)

if [[ -z "$ALL_EVENTS" ]]; then
    log "No events found on calendar"
    exit 0
fi

# Parse events and check if any are 5-10 min away
# (gog calendar output format varies, this is simplified)
# TODO: Parse actual gog output format and extract meeting times

# For now, placeholder logic:
# In production, would:
# 1. Parse gog calendar JSON output
# 2. Extract: event_id, title, start_time, attendees
# 3. Filter: external attendees only (not from your domains)
# 4. Check: if start_time is 5-10 min from now
# 5. Check state: if already sent brief for this event_id today
# 6. If not sent: invoke meeting prep skill

log "TODO: Parse gog calendar output and trigger meeting prep for upcoming external meetings"
log "Currently: skeleton cron wrapper built, needs gog calendar parser"

# Skeleton for actual implementation:
# while read -r event_json; do
#     EVENT_ID=$(echo "$event_json" | jq -r '.id')
#     TITLE=$(echo "$event_json" | jq -r '.title')
#     START_TIME=$(echo "$event_json" | jq -r '.start_time')
#     ATTENDEES=$(echo "$event_json" | jq -r '.attendees[]')
#     
#     # Check if already sent
#     ALREADY_SENT=$(jq --arg id "$EVENT_ID" '[.sent[] | select(. == $id)] | length' "$STATE_FILE")
#     if [[ "$ALREADY_SENT" -gt 0 ]]; then
#         continue
#     fi
#     
#     # Check if 5-10 min before start
#     START_UNIX=$(date -j -f "%Y-%m-%d %H:%M:%S" "$START_TIME" +%s)
#     TIME_DIFF=$((START_UNIX - NOW_UNIX))
#     
#     if [[ $TIME_DIFF -ge 300 && $TIME_DIFF -le 600 ]]; then
#         log "Preparing brief for: $TITLE"
#         
#         # Invoke meeting prep skill (via openclaw message send to skill session)
#         # Or use /meeting-prep command
#         
#         # Mark as sent
#         jq --arg id "$EVENT_ID" '.sent += [$id]' "$STATE_FILE" > "${STATE_FILE}.tmp"
#         mv "${STATE_FILE}.tmp" "$STATE_FILE"
#     fi
# done <<< "$PARSED_EVENTS"

log "Meeting prep cron check complete"
