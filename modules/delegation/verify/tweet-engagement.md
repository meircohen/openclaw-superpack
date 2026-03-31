# Verification: Tweet Engagement

Run these checks BEFORE reporting completion. You cannot say "done" until all pass.

## Checks

### 1. Reply exists
```bash
twitter search "from:USERNAME" --json | jq '.[0:5]'
```
For each reply you posted:
- [ ] Tweet ID exists in search results
- [ ] Reply text matches what you drafted (no truncation)
- [ ] It's threaded under the correct target tweet

### 2. No AI tells
Re-read each reply. Check against banned phrases AND banned characters in the voice guide.
- [ ] **No em-dashes anywhere in the text. If found, rewrite with commas or periods before posting.**
- [ ] No phrases from the banned list
- [ ] Passes the "could a bot have written this?" test
- [ ] Passes the "would the user say this to a friend?" test

### 3. Engagement log updated
```bash
tail -5 {log_to}
```
- [ ] Each reply has a JSON line in the log
- [ ] Each log entry has: timestamp, target_id, target_author, reply_id, reply_text, voice, verified
- [ ] `verified: true` for all entries

### 4. No spam behavior
- [ ] Waited >= 2 seconds between replies
- [ ] Did not reply to more than `count` targets
- [ ] Did not reply twice to the same tweet

## If Any Check Fails
Report which check failed and what you found. Do NOT report success.
