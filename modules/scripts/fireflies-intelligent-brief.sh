#!/bin/bash
# Fireflies Intelligent Brief — AI-powered meeting context
# Usage: fireflies-intelligent-brief.sh "Person Name"

set -euo pipefail

PERSON="$1"
WORKSPACE="$HOME/.openclaw/workspace"
TMP_FILE="/tmp/fireflies-brief-$$.txt"

# Fetch raw context using basic script
bash "$WORKSPACE/scripts/fireflies-pre-meeting.sh" "$PERSON" 10 > "$TMP_FILE" 2>&1

# Check if we found meetings
if grep -q "No recent meetings" "$TMP_FILE"; then
  cat "$TMP_FILE"
  rm "$TMP_FILE"
  exit 0
fi

# Get the meeting ID from Fireflies API
source ~/.openclaw/.api-keys

QUERY='{"query": "query { transcripts(limit: 10) { id title date participants } }"}'

RESPONSE=$(curl -s -X POST 'https://api.fireflies.ai/graphql' \
  -H 'Content-Type: application/json' \
  -H "Authorization: Bearer $FIREFLIES_API_KEY" \
  -d "$QUERY")

MEETING_ID=$(echo "$RESPONSE" | jq -r --arg person "$PERSON" '
  .data.transcripts[] | 
  select(.title | ascii_downcase | contains($person | ascii_downcase)) | 
  .id
' | head -1)

if [[ -z "$MEETING_ID" ]]; then
  echo "Could not fetch meeting details"
  rm "$TMP_FILE"
  exit 1
fi

# Fetch full transcript
TRANSCRIPT_QUERY="{\"query\": \"query { transcript(id: \\\"$MEETING_ID\\\") { sentences { text speaker_name } } }\"}"

TRANSCRIPT=$(curl -s -X POST 'https://api.fireflies.ai/graphql' \
  -H 'Content-Type: application/json' \
  -H "Authorization: Bearer $FIREFLIES_API_KEY" \
  -d "$TRANSCRIPT_QUERY")

# Extract just the conversation text
CONVERSATION=$(echo "$TRANSCRIPT" | jq -r '.data.transcript.sentences[] | "\(.speaker_name): \(.text)"' | head -200)

# Save to temp file for AI analysis
ANALYSIS_INPUT=$(cat <<EOF
Analyze this meeting transcript and provide a pre-meeting brief:

MEETING: $PERSON
DATE: $(grep "Last met:" "$TMP_FILE" | cut -d: -f2-)

TRANSCRIPT (excerpt):
$CONVERSATION

EXTRACT:
1. **Key Topics Discussed** (3-5 bullet points, specific and actionable)
2. **Action Items Assigned** (who will do what, with any deadlines mentioned)
3. **Open Questions / Decisions Pending** (what needs follow-up)
4. **Context for Next Meeting** (what to remember, prepare, or ask about)

Format as a brief suitable for reading 5 minutes before the next call.
EOF
)

# Use OpenClaw to analyze (route to this same session)
echo "$ANALYSIS_INPUT" | openclaw message send --message "$(cat)" --session-key "$(openclaw sessions list --limit 1 | jq -r '.sessions[0].key')" 2>/dev/null || {
  # Fallback: just show raw extraction
  cat "$TMP_FILE"
}

rm "$TMP_FILE"
