# Verification: Tweet Original

Run these checks BEFORE reporting completion.

## Checks

### 1. Tweet exists
```bash
twitter search "from:USERNAME" --json | jq '.[0:3]'
```
- [ ] Tweet ID exists in search results
- [ ] Text matches your draft (no truncation, no corruption)
- [ ] If thread: all tweets in thread exist and are properly chained

### 2. Content quality
- [ ] Matches requested angle (war-story/insight/hot-take/thread)
- [ ] Under character limit (280 per tweet, or as specified)
- [ ] No AI tell phrases (check banned list)
- [ ] First line earns the second line (hook test)
- [ ] Specific details, not generic advice

### 3. Factual accuracy
- [ ] Any numbers mentioned are verified or explicitly approximate
- [ ] Any dates mentioned are correct
- [ ] No claims that could be publicly disproven

### 4. Log updated
```bash
tail -3 {log_to}
```
- [ ] JSON log entry exists with: timestamp, type, tweet_id, text, angle, voice, verified
- [ ] `verified: true`

### 5. Media (if applicable)
- [ ] If `media: freeze-card` -- image was generated and attached
- [ ] If `media: generated` -- image was generated and attached
- [ ] If `media: none` -- no media attached (don't add unrequested media)

## If Any Check Fails
Report which check failed and what you found. Do NOT claim success.
