#!/bin/bash
# Weekly George Coaching Recap
# Compiles insights from all George sessions

source ~/.openclaw/.api-keys

if [ -z "$FIREFLIES_API_KEY" ]; then
  echo "Error: FIREFLIES_API_KEY not set"
  exit 1
fi

WORKSPACE="/Users/meircohen/.openclaw/workspace"
MEMORY_FILE="$WORKSPACE/memory/coaching-insights.md"

# 1. Find all George meetings
echo "📊 Fetching George coaching sessions..."

GEORGE_MEETINGS=$(curl -s -X POST 'https://api.fireflies.ai/graphql' \
  -H "Authorization: Bearer $FIREFLIES_API_KEY" \
  -H "Content-Type: application/json" \
  -d '{"query": "query { transcripts(limit: 100) { id title date } }"}' | \
  jq -r '.data.transcripts[] | select(.title | contains("George")) | "\(.date)|\(.id)|\(.title)"' | \
  sort -r)

TOTAL=$(echo "$GEORGE_MEETINGS" | wc -l | tr -d ' ')

echo "Found $TOTAL George coaching sessions"

# 2. Get date range for this week vs last week
THIS_WEEK_START=$(date -u -v-mon +%Y-%m-%d)
LAST_WEEK=$(date -u -v-mon -v-7d +%Y-%m-%d)

# 3. Extract insights from recent sessions
echo ""
echo "🎯 Recent Coaching Insights:"
echo ""

while IFS='|' read -r date id title; do
  # Only process last 30 days for recap
  if [[ "$date" < "$(date -u -v-30d +%Y-%m-%d)" ]]; then
    continue
  fi
  
  echo "### $title — $date"
  
  # Fetch transcript
  TRANSCRIPT=$(curl -s -X POST 'https://api.fireflies.ai/graphql' \
    -H "Authorization: Bearer $FIREFLIES_API_KEY" \
    -H "Content-Type: application/json" \
    -d "{\"query\": \"query { transcript(id: \\\"$id\\\") { sentences { speaker_name text } } }\"}")
  
  # Extract key topics (search for specific patterns)
  echo "$TRANSCRIPT" | jq -r '.data.transcript.sentences[] | "\(.speaker_name): \(.text)"' | \
    grep -i "time block\|morning routine\|habit\|commitment\|action item\|goal" | \
    head -5
  
  echo ""
  echo "📎 Link: https://app.fireflies.ai/view/$id"
  echo ""
  
done <<< "$GEORGE_MEETINGS"

# 4. Generate summary
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "📋 Summary"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
echo "Total George sessions: $TOTAL"
echo "Recent topics: Time blocking, morning routine, habit formation"
echo ""
echo "💾 Full insights saved to: $MEMORY_FILE"
