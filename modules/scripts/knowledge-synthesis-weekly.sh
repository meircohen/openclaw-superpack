#!/bin/bash
# Weekly Knowledge Synthesis — Extract insights from meetings, daily notes, conversations
# Runs Monday morning, included in weekly digest

set -euo pipefail

WORKSPACE="$HOME/.openclaw/workspace"
MEMORY_DIR="$WORKSPACE/memory"
STATE_DIR="$WORKSPACE/state"
OUTPUT_FILE="$STATE_DIR/weekly-insights-$(date +%Y-%m-%d).md"

# Date range for this week
WEEK_START=$(date -v-7d +%Y-%m-%d)
WEEK_END=$(date +%Y-%m-%d)

echo "# Weekly Knowledge Synthesis" > "$OUTPUT_FILE"
echo "**Period:** $WEEK_START to $WEEK_END" >> "$OUTPUT_FILE"
echo "" >> "$OUTPUT_FILE"

## 1. MEETING INTELLIGENCE (from Fireflies)

echo "## 📅 Meeting Intelligence" >> "$OUTPUT_FILE"
echo "" >> "$OUTPUT_FILE"

source ~/.openclaw/.api-keys

# Fetch last week's meetings
MEETINGS_QUERY='{"query": "query { transcripts(limit: 20) { id title date participants } }"}'

MEETINGS=$(curl -s -X POST 'https://api.fireflies.ai/graphql' \
  -H 'Content-Type: application/json' \
  -H "Authorization: Bearer $FIREFLIES_API_KEY" \
  -d "$MEETINGS_QUERY")

