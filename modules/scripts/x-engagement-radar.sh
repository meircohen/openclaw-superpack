#!/usr/bin/env bash
# x-engagement-radar.sh — Real-time monitoring of target accounts for reply opportunities
# Usage: ./x-engagement-radar.sh [--since MINUTES] [--json]
# Default: checks for posts in the last 5 minutes
set -euo pipefail

##############################################################################
# CONFIG
##############################################################################
TARGETS=(
  libsoftiktok MarioNawfal paulg balajis levelsio
  ShaanVP Jason dhh rowancheung wolfejosh
  Awesome_Jew_ darrenmarble briankrebs larrykim winniesun
)

SINCE_MINUTES="${1:-5}"
JSON_OUTPUT=false
[[ "${1:-}" == "--json" || "${2:-}" == "--json" ]] && JSON_OUTPUT=true
[[ "${1:-}" == "--since" ]] && SINCE_MINUTES="${2:-5}" && shift 2 2>/dev/null || true

STATE_DIR="$HOME/.openclaw/workspace/scripts/.radar-state"
mkdir -p "$STATE_DIR"

# Compute cutoff timestamp (Unix epoch)
if [[ "$OSTYPE" == darwin* ]]; then
  CUTOFF=$(date -v-${SINCE_MINUTES}M +%s 2>/dev/null || date -d "${SINCE_MINUTES} minutes ago" +%s)
else
  CUTOFF=$(date -d "${SINCE_MINUTES} minutes ago" +%s)
fi

##############################################################################
# HELPERS
##############################################################################
parse_twitter_date() {
  # Input: "Tue Mar 17 04:33:22 +0000 2026"
  # Output: Unix timestamp
  local d="$1"
  if [[ "$OSTYPE" == darwin* ]]; then
    python3 -c "
from email.utils import parsedate_tz, mktime_tz
import sys
# Convert Twitter format to RFC 2822-ish
d = '$d'
parts = d.split()
# 'Tue Mar 17 04:33:22 +0000 2026' -> rearrange
rfc = f'{parts[0]} {parts[2]} {parts[1]} {parts[5]} {parts[3]} {parts[4]}'
t = parsedate_tz(rfc)
if t:
    print(mktime_tz(t))
else:
    print(0)
" 2>/dev/null
  else
    date -d "$d" +%s 2>/dev/null || echo 0
  fi
}

suggest_reply_angle() {
  local handle="$1"
  local text="$2"

  # Keyword-based angle suggestion
  local text_lower
  text_lower=$(echo "$text" | tr '[:upper:]' '[:lower:]')

  if echo "$text_lower" | grep -qiE "ai|artificial intelligence|llm|gpt|claude|agent"; then
    echo "🤖 AI angle: Share your experience running 55+ AI agents via OpenClaw. Concrete numbers > theory."
  elif echo "$text_lower" | grep -qiE "startup|founder|build|ship|launch|product"; then
    echo "🚀 Founder angle: Relate to building TrapCall/RoboKiller/SpoofCard. Non-technical founder perspective."
  elif echo "$text_lower" | grep -qiE "israel|jewish|antisemit|hamas|gaza|zion"; then
    echo "🇮🇱 Israel/Jewish angle: Share perspective as proud Jew. Keep factual, link personal connection."
  elif echo "$text_lower" | grep -qiE "security|hack|breach|cyber|privacy"; then
    echo "🔒 Security angle: Tie to TrapCall/RoboKiller privacy expertise. Real-world caller protection."
  elif echo "$text_lower" | grep -qiE "politic|trump|biden|congress|democrat|republican|conservative|liberal"; then
    echo "🏛️ Political angle: Share concise, bold take. Don't hedge — strong opinions get engagement."
  elif echo "$text_lower" | grep -qiE "money|revenue|profit|business|growth|scale"; then
    echo "💰 Business angle: Share real numbers or frameworks from scaling consumer apps to millions of users."
  elif echo "$text_lower" | grep -qiE "content|creator|social media|tiktok|youtube|viral"; then
    echo "📱 Content angle: Share your cross-platform strategy. Building in public + AI automation angle."
  else
    echo "💬 General: Add a unique insight from your experience. Ask a provocative follow-up question."
  fi
}

##############################################################################
# MAIN
##############################################################################
FOUND_COUNT=0
RESULTS="[]"

header() {
  if ! $JSON_OUTPUT; then
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo "🎯 X ENGAGEMENT RADAR — $(date '+%Y-%m-%d %H:%M %Z')"
    echo "   Monitoring ${#TARGETS[@]} targets | Window: last ${SINCE_MINUTES} min"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo ""
  fi
}

header

# ── Parallel fetch phase ─────────────────────────────────────
FETCH_DIR=$(mktemp -d)
BG_PIDS=""

cleanup() {
  for p in $BG_PIDS; do kill "$p" 2>/dev/null; done
  rm -rf "$FETCH_DIR" 2>/dev/null
}
trap cleanup EXIT

# Fetch sequentially with a hard 10s timeout per account via Python.
# twitter-cli retries on 429 with exponential backoff which can block 40s+.
# We kill after 10s so rate-limited accounts fail fast.

for handle in "${TARGETS[@]}"; do
  python3 -c "
import subprocess, sys
try:
    r = subprocess.run(
        ['twitter', 'user-posts', '$handle', '--max', '5', '--json'],
        capture_output=True, text=True, timeout=10
    )
    if r.returncode == 0 and r.stdout.strip():
        with open('$FETCH_DIR/${handle}.json', 'w') as f:
            f.write(r.stdout)
