# Skill: Tweet Original

You are composing an original tweet (or thread) for the user's account. The goal: content that sounds like it came from a real person who builds and ships, not a content bot.

## Inputs
Brief includes: `topic`, `angle`, `voice`, `media`, `max_length`, `thread_count`.

## Steps

### 1. Read the voice guide
Read `skills/delegation/voice/{voice}.md`. This is non-negotiable -- internalize before writing.

### 2. Research the topic (if needed)
If the topic is about current events or trending:
```bash
bash scripts/search.sh "topic keywords" 5
```
Get facts and context. Don't post stale takes.

### 3. Pick your angle
- **war-story**: Something that actually happened. Specifics > generalities. Include numbers.
- **insight**: A non-obvious observation. The "thing everyone's missing."
- **hot-take**: Contrarian position. Must have substance behind it.
- **thread**: Multi-tweet breakdown. Each tweet must stand alone AND build on prior.

### 4. Draft the tweet
Write it. Then apply these filters:

**The 5-Second Test:**
1. Would this get scrolled past? -> Stronger hook needed
2. Is this generic advice? -> Add the user's specific experience
3. Are there AI-tell phrases? -> Strip them (see voice guide banned list)
4. Is this longer than it needs to be? -> Cut ruthlessly
5. Does the first line earn the second line? -> If not, rewrite the first line

**For threads:**
- Tweet 1 = hook. Must create curiosity.
- Each tweet = one idea. No run-on thoughts.
- Last tweet = punchline or call to action.
- Number them: "1/" "2/" etc.

### 5. Post it
Single tweet:
```bash
twitter post "your tweet text"
```

Thread:
```bash
# Post first tweet, capture ID
twitter post "1/ First tweet" --json | jq -r '.id'
# Reply to create thread
twitter post "2/ Second tweet" --reply-to FIRST_TWEET_ID
```

### 6. Verify
```bash
twitter search "from:USERNAME" --json | head -3
```
Confirm the tweet exists and content matches.

### 7. Log
Append to log file:
```json
{"timestamp":"ISO","type":"original","tweet_id":"...","text":"...","angle":"...","voice":"...","verified":true}
```

## Common Pitfalls
- `media: none` is default. Don't generate images unless brief says otherwise.
- Numbers must be verified. "Vague > Wrong" -- say "a few months" not "6 months" if unsure.
- Don't post at bad times (check time-awareness script if available).
- If the draft doesn't pass the 5-second test after 2 rewrites, ask for direction instead of posting mediocre content.

## Success = All of these are true:
- [ ] Tweet matches the requested angle and voice
- [ ] No AI-tell phrases (checked against banned list)
- [ ] Posted and verified via twitter CLI
- [ ] Logged to engagement log
- [ ] Under character limit
