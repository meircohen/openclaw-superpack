#!/usr/bin/env bash
# x-quote-tweet-finder.sh — Find high-engagement QT candidates from top followed accounts
# Usage: ./x-quote-tweet-finder.sh [--hours 6] [--min-likes 50] [--json]
set -euo pipefail

##############################################################################
# CONFIG
##############################################################################
MY_HANDLE="MeirCohen"
HOURS=6
MIN_LIKES=50
MIN_VIEWS=1000
JSON_OUTPUT=false
TOP_N=20

# Parse args
while [[ $# -gt 0 ]]; do
  case "$1" in
    --hours) HOURS="$2"; shift 2 ;;
    --min-likes) MIN_LIKES="$2"; shift 2 ;;
    --min-views) MIN_VIEWS="$2"; shift 2 ;;
    --json) JSON_OUTPUT=true; shift ;;
    --top) TOP_N="$2"; shift 2 ;;
    *) shift ;;
  esac
done

CACHE_DIR="$HOME/.openclaw/workspace/scripts/.qt-cache"
mkdir -p "$CACHE_DIR"

# Cutoff timestamp
if [[ "$OSTYPE" == darwin* ]]; then
  CUTOFF=$(date -v-${HOURS}H +%s 2>/dev/null)
else
  CUTOFF=$(date -d "${HOURS} hours ago" +%s)
fi

# Relevance topics for QT scoring
TOPICS="ai|artificial intelligence|llm|gpt|agent|automation|startup|founder|ship|build|launch|scale|revenue|growth|israel|jewish|zion|security|privacy|hack|cyber|creator|content|tiktok|political|trump|conservative|tech|software|code|nocode|no-code|openclaw"

##############################################################################
# STEP 1: Get top accounts Meir follows (by follower count)
##############################################################################
echo "📡 Fetching accounts @${MY_HANDLE} follows..." >&2

FOLLOWING_RAW=$(twitter following "$MY_HANDLE" --max 100 --json 2>/dev/null) || {
  echo "❌ Failed to fetch following list" >&2
  exit 1
}

