#!/usr/bin/env bash
# x-safe-post.sh — Anti-bot-detection wrapper for twitter CLI
# Adds human-like delays, jitter, rate tracking, and cooldown enforcement
#
# Usage:
#   x-safe-post.sh post "Tweet text here"
#   x-safe-post.sh reply <tweet_id> "Reply text here"
#   x-safe-post.sh quote <tweet_url> "Quote text here"
#   x-safe-post.sh batch <file.jsonl>   # batch post from file with auto-delays
#   x-safe-post.sh status               # show rate limit status
#   x-safe-post.sh reset                # reset rate tracking
#
# Anti-detection features:
#   - Random delay between posts (45-120s default)
#   - Tracks posts per hour/day, enforces X rate limits
#   - Exponential cooldown after 226 errors
#   - Human-like jitter on all timings
#   - Session tracking (won't exceed 5 posts/15min, 15 posts/hour, 50 posts/day)

set -euo pipefail

##############################################################################
# CONFIG
##############################################################################
STATE_DIR="$HOME/.openclaw/workspace/scripts/.x-rate-state"
STATE_FILE="$STATE_DIR/post-history.jsonl"
COOLDOWN_FILE="$STATE_DIR/cooldown-until"
CONFIG_FILE="$STATE_DIR/config.json"

mkdir -p "$STATE_DIR"
touch "$STATE_FILE"

# Default limits (conservative, well under X's actual limits)
MAX_PER_15MIN=5
MAX_PER_HOUR=15
MAX_PER_DAY=50
MIN_DELAY_SEC=45       # Minimum seconds between posts
MAX_DELAY_SEC=120      # Maximum seconds between posts
COOLDOWN_BASE_SEC=300  # 5 min cooldown after 226 error
MAX_COOLDOWN_SEC=3600  # Max 1 hour cooldown

##############################################################################
# HELPERS
##############################################################################

now_epoch() {
  date +%s
}

now_iso() {
  date -u +"%Y-%m-%dT%H:%M:%SZ"
}

random_between() {
  local min=$1 max=$2
  python3 -c "import random; print(random.randint($min, $max))"
}

human_jitter() {
  # Add 0-15 seconds of random jitter to simulate human behavior
  python3 -c "import random; print(random.uniform(0, 15))"
}

log_post() {
  local action="$1" tweet_id="$2" status="$3"
  echo "{\"ts\":$(now_epoch),\"iso\":\"$(now_iso)\",\"action\":\"$action\",\"tweet_id\":\"$tweet_id\",\"status\":\"$status\"}" >> "$STATE_FILE"
}

count_recent_posts() {
  local window_sec=$1
  local cutoff=$(($(now_epoch) - window_sec))
  python3 -c "
import json, sys
count = 0
for line in open('$STATE_FILE'):
    try:
        d = json.loads(line.strip())
        if d.get('status') == 'ok' and d.get('ts', 0) > $cutoff:
            count += 1
    except: pass
print(count)
"
}

check_cooldown() {
  if [[ -f "$COOLDOWN_FILE" ]]; then
    local until=$(cat "$COOLDOWN_FILE")
    local now=$(now_epoch)
    if [[ $now -lt $until ]]; then
      local remaining=$(( (until - now + 59) / 60 ))
      echo "🧊 COOLDOWN ACTIVE: ${remaining}min remaining (anti-bot protection triggered earlier)"
      echo "   Cooldown expires: $(date -r "$until" '+%H:%M:%S %Z' 2>/dev/null || date -d "@$until" '+%H:%M:%S %Z' 2>/dev/null)"
      return 1
    else
      rm -f "$COOLDOWN_FILE"
    fi
  fi
  return 0
}

set_cooldown() {
  local consecutive_fails=${1:-1}
  # Exponential backoff: 5min, 10min, 20min, 40min, max 60min
  local cooldown_sec=$((COOLDOWN_BASE_SEC * (2 ** (consecutive_fails - 1))))
  if [[ $cooldown_sec -gt $MAX_COOLDOWN_SEC ]]; then
    cooldown_sec=$MAX_COOLDOWN_SEC
  fi
  local until=$(( $(now_epoch) + cooldown_sec ))
  echo "$until" > "$COOLDOWN_FILE"
  echo "⚠️  Bot detection triggered (error 226). Cooling down for $((cooldown_sec / 60))min."
}

