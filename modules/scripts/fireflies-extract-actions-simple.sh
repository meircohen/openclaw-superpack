#!/bin/bash
# Simple Fireflies Action Extractor — Outputs transcript for manual AI analysis
# Usage: fireflies-extract-actions-simple.sh <meeting_id>

set -euo pipefail

MEETING_ID="$1"
source ~/.openclaw/.api-keys

# Fetch transcript
TRANSCRIPT_QUERY="{\"query\": \"query { transcript(id: \\\"$MEETING_ID\\\") { title date sentences { text speaker_name } } }\"}"

RESPONSE=$(curl -s -X POST 'https://api.fireflies.ai/graphql' \
  -H 'Content-Type: application/json' \
  -H "Authorization: Bearer $FIREFLIES_API_KEY" \
  -d "$TRANSCRIPT_QUERY")

# Extract meeting info
MEETING_TITLE=$(echo "$RESPONSE" | jq -r '.data.transcript.title // "Unknown"')
MEETING_DATE=$(echo "$RESPONSE" | jq -r '(.data.transcript.date/1000) | strftime("%Y-%m-%d")' 2>/dev/null || echo "Unknown")

# Extract conversation (limit to first 300 lines to avoid overwhelming output)
CONVERSATION=$(echo "$RESPONSE" | jq -r '.data.transcript.sentences[]? | "\(.speaker_name): \(.text)"' 2>/dev/null | head -300)

if [[ -z "$CONVERSATION" ]]; then
    echo "❌ No transcript found for meeting: $MEETING_ID"
    exit 1
fi

echo "Meeting: $MEETING_TITLE ($MEETING_DATE)"
echo "Meeting ID: $MEETING_ID"
echo ""
echo "=== TRANSCRIPT (first 300 lines) ==="
echo "$CONVERSATION"
echo ""
echo "=== END TRANSCRIPT ==="
echo ""
echo "To extract action items, ask Oz:"
echo "\"Analyze the transcript above and extract action items assigned to Meir. Output as JSON array.\""
