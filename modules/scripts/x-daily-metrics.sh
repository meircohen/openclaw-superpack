#!/usr/bin/env bash
# x-daily-metrics.sh — Daily performance analytics for @MeirCohen
# Usage: ./x-daily-metrics.sh [--tweets 20] [--json]
set -euo pipefail

##############################################################################
# CONFIG
##############################################################################
MY_HANDLE="MeirCohen"
TWEET_COUNT=20
JSON_OUTPUT=false
REPORT_DIR="$HOME/.openclaw/workspace/scripts/.metrics-reports"
mkdir -p "$REPORT_DIR"

# Parse args
while [[ $# -gt 0 ]]; do
  case "$1" in
    --tweets) TWEET_COUNT="$2"; shift 2 ;;
    --json) JSON_OUTPUT=true; shift ;;
    --handle) MY_HANDLE="$2"; shift 2 ;;
    *) shift ;;
  esac
done

##############################################################################
# STEP 1: Fetch profile stats
##############################################################################
PROFILE=$(twitter user "$MY_HANDLE" --json 2>/dev/null) || {
  echo "❌ Failed to fetch profile for @${MY_HANDLE}" >&2
  exit 1
}

# Unwrap new schema: {"ok":true,"data":{...}} or bare {...}
FOLLOWER_COUNT=$(echo "$PROFILE" | python3 -c "import json,sys; d=json.load(sys.stdin); p=d.get('data',d) if isinstance(d,dict) else d; print(p.get('followers',0))")
FOLLOWING_COUNT=$(echo "$PROFILE" | python3 -c "import json,sys; d=json.load(sys.stdin); p=d.get('data',d) if isinstance(d,dict) else d; print(p.get('following',0))")
TOTAL_TWEETS=$(echo "$PROFILE" | python3 -c "import json,sys; d=json.load(sys.stdin); p=d.get('data',d) if isinstance(d,dict) else d; print(p.get('tweets',0))")
TOTAL_LIKES=$(echo "$PROFILE" | python3 -c "import json,sys; d=json.load(sys.stdin); p=d.get('data',d) if isinstance(d,dict) else d; print(p.get('likes',0))")

##############################################################################
# STEP 2: Fetch latest tweets
##############################################################################
TWEETS_RAW=$(twitter user-posts "$MY_HANDLE" --max "$TWEET_COUNT" --json 2>/dev/null) || {
  echo "❌ Failed to fetch tweets for @${MY_HANDLE}" >&2
  exit 1
}