# Sort by follower count descending, take top N
TOP_ACCOUNTS=$(echo "$FOLLOWING_RAW" | python3 -c "
import json, sys
users = json.load(sys.stdin)
# Sort by followers descending
users.sort(key=lambda u: u.get('followers', 0), reverse=True)
# Take top N
for u in users[:${TOP_N}]:
    print(f\"{u['screenName']}|{u.get('followers',0)}|{u.get('name','')}\")
" 2>/dev/null)

if [[ -z "$TOP_ACCOUNTS" ]]; then
  echo "❌ No accounts found" >&2
  exit 1
fi

ACCOUNT_COUNT=$(echo "$TOP_ACCOUNTS" | wc -l | tr -d ' ')

if ! $JSON_OUTPUT; then
  echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
  echo "🔁 QUOTE TWEET FINDER — $(date '+%Y-%m-%d %H:%M %Z')"
  echo "   Scanning top ${ACCOUNT_COUNT} accounts | Window: last ${HOURS}h"
  echo "   Min likes: ${MIN_LIKES} | Min views: ${MIN_VIEWS}"
  echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
  echo ""
fi

##############################################################################
# STEP 2: Scan each account for QT-worthy posts
##############################################################################
CANDIDATES="[]"
FOUND=0

while IFS='|' read -r screen_name follower_count display_name; do
  [[ -z "$screen_name" ]] && continue

  RAW=$(twitter user-posts "$screen_name" --max 10 --json 2>/dev/null) || {
    echo "  ⚠️  Skipping @${screen_name}" >&2
    continue
  }

  # Filter and score tweets
  SCORED=$(echo "$RAW" | python3 -c "
import json, sys, re
from email.utils import parsedate_tz, mktime_tz

tweets = json.load(sys.stdin)
cutoff = ${CUTOFF}
min_likes = ${MIN_LIKES}
min_views = ${MIN_VIEWS}
topics = '${TOPICS}'

results = []
for t in tweets:
    # Skip retweets
    if t.get('isRetweet', False):
        continue

    # Parse date
    d = t.get('createdAt', '')
    parts = d.split()
    if len(parts) >= 6:
        rfc = f'{parts[0]} {parts[2]} {parts[1]} {parts[5]} {parts[3]} {parts[4]}'
        parsed = parsedate_tz(rfc)
        ts = mktime_tz(parsed) if parsed else 0
    else:
        ts = 0

    if ts < cutoff:
        continue

    m = t.get('metrics', {})
    likes = m.get('likes', 0)
    views = m.get('views', 0)
    replies = m.get('replies', 0)
    retweets = m.get('retweets', 0)
    quotes = m.get('quotes', 0)

    if likes < min_likes or views < min_views:
        continue

    text = t.get('text', '')

    # Score: engagement + topic relevance
    engagement_score = (likes * 2) + (retweets * 3) + (replies * 1.5) + (quotes * 4)
    topic_match = len(re.findall(topics, text.lower()))
    topic_bonus = topic_match * 50
    total_score = engagement_score + topic_bonus

    # Engagement rate
    eng_rate = ((likes + retweets + replies + quotes) / max(views, 1)) * 100

    results.append({
        'id': t['id'],
        'text': text,
        'handle': '${screen_name}',
        'name': t.get('author', {}).get('name', '${display_name}'),
        'likes': likes,
        'views': views,
        'replies': replies,
        'retweets': retweets,
        'quotes': quotes,
        'score': round(total_score, 1),
        'eng_rate': round(eng_rate, 2),
        'topic_match': topic_match > 0,
    })

# Sort by score descending
results.sort(key=lambda x: x['score'], reverse=True)
print(json.dumps(results))
" 2>/dev/null) || continue

  COUNT=$(echo "$SCORED" | python3 -c "import json,sys; print(len(json.load(sys.stdin)))" 2>/dev/null || echo 0)

  if [[ "$COUNT" -gt 0 ]]; then
    # Process each candidate
    echo "$SCORED" | python3 -c "
import json, sys

tweets = json.load(sys.stdin)
for t in tweets:
    text_lower = t['text'].lower()

    # Determine QT angle
    if any(w in text_lower for w in ['ai', 'agent', 'llm', 'gpt', 'claude', 'automation']):
        angle = '🤖 AI/Agents: Share your hands-on experience with 55+ AI agents. Real metrics, not theory.'
    elif any(w in text_lower for w in ['startup', 'founder', 'build', 'ship', 'launch', 'scale']):
        angle = '🚀 Founder take: Add your builder perspective. Reference TrapCall/RoboKiller journey.'
    elif any(w in text_lower for w in ['israel', 'jewish', 'hamas', 'antisemit', 'zion']):
        angle = '🇮🇱 Pro-Israel: Add your voice with conviction. Personal connection + facts.'
    elif any(w in text_lower for w in ['money', 'revenue', 'business', 'growth', 'profit']):
        angle = '💰 Business: Share a real number or counterintuitive insight from your experience.'
    elif any(w in text_lower for w in ['security', 'hack', 'privacy', 'cyber', 'breach']):
        angle = '🔒 Security/Privacy: Tie to your telecom security background. Unique expertise.'
    elif any(w in text_lower for w in ['politic', 'trump', 'biden', 'conservative', 'liberal']):
        angle = '🏛️ Political hot take: Bold, concise opinion. Controversy = engagement.'
    else:
        angle = '💬 General: Add a strong opinion or contrarian take. Ask a provocative question.'

    print(json.dumps({**t, 'qt_angle': angle}))
" 2>/dev/null | while IFS= read -r line; do
      FOUND=$((FOUND + 1))

      if ! $JSON_OUTPUT; then
        TWEET_HANDLE=$(echo "$line" | python3 -c "import json,sys; print(json.load(sys.stdin)['handle'])")
        TWEET_ID=$(echo "$line" | python3 -c "import json,sys; print(json.load(sys.stdin)['id'])")
        TWEET_TEXT=$(echo "$line" | python3 -c "import json,sys; print(json.load(sys.stdin)['text'][:300])")
        TWEET_LIKES=$(echo "$line" | python3 -c "import json,sys; print(json.load(sys.stdin)['likes'])")
        TWEET_VIEWS=$(echo "$line" | python3 -c "import json,sys; print(json.load(sys.stdin)['views'])")
        TWEET_SCORE=$(echo "$line" | python3 -c "import json,sys; print(json.load(sys.stdin)['score'])")
        TWEET_ENG=$(echo "$line" | python3 -c "import json,sys; print(json.load(sys.stdin)['eng_rate'])")
        TWEET_ANGLE=$(echo "$line" | python3 -c "import json,sys; print(json.load(sys.stdin)['qt_angle'])")
        TWEET_TOPIC=$(echo "$line" | python3 -c "import json,sys; print('✅' if json.load(sys.stdin)['topic_match'] else '—')")

        echo "  🔁 QT Candidate from @${TWEET_HANDLE}"
        echo "  ┌─────────────────────────────────────────────────"
        echo "  │ 📝 ${TWEET_TEXT}"
        echo "  │ 🔗 https://x.com/${TWEET_HANDLE}/status/${TWEET_ID}"
        echo "  │ 📊 ${TWEET_VIEWS} views | ❤️  ${TWEET_LIKES} | ⚡ Score: ${TWEET_SCORE}"
        echo "  │ 📈 Eng rate: ${TWEET_ENG}% | Topic match: ${TWEET_TOPIC}"
        echo "  │ 🎯 ${TWEET_ANGLE}"
        echo "  └─────────────────────────────────────────────────"
        echo ""
      fi
    done

    # Append to JSON results
    CANDIDATES=$(echo "$CANDIDATES" "$SCORED" | python3 -c "
import json, sys
lines = sys.stdin.read().strip().split('\n')
existing = json.loads(lines[0])
new = json.loads(lines[1]) if len(lines) > 1 else []
existing.extend(new)
print(json.dumps(existing))
" 2>/dev/null)
  fi

  # Rate limiting
  sleep 0.5
done <<< "$TOP_ACCOUNTS"

##############################################################################
# OUTPUT
##############################################################################
if $JSON_OUTPUT; then
  # Sort all candidates by score and output
  echo "$CANDIDATES" | python3 -c "
import json, sys
candidates = json.load(sys.stdin)
candidates.sort(key=lambda x: x.get('score', 0), reverse=True)
# Add QT angles
for c in candidates:
    text_lower = c['text'].lower()
    if any(w in text_lower for w in ['ai', 'agent', 'llm', 'gpt', 'claude', 'automation']):
        c['qt_angle'] = 'AI/Agents: Share hands-on experience with 55+ AI agents'
    elif any(w in text_lower for w in ['startup', 'founder', 'build', 'ship', 'launch']):
        c['qt_angle'] = 'Founder take: Reference TrapCall/RoboKiller builder journey'
    elif any(w in text_lower for w in ['israel', 'jewish', 'hamas', 'zion']):
        c['qt_angle'] = 'Pro-Israel: Personal connection + facts'
    elif any(w in text_lower for w in ['money', 'revenue', 'business', 'growth']):
        c['qt_angle'] = 'Business: Share real numbers or counterintuitive insight'
    else:
        c['qt_angle'] = 'General: Strong opinion or contrarian take'
    c['url'] = f\"https://x.com/{c['handle']}/status/{c['id']}\"
print(json.dumps(candidates, indent=2))
" 2>/dev/null
else
  TOTAL=$(echo "$CANDIDATES" | python3 -c "import json,sys; print(len(json.load(sys.stdin)))" 2>/dev/null || echo 0)
  echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
  if [[ "$TOTAL" -eq 0 ]]; then
    echo "  😴 No QT candidates found. Try --min-likes 20 or --hours 12"
  else
    echo "  ✅ Found ${TOTAL} QT candidates. Get quoting!"
  fi
  echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
fi
