#!/bin/bash
# Daily cron: Process yesterday's Fireflies meetings for action items

set -euo pipefail

STATE_DIR="/Users/meircohen/.openclaw/workspace/state"
PROCESSED_FILE="$STATE_DIR/fireflies-processed-meetings.json"

# Initialize if needed
[ ! -f "$PROCESSED_FILE" ] && echo '{}' > "$PROCESSED_FILE"

# Get yesterday's date
YESTERDAY=$(date -v-1d +%Y-%m-%d)

echo "🔍 Checking for new Fireflies meetings..."

# Get meetings from yesterday
MEETINGS=$(bash ~/.openclaw/workspace/scripts/fireflies-helper.sh list_meetings 2>/dev/null | \
    jq -r --arg date "$YESTERDAY" '.data.transcripts[] | select(.date_string == $date) | .id + " | " + .title')

if [ -z "$MEETINGS" ]; then
    echo "No meetings found for $YESTERDAY"
    exit 0
fi

# Process each meeting
while IFS='|' read -r meeting_id meeting_title; do
    meeting_id=$(echo "$meeting_id" | tr -d ' ')
    meeting_title=$(echo "$meeting_title" | xargs)
    
    # Check if already processed
    if jq -e --arg id "$meeting_id" '.[$id] != null' "$PROCESSED_FILE" >/dev/null 2>&1; then
        echo "⏭️  Skipping already processed: $meeting_title"
        continue
    fi
    
    echo "📋 Processing: $meeting_title"
    
    # Extract action items
    if bash ~/.openclaw/workspace/scripts/fireflies-action-extractor-v2.sh "$meeting_id"; then
        # Mark as processed
        jq --arg id "$meeting_id" --arg date "$(date -u +%Y-%m-%dT%H:%M:%SZ)" \
            '. + {($id): $date}' "$PROCESSED_FILE" > "${PROCESSED_FILE}.tmp"
        mv "${PROCESSED_FILE}.tmp" "$PROCESSED_FILE"
    else
        echo "❌ Extraction failed for: $meeting_title"
    fi
    
    echo ""
done <<< "$MEETINGS"

echo "✅ Daily processing complete"
