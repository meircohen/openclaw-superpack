#!/bin/bash
# Daily Fireflies Action Items Processing
# Runs at end of day to capture action items from yesterday's meetings

set -euo pipefail

WORKSPACE="$HOME/.openclaw/workspace"
cd "$WORKSPACE"

# Check for meetings from last 24 hours
echo "🔍 Checking for new Fireflies meetings..."

bash scripts/fireflies-helper.sh list_meetings | head -10 | while read -r line; do
  MEETING_ID=$(echo "$line" | cut -d'|' -f3 | xargs)
  MEETING_TITLE=$(echo "$line" | cut -d'|' -f2 | xargs)
  
  echo "📋 Processing: $MEETING_TITLE"
  
  # Extract action items using the helper
  bash scripts/fireflies-action-extractor.sh "$MEETING_ID"
done

echo "✅ Fireflies daily processing complete"