##############################################################################
# STEP 3: Calculate metrics
##############################################################################
REPORT=$(echo "$TWEETS_RAW" | python3 -c "
import json, sys
from datetime import datetime

raw = json.load(sys.stdin)
# Unwrap new schema: {"ok":true,"data":[...]} or bare [...]
tweets = raw.get('data', raw) if isinstance(raw, dict) else raw
if not isinstance(tweets, list):
    tweets = [tweets]
followers = ${FOLLOWER_COUNT}

# Filter to only original tweets (not retweets)
original = [t for t in tweets if isinstance(t, dict) and not t.get('isRetweet', False)]
all_tweets = tweets  # keep all for completeness

if not original:
    print(json.dumps({'error': 'No original tweets found'}))
    sys.exit(0)

# Calculate metrics for original tweets
total_views = sum(t.get('metrics', {}).get('views', 0) for t in original)
total_likes = sum(t.get('metrics', {}).get('likes', 0) for t in original)
total_replies = sum(t.get('metrics', {}).get('replies', 0) for t in original)
total_retweets = sum(t.get('metrics', {}).get('retweets', 0) for t in original)
total_quotes = sum(t.get('metrics', {}).get('quotes', 0) for t in original)
total_bookmarks = sum(t.get('metrics', {}).get('bookmarks', 0) for t in original)
n = len(original)

avg_views = total_views / n
avg_likes = total_likes / n
avg_replies = total_replies / n
avg_retweets = total_retweets / n
avg_quotes = total_quotes / n

# Engagement rate: (likes + replies + retweets + quotes) / views * 100
total_engagements = total_likes + total_replies + total_retweets + total_quotes
eng_rate = (total_engagements / max(total_views, 1)) * 100

# Views per follower
vpf = avg_views / max(followers, 1)

# Best and worst performing (by total engagement)
def engagement_score(t):
    m = t.get('metrics', {})
    return m.get('likes', 0) * 2 + m.get('retweets', 0) * 3 + m.get('replies', 0) * 1.5 + m.get('quotes', 0) * 4 + m.get('bookmarks', 0) * 2

sorted_tweets = sorted(original, key=engagement_score, reverse=True)
best = sorted_tweets[0]
worst = sorted_tweets[-1]

# Per-tweet breakdown
tweet_breakdown = []
for t in sorted_tweets:
    m = t.get('metrics', {})
    views = m.get('views', 0)
    likes = m.get('likes', 0)
    replies = m.get('replies', 0)
    rts = m.get('retweets', 0)
    quotes = m.get('quotes', 0)
    bm = m.get('bookmarks', 0)
    eng = ((likes + replies + rts + quotes) / max(views, 1)) * 100
    tweet_breakdown.append({
        'id': t['id'],
        'text': t['text'][:150],
        'views': views,
        'likes': likes,
        'replies': replies,
        'retweets': rts,
        'quotes': quotes,
        'bookmarks': bm,
        'eng_rate': round(eng, 2),
        'score': round(engagement_score(t), 1),
        'date': t.get('createdAt', ''),
    })

report = {
    'date': datetime.now().strftime('%Y-%m-%d'),
    'handle': '@${MY_HANDLE}',
    'followers': followers,
    'following': ${FOLLOWING_COUNT},
    'total_tweets': ${TOTAL_TWEETS},
    'analyzed_tweets': n,
    'retweets_excluded': len(all_tweets) - n,
    'summary': {
        'avg_views': round(avg_views, 1),
        'avg_likes': round(avg_likes, 1),
        'avg_replies': round(avg_replies, 1),
        'avg_retweets': round(avg_retweets, 1),
        'avg_quotes': round(avg_quotes, 1),
        'total_views': total_views,
        'total_engagements': total_engagements,
        'engagement_rate': round(eng_rate, 3),
        'views_per_follower': round(vpf, 2),
        'total_bookmarks': total_bookmarks,
    },
    'best_tweet': {
        'id': best['id'],
        'text': best['text'][:200],
        'url': f\"https://x.com/${MY_HANDLE}/status/{best['id']}\",
        'views': best.get('metrics', {}).get('views', 0),
        'likes': best.get('metrics', {}).get('likes', 0),
        'replies': best.get('metrics', {}).get('replies', 0),
        'retweets': best.get('metrics', {}).get('retweets', 0),
        'score': round(engagement_score(best), 1),
    },
    'worst_tweet': {
        'id': worst['id'],
        'text': worst['text'][:200],
        'url': f\"https://x.com/${MY_HANDLE}/status/{worst['id']}\",
        'views': worst.get('metrics', {}).get('views', 0),
        'likes': worst.get('metrics', {}).get('likes', 0),
        'replies': worst.get('metrics', {}).get('replies', 0),
        'retweets': worst.get('metrics', {}).get('retweets', 0),
        'score': round(engagement_score(worst), 1),
    },
    'tweet_breakdown': tweet_breakdown,
}

print(json.dumps(report, indent=2))
")

##############################################################################
# STEP 4: Output
##############################################################################
if $JSON_OUTPUT; then
  echo "$REPORT"
  # Save to file
  DATE=$(date '+%Y-%m-%d')
  echo "$REPORT" > "$REPORT_DIR/metrics-${DATE}.json"
else
  echo "$REPORT" | python3 -c "
import json, sys

r = json.load(sys.stdin)
s = r['summary']
b = r['best_tweet']
w = r['worst_tweet']

print('━' * 62)
print(f\"📊 DAILY X METRICS — {r['date']}\")
print(f\"   {r['handle']} | {r['followers']:,} followers | {r['analyzed_tweets']} tweets analyzed\")
print('━' * 62)
print()
print('  📈 AVERAGES (per tweet)')
print(f\"  ├── 👁️  Views:    {s['avg_views']:,.1f}\")
print(f\"  ├── ❤️  Likes:    {s['avg_likes']:,.1f}\")
print(f\"  ├── 💬 Replies:  {s['avg_replies']:,.1f}\")
print(f\"  ├── 🔁 Retweets: {s['avg_retweets']:,.1f}\")
print(f\"  └── 📎 Quotes:   {s['avg_quotes']:,.1f}\")
print()
print('  📊 AGGREGATE')
print(f\"  ├── Total views:       {s['total_views']:,}\")
print(f\"  ├── Total engagements: {s['total_engagements']:,}\")
print(f\"  ├── Engagement rate:   {s['engagement_rate']:.3f}%\")
print(f\"  ├── Views/follower:    {s['views_per_follower']:.2f}x\")
print(f\"  └── Total bookmarks:   {s['total_bookmarks']:,}\")
print()
print('  🏆 BEST PERFORMING')
print(f\"  ├── 📝 {b['text'][:120]}...\")
print(f\"  ├── 🔗 {b['url']}\")
print(f\"  ├── 👁️  {b['views']:,} views | ❤️  {b['likes']} | 💬 {b['replies']}\")
print(f\"  └── ⚡ Score: {b['score']}\")
print()
print('  💀 WORST PERFORMING')
print(f\"  ├── 📝 {w['text'][:120]}...\")
print(f\"  ├── 🔗 {w['url']}\")
print(f\"  ├── 👁️  {w['views']:,} views | ❤️  {w['likes']} | 💬 {w['replies']}\")
print(f\"  └── ⚡ Score: {w['score']}\")
print()
print('  📋 FULL BREAKDOWN (by score)')
print('  ┌──────────────────────────────────────────────────────────')
for i, t in enumerate(r['tweet_breakdown'][:10]):
    rank = '🥇' if i == 0 else '🥈' if i == 1 else '🥉' if i == 2 else f' {i+1}.'
    print(f\"  │ {rank} {t['text'][:80]}...\")
    print(f\"  │    👁️ {t['views']:,} | ❤️ {t['likes']} | 💬 {t['replies']} | 🔁 {t['retweets']} | Eng: {t['eng_rate']}%\")
print('  └──────────────────────────────────────────────────────────')
print()
print('━' * 62)
print('  💡 TIP: Run with --json to save machine-readable report')
print('━' * 62)
"

  # Save report
  DATE=$(date '+%Y-%m-%d')
  echo "$REPORT" > "$REPORT_DIR/metrics-${DATE}.json"
  echo "  📁 Report saved: $REPORT_DIR/metrics-${DATE}.json"
fi