except subprocess.TimeoutExpired:
    pass
except Exception:
    pass
" 2>/dev/null
done

# ── Sequential process phase ─────────────────────────────────
for handle in "${TARGETS[@]}"; do
  RAW_FILE="$FETCH_DIR/${handle}.json"
  if [[ ! -s "$RAW_FILE" ]]; then
    if ! $JSON_OUTPUT; then
      echo "  ⚠️  Failed to fetch @${handle} — skipping"
    fi
    continue
  fi
  RAW=$(cat "$RAW_FILE")

  # Parse each tweet
  TWEET_COUNT=$(echo "$RAW" | python3 -c "import json,sys; d=json.load(sys.stdin); print(len(d))" 2>/dev/null || echo 0)

  for i in $(seq 0 $((TWEET_COUNT - 1))); do
    TWEET_DATA=$(echo "$RAW" | python3 -c "
import json, sys
tweets = json.load(sys.stdin)
t = tweets[$i]
# Skip retweets — we want original content
if t.get('isRetweet', False):
    sys.exit(0)
print(json.dumps({
    'id': t['id'],
    'text': t['text'],
    'handle': t['author']['screenName'],
    'name': t['author']['name'],
    'created': t['createdAt'],
    'likes': t.get('metrics',{}).get('likes',0),
    'replies': t.get('metrics',{}).get('replies',0),
    'retweets': t.get('metrics',{}).get('retweets',0),
    'views': t.get('metrics',{}).get('views',0),
    'quotes': t.get('metrics',{}).get('quotes',0),
}))
" 2>/dev/null) || continue

    [[ -z "$TWEET_DATA" ]] && continue

    TWEET_ID=$(echo "$TWEET_DATA" | python3 -c "import json,sys; print(json.load(sys.stdin)['id'])")
    TWEET_TEXT=$(echo "$TWEET_DATA" | python3 -c "import json,sys; print(json.load(sys.stdin)['text'])")
    TWEET_DATE=$(echo "$TWEET_DATA" | python3 -c "import json,sys; print(json.load(sys.stdin)['created'])")
    TWEET_LIKES=$(echo "$TWEET_DATA" | python3 -c "import json,sys; print(json.load(sys.stdin)['likes'])")
    TWEET_VIEWS=$(echo "$TWEET_DATA" | python3 -c "import json,sys; print(json.load(sys.stdin)['views'])")
    TWEET_REPLIES=$(echo "$TWEET_DATA" | python3 -c "import json,sys; print(json.load(sys.stdin)['replies'])")

    # Check if this tweet is within the time window
    TWEET_TS=$(parse_twitter_date "$TWEET_DATE")
    TWEET_TS_INT=${TWEET_TS%.*}

    # Check if already seen
    SEEN_FILE="$STATE_DIR/${handle}_seen.txt"
    touch "$SEEN_FILE"
    if grep -q "^${TWEET_ID}$" "$SEEN_FILE" 2>/dev/null; then
      continue
    fi

    # For first run or wide windows, show recent tweets
    if [[ "$TWEET_TS_INT" -lt "$CUTOFF" ]]; then
      continue
    fi

    # Mark as seen
    echo "$TWEET_ID" >> "$SEEN_FILE"
    # Keep state file small (last 200 IDs)
    tail -200 "$SEEN_FILE" > "$SEEN_FILE.tmp" && mv "$SEEN_FILE.tmp" "$SEEN_FILE"

    ANGLE=$(suggest_reply_angle "$handle" "$TWEET_TEXT")
    FOUND_COUNT=$((FOUND_COUNT + 1))

    if $JSON_OUTPUT; then
      RESULTS=$(echo "$RESULTS" | python3 -c "
import json, sys
results = json.load(sys.stdin)
results.append({
    'handle': '@${handle}',
    'tweet_id': '${TWEET_ID}',
    'text': $(echo "$TWEET_TEXT" | python3 -c "import json,sys; print(json.dumps(sys.stdin.read().strip()))"),
    'likes': ${TWEET_LIKES},
    'views': ${TWEET_VIEWS},
    'replies': ${TWEET_REPLIES},
    'reply_angle': $(echo "$ANGLE" | python3 -c "import json,sys; print(json.dumps(sys.stdin.read().strip()))"),
    'url': 'https://x.com/${handle}/status/${TWEET_ID}'
})
print(json.dumps(results))
")
    else
      echo "  🔥 NEW POST from @${handle}"
      echo "  ┌─────────────────────────────────────────────────"
      echo "  │ 📝 ${TWEET_TEXT}" | head -c 500
      echo ""
      echo "  │ 🔗 https://x.com/${handle}/status/${TWEET_ID}"
      echo "  │ 📊 ${TWEET_VIEWS} views | ❤️  ${TWEET_LIKES} | 💬 ${TWEET_REPLIES}"
      echo "  │ 🎯 ${ANGLE}"
      echo "  └─────────────────────────────────────────────────"
      echo ""
    fi
  done

  # Rate limiting: small delay between targets
  sleep 0.5
done

if $JSON_OUTPUT; then
  echo "$RESULTS" | python3 -m json.tool
else
  echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
  if [[ $FOUND_COUNT -eq 0 ]]; then
    echo "  😴 No new posts from targets in the last ${SINCE_MINUTES} minutes."
  else
    echo "  ✅ Found ${FOUND_COUNT} new posts. Time to engage!"
  fi
  echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
fi

# Cleanup temp dir
rm -rf "$FETCH_DIR" 2>/dev/null