check_rate_limits() {
  local posts_15m=$(count_recent_posts 900)
  local posts_1h=$(count_recent_posts 3600)
  local posts_24h=$(count_recent_posts 86400)

  if [[ $posts_15m -ge $MAX_PER_15MIN ]]; then
    local wait=$((900 - $(now_epoch) + $(python3 -c "
import json
lines = open('$STATE_FILE').readlines()
for line in reversed(lines):
    d = json.loads(line)
    if d.get('status') == 'ok': print(d['ts']); break
" 2>/dev/null || echo "$(now_epoch)")))
    echo "🛑 Rate limit: ${posts_15m}/${MAX_PER_15MIN} posts in 15min. Wait ~$((wait/60))min."
    return 1
  fi

  if [[ $posts_1h -ge $MAX_PER_HOUR ]]; then
    echo "🛑 Rate limit: ${posts_1h}/${MAX_PER_HOUR} posts this hour."
    return 1
  fi

  if [[ $posts_24h -ge $MAX_PER_DAY ]]; then
    echo "🛑 Rate limit: ${posts_24h}/${MAX_PER_DAY} posts today."
    return 1
  fi

  return 0
}

wait_human_delay() {
  local delay=$(random_between $MIN_DELAY_SEC $MAX_DELAY_SEC)
  local jitter=$(human_jitter)
  local total=$(python3 -c "print(int($delay + $jitter))")

  # Check last post time
  local last_post_ts=$(python3 -c "
import json
lines = open('$STATE_FILE').readlines()
for line in reversed(lines):
    try:
        d = json.loads(line)
        if d.get('status') == 'ok':
            print(d['ts']); break
    except: pass
else:
    print(0)
" 2>/dev/null || echo "0")

  local elapsed=$(($(now_epoch) - last_post_ts))

  if [[ $elapsed -ge $total ]]; then
    # Already waited long enough naturally
    return 0
  fi

  local remaining=$((total - elapsed))
  echo "⏳ Human-like delay: waiting ${remaining}s before posting..."
  sleep "$remaining"
}

do_post() {
  local text="$1"
  local reply_to="${2:-}"

  # Pre-flight checks
  if ! check_cooldown; then return 1; fi

  # If rate limited, wait it out (in batch mode) or fail (in single mode)
  local rate_attempts=0
  while ! check_rate_limits 2>/dev/null; do
    if [[ "${BATCH_MODE:-false}" == "true" && $rate_attempts -lt 20 ]]; then
      echo "  ⏳ Rate limited. Waiting 60s... (attempt $((rate_attempts+1)))"
      sleep 60
      rate_attempts=$((rate_attempts + 1))
    else
      check_rate_limits  # Print the error message
      return 1
    fi
  done

  # Human delay (skip if first post in a while)
  wait_human_delay

  # Post
  local result
  if [[ -n "$reply_to" ]]; then
    result=$(twitter post --reply-to "$reply_to" "$text" 2>&1)
  else
    result=$(twitter post "$text" 2>&1)
  fi

  # Parse result
  if echo "$result" | grep -q "success: true\|ok: true"; then
    local tweet_id=$(echo "$result" | grep -o "id: '[0-9]*'" | head -1 | grep -o '[0-9]*')
    if [[ -z "$tweet_id" ]]; then
      tweet_id=$(echo "$result" | grep "id:" | head -1 | awk '{print $2}' | tr -d "'\"")
    fi
    local url=$(echo "$result" | grep "url:" | head -1 | awk '{print $2}')
    log_post "${reply_to:+reply}${reply_to:-post}" "$tweet_id" "ok"
    echo "✅ Posted! $url"
    return 0
  elif echo "$result" | grep -q "226\|automated\|bot"; then
    log_post "${reply_to:+reply}${reply_to:-post}" "" "226"
    # Count consecutive 226 errors
    local consecutive=$(python3 -c "
import json
count = 0
for line in reversed(open('$STATE_FILE').readlines()):
    d = json.loads(line)
    if d.get('status') == '226': count += 1
    else: break
print(count)
" 2>/dev/null || echo "1")
    set_cooldown "$consecutive"
    return 1
  elif echo "$result" | grep -q "shorter\|too long\|186"; then
    echo "❌ Tweet too long. Trim to 280 chars."
    return 1
  else
    log_post "${reply_to:+reply}${reply_to:-post}" "" "error"
    echo "❌ Failed: $result"
    return 1
  fi
}

##############################################################################
# COMMANDS
##############################################################################

cmd_post() {
  local text="$1"
  local char_count=${#text}
  echo "📝 Posting ($char_count chars)..."
  do_post "$text"
}

cmd_reply() {
  local tweet_id="$1"
  local text="$2"
  local char_count=${#text}
  echo "💬 Replying to $tweet_id ($char_count chars)..."
  do_post "$text" "$tweet_id"
}

cmd_batch() {
  local file="$1"
  if [[ ! -f "$file" ]]; then
    echo "❌ File not found: $file"
    return 1
  fi

  local total=$(wc -l < "$file" | tr -d ' ')
  local posted=0
  local failed=0

  echo "📋 Batch posting $total items from $file (auto-waits on rate limits)"
  echo ""
  export BATCH_MODE=true

  while IFS= read -r line; do
    local action=$(echo "$line" | python3 -c "import json,sys; print(json.load(sys.stdin).get('action','post'))")
    local text=$(echo "$line" | python3 -c "import json,sys; print(json.load(sys.stdin).get('text',''))")
    local reply_to=$(echo "$line" | python3 -c "import json,sys; print(json.load(sys.stdin).get('reply_to',''))")

    if [[ "$action" == "reply" && -n "$reply_to" ]]; then
      if cmd_reply "$reply_to" "$text"; then
        posted=$((posted + 1))
      else
        failed=$((failed + 1))
        # If cooldown triggered, stop batch
        if [[ -f "$COOLDOWN_FILE" ]]; then
          echo "🛑 Cooldown triggered. Stopping batch. ${posted} posted, $((total - posted - failed)) remaining."
          return 1
        fi
      fi
    else
      if cmd_post "$text"; then
        posted=$((posted + 1))
      else
        failed=$((failed + 1))
        if [[ -f "$COOLDOWN_FILE" ]]; then
          echo "🛑 Cooldown triggered. Stopping batch. ${posted} posted, $((total - posted - failed)) remaining."
          return 1
        fi
      fi
    fi
  done < "$file"

  echo ""
  echo "✅ Batch complete: $posted posted, $failed failed"
}

cmd_status() {
  local posts_15m=$(count_recent_posts 900)
  local posts_1h=$(count_recent_posts 3600)
  local posts_24h=$(count_recent_posts 86400)

  echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
  echo "📊 X POSTING STATUS"
  echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
  echo "  Last 15min: ${posts_15m}/${MAX_PER_15MIN}"
  echo "  Last hour:  ${posts_1h}/${MAX_PER_HOUR}"
  echo "  Last 24h:   ${posts_24h}/${MAX_PER_DAY}"
  echo ""

  if check_cooldown 2>/dev/null; then
    echo "  ✅ No cooldown active"
  fi

  echo ""
  echo "  Recent posts:"
  tail -5 "$STATE_FILE" 2>/dev/null | python3 -c "
import json, sys
from datetime import datetime
for line in sys.stdin:
    try:
        d = json.loads(line.strip())
        ts = datetime.fromtimestamp(d['ts']).strftime('%H:%M:%S')
        status = '✅' if d['status'] == 'ok' else '❌'
        print(f'    {status} {ts} {d[\"action\"]} {d.get(\"tweet_id\",\"\")}')
    except: pass
" 2>/dev/null
  echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
}

cmd_reset() {
  rm -f "$STATE_FILE" "$COOLDOWN_FILE"
  touch "$STATE_FILE"
  echo "✅ Rate state and cooldown reset"
}

##############################################################################
# MAIN
##############################################################################

ACTION="${1:-help}"
shift || true

case "$ACTION" in
  post)
    cmd_post "$*"
    ;;
  reply)
    TWEET_ID="$1"
    shift
    cmd_reply "$TWEET_ID" "$*"
    ;;
  batch)
    cmd_batch "$1"
    ;;
  status)
    cmd_status
    ;;
  reset)
    cmd_reset
    ;;
  help|--help|-h)
    echo "Usage:"
    echo "  x-safe-post.sh post \"Tweet text\""
    echo "  x-safe-post.sh reply <tweet_id> \"Reply text\""
    echo "  x-safe-post.sh batch <file.jsonl>"
    echo "  x-safe-post.sh status"
    echo "  x-safe-post.sh reset"
    echo ""
    echo "Anti-detection: human-like delays (45-120s), rate limits"
    echo "(5/15min, 15/hour, 50/day), exponential cooldown on 226 errors"
    ;;
  *)
    echo "Unknown command: $ACTION"
    echo "Run with --help for usage"
    exit 1
    ;;
esac
