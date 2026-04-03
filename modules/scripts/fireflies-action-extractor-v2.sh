#!/bin/bash
# Fireflies Action Item Extractor v2 — uses OpenClaw tools API
# Usage: fireflies-action-extractor-v2.sh <meeting_id>

set -euo pipefail

MEETING_ID="$1"
STATE_FILE="$HOME/.openclaw/workspace/state/fireflies/fireflies-action-items.json"
TMP_FILE="/tmp/fireflies-transcript-$$.txt"
RESULT_FILE="/tmp/fireflies-extraction-$$.json"

source ~/.openclaw/.api-keys

# Initialize state file if doesn't exist
if [[ ! -f "$STATE_FILE" ]]; then
    echo '[]' > "$STATE_FILE"
fi

# Fetch transcript
TRANSCRIPT_QUERY="{\"query\": \"query { transcript(id: \\\"$MEETING_ID\\\") { title date sentences { text speaker_name } } }\"}"

RESPONSE=$(curl -s -X POST 'https://api.fireflies.ai/graphql' \
  -H 'Content-Type: application/json' \
  -H "Authorization: Bearer $FIREFLIES_API_KEY" \
  -d "$TRANSCRIPT_QUERY")

# Extract meeting info
MEETING_TITLE=$(echo "$RESPONSE" | jq -r '.data.transcript.title')
MEETING_DATE=$(echo "$RESPONSE" | jq -r '(.data.transcript.date/1000) | strftime("%Y-%m-%d")')

if [[ "$MEETING_TITLE" == "null" ]]; then
    echo "❌ Meeting not found: $MEETING_ID"
    exit 1
fi

# Extract conversation
CONVERSATION=$(echo "$RESPONSE" | jq -r '.data.transcript.sentences[]? | "\(.speaker_name): \(.text)"' 2>/dev/null)

if [[ -z "$CONVERSATION" ]]; then
    echo "❌ No transcript found for meeting: $MEETING_ID"
    exit 1
fi

# Save conversation to temp file (first 500 lines to avoid token limits)
echo "$CONVERSATION" | head -500 > "$TMP_FILE"

echo "📝 Meeting: $MEETING_TITLE ($MEETING_DATE)"
echo "📊 Analyzing transcript for action items..."
echo ""

# Read transcript
TRANSCRIPT_CONTENT=$(cat "$TMP_FILE")

# Create extraction prompt
cat > /tmp/fireflies-prompt-$$.txt <<EOF
Analyze this meeting transcript and extract action items assigned to MEIR COHEN.

Meeting: $MEETING_TITLE
Date: $MEETING_DATE

Transcript:
$TRANSCRIPT_CONTENT

RULES:
1. Only extract actions explicitly assigned to Meir (not general "we should" statements)
2. Look for patterns: "I'll", "I will", "Meir will", "[Meir's name] should"
3. Ignore vague statements like "I'll think about it" or "I'll get back to you"
4. Extract concrete, actionable items only
5. Include deadline if mentioned (otherwise mark as "no deadline")
6. Ownership skepticism: Don't assume Meir owns "we" statements unless explicit

Format each action item as JSON:
{
  "action": "specific action to take",
  "owner": "Meir Cohen",
  "deadline": "YYYY-MM-DD or no deadline",
  "context": "brief context from meeting",
  "status": "open"
}

Output ONLY a JSON array of action items. If no action items found, output: []

Write your JSON array to: $RESULT_FILE
EOF

# Use sessions_spawn via OpenClaw CLI for clean JSON extraction
openclaw run --task "$(cat /tmp/fireflies-prompt-$$.txt)" --timeout 120 > /tmp/fireflies-run-$$.log 2>&1

# Wait for result file
sleep 2

# Check if AI wrote the result file
if [[ -f "$RESULT_FILE" ]] && jq empty "$RESULT_FILE" 2>/dev/null; then
    # Merge with existing state
    TIMESTAMP=$(date -u +"%Y-%m-%dT%H:%M:%SZ")
    
    jq --arg meeting_id "$MEETING_ID" --arg meeting_title "$MEETING_TITLE" --arg timestamp "$TIMESTAMP" '
      map(. + {
        "meeting_id": $meeting_id,
        "meeting_title": $meeting_title,
        "extracted_at": $timestamp
      })
    ' "$RESULT_FILE" > /tmp/new-actions-$$.json
    
    # Append to state file (avoiding duplicates)
    jq -s '.[0] + .[1] | unique_by(.meeting_id + .action)' "$STATE_FILE" /tmp/new-actions-$$.json > "${STATE_FILE}.tmp"
    mv "${STATE_FILE}.tmp" "$STATE_FILE"
    
    # Show results
    ACTION_COUNT=$(jq 'length' "$RESULT_FILE")
    echo "✅ Extracted $ACTION_COUNT action items"
    echo ""
    jq -r '.[] | "  • \(.action) (deadline: \(.deadline))"' "$RESULT_FILE"
    
    rm /tmp/new-actions-$$.json "$RESULT_FILE"
else
    echo "❌ AI extraction failed - no valid JSON output"
    if [[ -f /tmp/fireflies-run-$$.log ]]; then
        echo "Log:"
        cat /tmp/fireflies-run-$$.log
    fi
fi

# Cleanup
rm -f "$TMP_FILE" /tmp/fireflies-prompt-$$.txt /tmp/fireflies-run-$$.log