# Filter to last 7 days
WEEK_START_MS=$(($(date -j -f "%Y-%m-%d" "$WEEK_START" +%s) * 1000))
WEEK_MEETINGS=$(echo "$MEETINGS" | jq -r --argjson start "$WEEK_START_MS" '
  .data.transcripts[] | 
  select(.date >= $start) | 
  "\(.title) | \((.date/1000) | strftime("%Y-%m-%d"))"
')

MEETING_COUNT=$(echo "$WEEK_MEETINGS" | wc -l | tr -d ' ')

echo "**Total meetings this week:** $MEETING_COUNT" >> "$OUTPUT_FILE"
echo "" >> "$OUTPUT_FILE"

if [[ $MEETING_COUNT -gt 0 ]]; then
  echo "**Meetings:**" >> "$OUTPUT_FILE"
  echo "$WEEK_MEETINGS" | sed 's/^/  • /' >> "$OUTPUT_FILE"
  echo "" >> "$OUTPUT_FILE"
  
  # Extract recurring participants
  RECURRING=$(echo "$MEETINGS" | jq -r --argjson start "$WEEK_START_MS" '
    [.data.transcripts[] | select(.date >= $start) | .participants[]?] | 
    group_by(.) | 
    map({name: .[0], count: length}) | 
    sort_by(-.count) | 
    .[] | 
    select(.count > 1) | 
    "\(.name) (\(.count) meetings)"
  ')
  
  if [[ -n "$RECURRING" ]]; then
    echo "**Recurring participants:**" >> "$OUTPUT_FILE"
    echo "$RECURRING" | head -5 | sed 's/^/  • /' >> "$OUTPUT_FILE"
    echo "" >> "$OUTPUT_FILE"
  fi
fi

## 2. DAILY NOTES PATTERNS (from memory/)

echo "## 📝 Daily Notes Patterns" >> "$OUTPUT_FILE"
echo "" >> "$OUTPUT_FILE"

# Check last 7 daily notes for recurring themes
DAILY_NOTES=$(find "$MEMORY_DIR" -name "2026-*.md" -type f -mtime -7 | sort)

if [[ -n "$DAILY_NOTES" ]]; then
  # Extract recurring keywords (simple frequency analysis)
  KEYWORDS=$(cat $DAILY_NOTES 2>/dev/null | \
    tr '[:upper:]' '[:lower:]' | \
    grep -oE '\b[a-z]{4,}\b' | \
    sort | uniq -c | sort -rn | head -10 | \
    awk '$1 > 2 {print "  • " $2 " (" $1 " mentions)"}')
  
  if [[ -n "$KEYWORDS" ]]; then
    echo "**Recurring themes (word frequency):**" >> "$OUTPUT_FILE"
    echo "$KEYWORDS" >> "$OUTPUT_FILE"
    echo "" >> "$OUTPUT_FILE"
  fi
fi

## 3. ACTION ITEMS STATUS (from Todoist integration)

echo "## ✅ Action Items Status" >> "$OUTPUT_FILE"
echo "" >> "$OUTPUT_FILE"

if [[ -f "$STATE_DIR/fireflies-action-items.json" ]]; then
  OPEN_ITEMS=$(jq -r '[.[] | select(.status == "open")] | length' "$STATE_DIR/fireflies-action-items.json" 2>/dev/null || echo "0")
  COMPLETED_ITEMS=$(jq -r '[.[] | select(.status == "completed")] | length' "$STATE_DIR/fireflies-action-items.json" 2>/dev/null || echo "0")
  
  echo "**This week:**" >> "$OUTPUT_FILE"
  echo "  • Open: $OPEN_ITEMS" >> "$OUTPUT_FILE"
  echo "  • Completed: $COMPLETED_ITEMS" >> "$OUTPUT_FILE"
  
  if [[ $COMPLETED_ITEMS -gt 0 && $OPEN_ITEMS -gt 0 ]]; then
    COMPLETION_RATE=$((COMPLETED_ITEMS * 100 / (COMPLETED_ITEMS + OPEN_ITEMS)))
    echo "  • Completion rate: ${COMPLETION_RATE}%" >> "$OUTPUT_FILE"
  fi
  echo "" >> "$OUTPUT_FILE"
fi

## 4. MEMORY BLOCK CHANGES (from memory/blocks/)

echo "## 🧠 Memory Updates" >> "$OUTPUT_FILE"
echo "" >> "$OUTPUT_FILE"

# Check which memory blocks were updated this week
UPDATED_BLOCKS=$(find "$MEMORY_DIR/blocks" -name "*.md" -type f -mtime -7 2>/dev/null | xargs -I {} basename {} .md)

if [[ -n "$UPDATED_BLOCKS" ]]; then
  echo "**Updated blocks:**" >> "$OUTPUT_FILE"
  echo "$UPDATED_BLOCKS" | sed 's/^/  • /' >> "$OUTPUT_FILE"
  echo "" >> "$OUTPUT_FILE"
fi

## 5. SYNTHESIS PROMPT (for AI to process)

echo "## 🎯 Insights to Extract" >> "$OUTPUT_FILE"
echo "" >> "$OUTPUT_FILE"
echo "_This section will be processed by AI to extract patterns and insights._" >> "$OUTPUT_FILE"
echo "" >> "$OUTPUT_FILE"
echo "**Questions to answer:**" >> "$OUTPUT_FILE"
echo "1. What patterns emerged across multiple meetings?" >> "$OUTPUT_FILE"
echo "2. Which commitments were kept vs missed?" >> "$OUTPUT_FILE"
echo "3. What topics consumed the most time?" >> "$OUTPUT_FILE"
echo "4. Which relationships deepened (recurring participants)?" >> "$OUTPUT_FILE"
echo "5. What's the delta between goals (active_guidance) and actual behavior?" >> "$OUTPUT_FILE"
echo "" >> "$OUTPUT_FILE"

# Output file location
echo "✓ Weekly synthesis data compiled: $OUTPUT_FILE"
echo ""
echo "Next step: Process with AI to extract insights"
echo "Command: openclaw message send --message \"Analyze $(basename $OUTPUT_FILE) and extract top 3 insights\""
