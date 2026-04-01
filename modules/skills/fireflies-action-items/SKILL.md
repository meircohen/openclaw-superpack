---
name: fireflies-action-items
description: Automatically extract and create tasks from Fireflies meeting transcripts. Use when processing new meetings or during daily digest to capture action items.
---

# Fireflies Action Items — Auto-Processing

## Purpose
Automatically extract action items from Fireflies meetings and create tasks.

## When to Use
- Daily digest (check for new meetings from yesterday)
- Post-meeting automation (10 min after meeting ends)
- Manual: "Process action items from [meeting]"
- Weekly review: "What action items are still open from last week?"

## Execution Flow

### 1. Check for new meetings
```bash
source ~/.openclaw/.api-keys

# Get meetings from last 7 days
curl -s -X POST 'https://api.fireflies.ai/graphql' \
  -H "Authorization: Bearer $FIREFLIES_API_KEY" \
  -H "Content-Type: application/json" \
  -d '{"query": "query { transcripts(limit: 20) { id title date } }"}' | \
  jq -r '.data.transcripts[] | select(.date >= "'$(date -u -v-7d +%Y-%m-%d)'") | "\(.id)|\(.title)|\(.date)"'
```

### 2. Check if already processed
```bash
# Load processed meetings
PROCESSED=$(jq -r '.processed[].id' state/fireflies-processed.json)

# Filter out already processed
for meeting in $(get_new_meetings); do
  if ! echo "$PROCESSED" | grep -q "$meeting"; then
    process_meeting "$meeting"
  fi
done
```

### 3. Extract action items
Fetch transcript and search for commitment patterns:

**Commitment patterns to detect:**
- "I'll [action]"
- "I will [action]"
- "We need to [action]"
- "We should [action]"
- "[Name] will [action]"
- "Follow up on [topic]"
- "Action item: [action]"
- "TODO: [action]"
- "Next step is [action]"
- "By [date], we'll [action]"

**Context extraction:**
- Who said it (speaker_name)
- What is the action
- When is it due (if mentioned)
- Who owns it (assign to Meir if unclear)

### 4. Create tasks
For each action item:

**Apple Reminders (primary):**
```bash
# Using remindctl
remindctl add "Action from [Meeting]: [action text]" \
  --notes "Owner: [person]\nMeeting: [meeting title] ([date])\nFireflies: https://app.fireflies.ai/view/[id]" \
  --list "Work" \
  --due "[date if mentioned]"
```

**Todoist (if configured):**
```bash
source ~/.openclaw/workspace/.env
todoist-cli add "[action]" \
  --description "From: [meeting] with [people]\nFireflies: [link]" \
  --due "[date]" \
  --priority 3 \
  --labels "meeting,fireflies"
```

### 5. Log processed meeting
```bash
# Add to state/fireflies-processed.json
jq '.processed += [{
  "id": "'$MEETING_ID'",
  "title": "'$MEETING_TITLE'",
  "date": "'$MEETING_DATE'",
  "action_items_extracted": true,
  "num_items": '$NUM_ITEMS',
  "processed_at": "'$(date -u +%Y-%m-%dT%H:%M:%SZ)'"
}]' state/fireflies-processed.json > /tmp/fireflies.json
mv /tmp/fireflies.json state/fireflies-processed.json
```

### 6. Update action items log
```bash
# Add each item to state/fireflies-action-items.json
jq '.items += [{
  "meeting_id": "'$MEETING_ID'",
  "meeting_title": "'$MEETING_TITLE'",
  "date": "'$MEETING_DATE'",
  "action": "'$ACTION_TEXT'",
  "owner": "'$OWNER'",
  "deadline": "'$DEADLINE'",
  "completed": false,
  "task_id": "'$TASK_ID'",
  "created_at": "'$(date -u +%Y-%m-%dT%H:%M:%SZ)'"
}]' state/fireflies-action-items.json > /tmp/actions.json
mv /tmp/actions.json state/fireflies-action-items.json
```

## Output Format

Return summary:
```
**Meeting Action Items: [Meeting Title] ([Date])**

✅ Created 3 tasks:
1. [Action 1] — Owner: Meir, Due: [date]
2. [Action 2] — Owner: George, FYI only
3. [Action 3] — Owner: Meir, Due: Next week

📎 Fireflies link: https://app.fireflies.ai/view/[id]
```

If no action items:
```
**Meeting: [Title] ([Date])**
No action items detected.
```

## Deduplication Rules

Before creating a task:
1. Check if similar action already exists in last 7 days
2. Normalize text (lowercase, remove punctuation)
3. If >80% similarity → skip, add note to existing task
4. If deadline changed → update existing task

## Owner Assignment Logic

**Assign to Meir if:**
- Speaker is Meir
- Statement: "I'll", "I will", "I need to"
- Context implies Meir's responsibility

**Assign to other person if:**
- Speaker is other person
- Statement: "[Other person] will"
- Explicitly delegated

**FYI only (don't create task) if:**
- Action assigned to someone else
- No follow-up needed from Meir
- Informational only

## Daily Digest Integration

Add to morning digest:
```
**Yesterday's Meeting Action Items (X new):**
- [Action 1] from [Meeting] with [Person]
- [Action 2] from [Meeting] — due [date]

📋 Total open action items: X
```

## Weekly Review Integration

Every Monday:
```
**Last Week's Meeting Action Items:**

✅ Completed: X
⏳ Still open: Y
🔴 Overdue: Z

Top unfinished items:
- [Action 1] from [Meeting] ([days ago])
- [Action 2] from [Meeting] ([days ago])
```

## George Coaching Special Handling

For meetings with George:
- Extract insights separately (time management, habits, commitments)
- Don't create tasks for general advice
- DO create tasks for specific commitments (e.g., "Start morning time block")
- Save insights to `memory/coaching-insights.md`

## Error Handling

- **No API key:** Alert user to add `FIREFLIES_API_KEY`
- **Meeting not found:** Log and skip
- **Transcript still processing:** Retry in 1 hour
- **Task creation failed:** Log to `state/fireflies-errors.json`

## Testing

Test on George meeting:
```bash
scripts/fireflies-helper.sh extract_actions 01KJG0MFN6ZA43FFSV0DDRJYV5
```

Should detect: "Create morning time block: Gym → Shower → Prayer → Task hour"
