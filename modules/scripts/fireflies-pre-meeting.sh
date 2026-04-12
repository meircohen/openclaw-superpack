#!/bin/bash
# Fireflies Pre-Meeting Brief
# Usage: fireflies-pre-meeting.sh "Person Name" or email

set -euo pipefail

source ~/.openclaw/.api-keys

PERSON="$1"
LIMIT="${2:-10}"  # Look back at last 10 meetings

# Search for meetings with this person
QUERY=$(cat <<EOF
{
  "query": "query { transcripts(limit: $LIMIT) { id title date participants } }"
}
EOF
)

RESPONSE=$(curl -s -X POST 'https://api.fireflies.ai/graphql' \
  -H 'Content-Type: application/json' \
  -H "Authorization: Bearer $FIREFLIES_API_KEY" \
  -d "$QUERY")

# Filter meetings with this person
MEETINGS=$(echo "$RESPONSE" | jq -c --arg person "$PERSON" '
  .data.transcripts[] | 
  select(.title | ascii_downcase | contains($person | ascii_downcase))
')

if [[ -z "$MEETINGS" ]]; then
  echo "No recent meetings found with: $PERSON"
  exit 0
fi

# Get most recent meeting
LATEST=$(echo "$MEETINGS" | head -1)
MEETING_ID=$(echo "$LATEST" | jq -r '.id')
MEETING_DATE=$(echo "$LATEST" | jq -r '(.date/1000) | strftime("%Y-%m-%d")')
MEETING_TITLE=$(echo "$LATEST" | jq -r '.title')

echo "📅 Last met: $MEETING_DATE"
echo "📝 Meeting: $MEETING_TITLE"
echo ""

# Fetch transcript for context extraction
TRANSCRIPT_QUERY=$(cat <<EOF
{
  "query": "query { transcript(id: \"$MEETING_ID\") { sentences { text speaker_name } } }"
}
EOF
)

TRANSCRIPT=$(curl -s -X POST 'https://api.fireflies.ai/graphql' \
  -H 'Content-Type: application/json' \
  -H "Authorization: Bearer $FIREFLIES_API_KEY" \
  -d "$TRANSCRIPT_QUERY")

# Extract key topics (simple keyword extraction for now)
echo "🔑 Key Topics:"
echo "$TRANSCRIPT" | jq -r '.data.transcript.sentences[]?.text // empty' 2>/dev/null | \
  grep -iE '(discuss|talk about|focus on|important|key point|action item|follow up|next step)' | \
  head -5 | sed 's/^/  • /' || echo "  (Unable to extract topics from transcript)"

echo ""

# Extract action items
echo "✅ Action Items Mentioned:"
echo "$TRANSCRIPT" | jq -r '.data.transcript.sentences[]?.text // empty' 2>/dev/null | \
  grep -iE "(I'll|I will|we'll|we will|need to|should|must|action item|follow up)" | \
  head -5 | sed 's/^/  • /' || echo "  (No action items detected)"

echo ""
echo "Full meeting count with $PERSON: $(echo "$MEETINGS" | wc -l | tr -d ' ')"
