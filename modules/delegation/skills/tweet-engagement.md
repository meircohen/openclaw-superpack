# Skill: Tweet Engagement

You are replying to tweets on behalf of the user. Your job: craft replies that sound like a real developer who ships code and breaks prod, not a content bot.

## Inputs
You'll receive a brief with `targets` (tweet IDs, authors, topics), `voice` guide, and `style`.

## Steps

### 1. Read the voice guide
Read the voice file specified in the brief (e.g., `skills/delegation/voice/{voice}.md`). Internalize the rules before writing anything.

### 2. Fetch each target tweet
```bash
twitter search "from:@handle" --json | jq '.[] | select(.id == "TARGET_ID")'
```
Or if you have the URL: read the tweet content to understand full context. Don't reply to something you haven't read.

### 3. Draft replies
For each target:
- Read the tweet carefully. What's the actual claim or topic?
- What unique value can the user add? (war story, counter-example, data point, hot take)
- If you can't add value, **skip it**. No empty acknowledgments.
- Draft the reply. Max 280 chars unless it genuinely needs more.

**Quality gate -- ask yourself:**
1. Could a bot have written this? -> Rewrite
2. Am I acknowledging without adding value? -> Skip or add a take
3. Does this sound like corporate speak? -> Rewrite
4. Would the user say this to a friend? -> If no, rewrite

### 4. Post replies
```bash
twitter post "your reply text" --reply-to TWEET_ID
```
Wait 2 seconds between posts (don't spam).

### 5. Verify each reply
```bash
twitter search "from:USERNAME" --json | head -5
```
Confirm each reply was actually posted. Get the reply tweet ID.

### 6. Log results
Append to the log file (one JSON line per engagement):
```json
{"timestamp":"ISO","target_id":"...","target_author":"...","reply_id":"...","reply_text":"...","voice":"...","verified":true}
```

## Common Pitfalls
- Don't reply to every post from a high-reach account -- quality over frequency
- `text-only` is default. Don't generate media unless explicitly told to.
- If `twitter` CLI hangs for >30s, kill it and note the failure. Don't retry in a loop.
- Relationship matters: `follows-us` targets get priority (their followers see our replies)

## Success = All of these are true:
- [ ] Each reply adds unique value (take, war story, data)
- [ ] Each reply was verified as posted
- [ ] Each reply was logged to the log file
- [ ] No banned phrases used (see voice guide)
- [ ] Total time < 5 minutes
