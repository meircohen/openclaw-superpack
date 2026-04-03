#!/bin/bash
# Fireflies Action Item Extractor — AI-powered
# Usage: fireflies-action-extractor.sh <meeting_id>

set -euo pipefail

MEETING_ID="$1"
STATE_FILE="$HOME/.openclaw/workspace/state/fireflies/fireflies-action-items.json"
TMP_FILE="/tmp/fireflies-transcript-$$.txt"

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

# Read transcript content
TRANSCRIPT_CONTENT=$(cat "$TMP_FILE")

# Build AI prompt (bash heredoc with variable expansion)
AI_PROMPT="Analyze this meeting transcript and extract action items assigned to MEIR COHEN.

Meeting: $MEETING_TITLE
Date: $MEETING_DATE

Transcript:
$TRANSCRIPT_CONTENT

RULES:
1. Only extract actions explicitly assigned to Meir (not general \"we should\" statements)
2. Look for patterns: \"I'll\", \"I will\", \"Meir will\", \"[Meir's name] should\"
3. Ignore vague statements like \"I'll think about it\" or \"I'll get back to you\"
4. Extract concrete, actionable items only
5. Include deadline if mentioned (otherwise mark as \"no deadline\")
6. Ownership skepticism: Don't assume Meir owns \"we\" statements unless explicit

Format each action item as JSON:
{
  \"action\": \"specific action to take\",
  \"owner\": \"Meir Cohen\",
  \"deadline\": \"YYYY-MM-DD or no deadline\",
  \"context\": \"brief context from meeting\",
  \"status\": \"open\"
}

Output ONLY a JSON array of action items. If no action items found, output: []"

# Save prompt to temp file for sub-agent
echo "$AI_PROMPT" > /tmp/ai-prompt-$$.txt

# Call OpenClaw via sub-agent (cleanup after)
EXTRACTION=$(openclaw message send --message "$(cat /tmp/ai-prompt-$$.txt)" 2>&1 | grep -A 1000 '^\[' | head -1000)

rm /tmp/ai-prompt-$$.txt

# Validate JSON
if echo "$EXTRACTION" | jq empty 2>/dev/null; then
    # Merge with existing state
    TIMESTAMP=$(date -u +"%Y-%m-%dT%H:%M:%SZ")
    
    echo "$EXTRACTION" | jq --arg meeting_id "$MEETING_ID" --arg meeting_title "$MEETING_TITLE" --arg timestamp "$TIMESTAMP" '
      map(. + {
        "meeting_id": $meeting_id,
        "meeting_title": $meeting_title,
        "extracted_at": $timestamp
      })
    ' > /tmp/new-actions-$$.json
    
    # Append to state file (avoiding duplicates)
    jq -s '.[0] + .[1] | unique_by(.meeting_id + .action)' "$STATE_FILE" /tmp/new-actions-$$.json > "${STATE_FILE}.tmp"
    mv "${STATE_FILE}.tmp" "$STATE_FILE"
    
    # Show results
    ACTION_COUNT=$(echo "$EXTRACTION" | jq 'length')
    echo "✅ Extracted $ACTION_COUNT action items"
    echo ""
    echo "$EXTRACTION" | jq -r '.[] | "  • \(.action) (deadline: \(.deadline))"'
    
    rm /tmp/new-actions-$$.json
else
    echo "❌ AI extraction failed or returned invalid JSON"
    echo "Response:"
    echo "$EXTRACTION"
fi

rm "$TMP_FILE"
