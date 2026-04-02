#!/bin/bash
# Drain one pending reply from the queue and post it
# Designed to be called by cron every 15 minutes

QUEUE="/Users/meircohen/.openclaw/workspace/state/x-twitter/pending-replies.json"
LOG="/Users/meircohen/.openclaw/workspace/state/x-twitter/x-engagement-log.jsonl"
export PATH="/Users/meircohen/.local/bin:$PATH"

if [ ! -f "$QUEUE" ]; then
  echo "NO_QUEUE"
  exit 0
fi

# Get first pending item
ITEM=$(python3 -c "
import json
with open('$QUEUE') as f:
    items = json.load(f)
pending = [i for i in items if i.get('status') == 'pending']
if not pending:
    print('EMPTY')
else:
    print(json.dumps(pending[0]))
")

if [ "$ITEM" = "EMPTY" ]; then
  echo "QUEUE_EMPTY"
  exit 0
fi

TARGET_ID=$(echo "$ITEM" | python3 -c "import json,sys; print(json.load(sys.stdin)['target_id'])")
REPLY_TEXT=$(echo "$ITEM" | python3 -c "import json,sys; print(json.load(sys.stdin)['reply'])")
AUTHOR=$(echo "$ITEM" | python3 -c "import json,sys; print(json.load(sys.stdin)['author'])")

echo "Posting reply to $AUTHOR (tweet $TARGET_ID)..."
RESULT=$(twitter reply "$TARGET_ID" "$REPLY_TEXT" --json 2>&1)
echo "$RESULT"

# Check if success
OK=$(echo "$RESULT" | python3 -c "import json,sys; data=json.load(sys.stdin); print(data.get('ok', False))" 2>/dev/null)

if [ "$OK" = "True" ]; then
  # Mark as posted in queue
  python3 -c "
import json
with open('$QUEUE') as f:
    items = json.load(f)
for i in items:
    if i['target_id'] == '$TARGET_ID' and i['status'] == 'pending':
        i['status'] = 'posted'
        break
with open('$QUEUE', 'w') as f:
    json.dump(items, f, indent=2)
print('POSTED: $AUTHOR')
"
  # Log it
  echo "{\"action\":\"reply\",\"target\":\"$TARGET_ID\",\"author\":\"$AUTHOR\",\"timestamp\":\"$(date -u +%Y-%m-%dT%H:%M:%SZ)\",\"status\":\"posted\"}" >> "$LOG"
else
  echo "FAILED - will retry next cycle"
fi
