---
name: fireflies
description: Extract action items, search meetings, and build intelligence from Fireflies.ai meeting transcripts. Use when processing meeting notes, searching past conversations, or preparing for calls with context.
---

# Fireflies Meeting Intelligence

## API Access
API Key stored in `~/.openclaw/.api-keys` as `FIREFLIES_API_KEY`

## Core Capabilities

### 1. Fetch Meeting Transcript
```bash
source ~/.openclaw/.api-keys

curl -s -X POST 'https://api.fireflies.ai/graphql' \
  -H 'Content-Type: application/json' \
  -H "Authorization: Bearer $FIREFLIES_API_KEY" \
  -d '{
    "query": "query Transcript($transcriptId: String!) { transcript(id: $transcriptId) { title date sentences { text speaker_name start_time end_time } } }",
    "variables": {
      "transcriptId": "MEETING_ID"
    }
  }'
```

### 2. List Recent Meetings
```bash
curl -s -X POST 'https://api.fireflies.ai/graphql' \
  -H 'Content-Type: application/json' \
  -H "Authorization: Bearer $FIREFLIES_API_KEY" \
  -d '{
    "query": "query { transcripts(limit: 10) { id title date } }"
  }'
```

### 3. Search Meetings
```bash
# Search by participant
curl -s -X POST 'https://api.fireflies.ai/graphql' \
  -H 'Content-Type: application/json' \
  -H "Authorization: Bearer $FIREFLIES_API_KEY" \
  -d '{
    "query": "query { transcripts(limit: 20) { id title date participants } }"
  }' | jq '.data.transcripts[] | select(.participants[] | contains("George"))'
```

## Use Cases

### Action Item Extraction
When processing a meeting:
1. Fetch transcript
2. Search for commitment patterns:
   - "I'll [action]"
   - "We need to [action]"
   - "Follow up on [topic]"
   - "[Person] will [action]"
3. Extract owner, action, deadline (if mentioned)
4. Create task in Apple Reminders or Todoist
5. Log to `state/fireflies-action-items.json`

### Pre-Meeting Context
Before a call with [Person]:
1. Search all transcripts with that person
2. Extract:
   - Last meeting date
   - Key topics discussed
   - Action items assigned
   - Open questions/decisions pending
3. Format as brief: "Last met [date], discussed [topics], action items: [list]"

### Coaching Session Tracking
For recurring coaching (e.g., George):
1. Fetch all sessions with coach
2. Extract insights by topic:
   - Time management advice
   - Habit formation guidance
   - Commitments made
   - Progress tracking
3. Build knowledge base in `memory/coaching-insights.md`

### Meeting Search
"What did [person] say about [topic]?"
1. Fetch all meetings with that person
2. Search transcript sentences for topic keywords
3. Return relevant excerpts with context

### Weekly Intelligence Report
Every Monday morning:
1. Fetch last week's meetings
2. Extract:
   - Total meetings
   - Key participants
   - Action items assigned to you
   - Action items assigned to others
   - Recurring topics
3. Compile report for weekly review

## Integration Points

### Meeting Prep Skill
Enhance `meeting-prep` to pull Fireflies context:
```markdown
**Previous meetings:**
- [Date]: Key topics discussed
- Action items from last call: [list]
- Open questions: [list]
```

### Daily Digest
Add to morning digest:
```markdown
**Yesterday's meeting action items:**
- [Action 1] - from [Meeting] with [Person]
- [Action 2] - deadline [date]
```

### Memory System
Store coaching insights:
```markdown
## George Coaching Insights

### Morning Routine (Feb 27, 2026)
- Structure: Gym → Shower → Prayer → Task hour
- Time-blocking: Start with mornings, expand gradually
- Goal: Squeeze out time waste incrementally
```

## State Files

### Processed Meetings
`state/fireflies-processed.json`:
```json
{
  "processed": [
    {
      "id": "01KJG0MFN6ZA43FFSV0DDRJYV5",
      "title": "Meir / George",
      "date": "2026-02-27",
      "action_items_extracted": true,
      "insights_saved": true
    }
  ]
}
```

### Action Items
`state/fireflies-action-items.json`:
```json
{
  "items": [
    {
      "meeting_id": "01KJG0MFN6ZA43FFSV0DDRJYV5",
      "meeting_title": "Meir / George",
      "date": "2026-02-27",
      "action": "Create morning time block: Gym → Shower → Prayer → Task hour",
      "owner": "Meir",
      "deadline": null,
      "completed": false
    }
  ]
}
```

## Common Queries

### Find George coaching sessions
```bash
source ~/.openclaw/.api-keys
curl -s -X POST 'https://api.fireflies.ai/graphql' \
  -H 'Content-Type: application/json' \
  -H "Authorization: Bearer $FIREFLIES_API_KEY" \
  -d '{"query": "query { transcripts(limit: 50) { id title date } }"}' | \
  jq '.data.transcripts[] | select(.title | contains("George"))'
```

### Search for topic across all meetings
```bash
# Fetch recent meetings, search transcripts for keyword
# Example: Find all mentions of "morning routine"
```

### Extract action items from specific meeting
```bash
# 1. Fetch transcript
# 2. Grep for "I'll", "we need to", "follow up", etc.
# 3. Parse context (who, what, when)
# 4. Create tasks
```

## Error Handling

- **401 Unauthorized:** Check `FIREFLIES_API_KEY` in `.api-keys`
- **Meeting not found:** Verify meeting ID is correct
- **No transcripts:** Meeting may still be processing
- **Rate limits:** Fireflies has API rate limits, cache aggressively

## Future Enhancements

1. **Real-time processing:** Webhook when new meeting finishes
2. **Smart summaries:** LLM-generated meeting summaries
3. **Topic tracking:** Build topic graph across all meetings
4. **Sentiment analysis:** Track tone in key relationships
5. **Decision log:** Extract decisions made, track reversals
6. **Commitment tracker:** "You promised X to Y on [date], did it happen?"

## Testing

Test API access:
```bash
source ~/.openclaw/.api-keys
curl -s -X POST 'https://api.fireflies.ai/graphql' \
  -H 'Content-Type: application/json' \
  -H "Authorization: Bearer $FIREFLIES_API_KEY" \
  -d '{"query": "query { transcripts(limit: 1) { id title } }"}' | jq
```

Should return JSON with recent meeting(s).
