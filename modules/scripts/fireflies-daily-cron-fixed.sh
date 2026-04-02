#!/bin/bash
# Daily cron: Process yesterday's Fireflies meetings for action items

set -euo pipefail

STATE_DIR="/Users/meircohen/.openclaw/workspace/state"
PROCESSED_FILE="$STATE_DIR/fireflies-processed-meetings.json"

# Initialize if needed
[ ! -f "$PROCESSED_FILE" ] && echo '{}' > "$PROCESSED_FILE"

# Get yesterday's date (Unix timestamp range)
YESTERDAY_START=$(date -j -v-1d -v0H -v0M -v0S +%s)
YESTERDAY_END=$(date -j -v-1d -v23H -v59M -v59S +%s)

# Convert to milliseconds
YESTERDAY_START_MS=$((YESTERDAY_START * 1000))
YESTERDAY_END_MS=$((YESTERDAY_END * 1000))

echo "🔍 Checking for new Fireflies meetings..."

# Get all meetings and filter by yesterday's timestamp
ALL_MEETINGS=$(bash ~/.openclaw/workspace/scripts/fireflies-helper.sh list_meetings 2>/dev/null || echo "")

if [ -z "$ALL_MEETINGS" ]; then
    echo "No meetings found"
    exit 0
fi

# Filter yesterday's meetings
YESTERDAY_MEETINGS=$(echo "$ALL_MEETINGS" | awk -v start="$YESTERDAY_START_MS" -v end="$YESTERDAY_END_MS" \
    '$1 >= start && $1 <= end { print $0 }')

if [ -z "$YESTERDAY_MEETINGS" ]; then
    echo "No meetings found for yesterday"
    exit 0
fi

# Process each meeting
echo "$YESTERDAY_MEETINGS" | while IFS='|' read -r timestamp title meeting_id; do
    meeting_id=$(echo "$meeting_id" | xargs)
    title=$(echo "$title" | xargs)
    
    # Check if already processed
    if jq -e --arg id "$meeting_id" '.[$id] != null' "$PROCESSED_FILE" >/dev/null 2>&1; then
        echo "⏭️  Skipping already processed: $title"
        continue
    fi
    
    echo "📋 Processing: $title"
    
    # Extract action items
    if bash ~/.openclaw/workspace/scripts/fireflies-action-extractor-v2.sh "$meeting_id" 2>&1; then
        # Mark as processed
        jq --arg id "$meeting_id" --arg date "$(date -u +%Y-%m-%dT%H:%M:%SZ)" \
            '. + {($id): $date}' "$PROCESSED_FILE" > "${PROCESSED_FILE}.tmp"
        mv "${PROCESSED_FILE}.tmp" "$PROCESSED_FILE"
        echo "✅ Processed: $title"
    else
        echo "❌ Extraction failed for: $title"
    fi
    
    echo ""
done

echo "✅ Daily processing complete"
