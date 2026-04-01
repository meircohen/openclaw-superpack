#!/bin/bash
# x-alive.sh - X/Twitter automation toolkit
# Usage: bash scripts/x-alive.sh <scan|trending|engage>
set -e

CMD="$1"
shift 2>/dev/null || true

case "$CMD" in
  scan)
    twitter mentions --json 2>/dev/null | python3 -c "
import json, sys
data = json.loads(sys.stdin.read())
tweets = data.get('data', [])
print(f'{len(tweets)} recent mentions')
for t in tweets[:5]:
    print(f'  @{t.get(\"author_name\",\"?\")}: {t[\"text\"][:80]}')
"
    ;;
  engage)
    for user in levelsio LibsofTikTok sama; do
      echo "=== @$user ==="
      twitter user-posts "$user" --json 2>/dev/null | python3 -c "
import json, sys
try:
    data = json.loads(sys.stdin.read())
    for t in data.get('data', [])[:3]:
        likes = t.get('public_metrics', {}).get('like_count', 0)
        replies = t.get('public_metrics', {}).get('reply_count', 0)
        print(f'  [{likes} likes {replies} replies] {t[\"text\"][:80]}')
except: pass
"
    done
    ;;
  *)
    echo "Usage: bash scripts/x-alive.sh <scan|engage>"
    ;;
esac
