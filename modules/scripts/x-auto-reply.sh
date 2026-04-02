#!/usr/bin/env bash
# x-auto-reply.sh - Monitor X mentions and auto-reply

set -euo pipefail

WORKSPACE="/Users/meircohen/.openclaw/workspace"
STATE_FILE="$WORKSPACE/state/x-last-mention-check.txt"
LOG_FILE="$WORKSPACE/logs/x-auto-reply.log"
TWITTER_CLI="/Users/meircohen/Library/Python/3.9/bin/twitter"

mkdir -p "$WORKSPACE/logs" "$WORKSPACE/state"

# Get last check timestamp (default to 2 hours ago)
LAST_CHECK=$(cat "$STATE_FILE" 2>/dev/null || date -u -v-2H +%s)
CURRENT_TIME=$(date -u +%s)

# Search for recent mentions
MENTIONS=$("$TWITTER_CLI" search "@MeirCohen" --json 2>/dev/null | \
  /usr/bin/python3 -c "
import json, sys
try:
    d = json.load(sys.stdin)
except:
    sys.exit(0)
last_check = int('$LAST_CHECK')
for tweet in d.get('data', []):
    if tweet['author']['screenName'].lower() == 'meircohen':
        continue
    from datetime import datetime
    created = datetime.strptime(tweet['createdAt'], '%a %b %d %H:%M:%S %z %Y')
    tweet_time = int(created.timestamp())
    if tweet_time > last_check:
        print(json.dumps({
            'id': tweet['id'],
            'author': tweet['author']['screenName'],
            'text': tweet['text'][:200],
            'timestamp': tweet_time
        }))
" 2>/dev/null) || true

# If no new mentions, exit
if [ -z "$MENTIONS" ]; then
    echo "$(date): No new mentions" >> "$LOG_FILE"
    echo "$CURRENT_TIME" > "$STATE_FILE"
    exit 0
fi

# Process each mention via openclaw agent
echo "$MENTIONS" | while IFS= read -r mention; do
    TWEET_ID=$(echo "$mention" | jq -r .id)
    AUTHOR=$(echo "$mention" | jq -r .author)
    TEXT=$(echo "$mention" | jq -r .text)

    echo "$(date): New mention from @$AUTHOR (ID: $TWEET_ID)" >> "$LOG_FILE"

    # Use openclaw agent to handle the reply
    openclaw agent \
      --session-id "x-auto-reply" \
      --message "New X mention needs a reply. Draft and post it.

From: @$AUTHOR
Tweet ID: $TWEET_ID
Text: $TEXT

Rules:
- Max 280 chars
- Short, punchy, have a take
- Use: $TWITTER_CLI post \"REPLY\" --reply-to $TWEET_ID
- Follow voice from artifacts/x-engagement-voice-update.md
- Skip if it's spam or not worth replying to" \
      --timeout 30 2>>"$LOG_FILE" || echo "$(date): Agent failed for $TWEET_ID" >> "$LOG_FILE"
done

# Update last check timestamp
echo "$CURRENT_TIME" > "$STATE_FILE"
