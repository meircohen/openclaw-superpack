#!/bin/bash
# Daily X performance analysis - fully automated
# Fetches ALL recent tweets/replies with full metrics
# No manual input required

set -euo pipefail

WORKSPACE="/Users/meircohen/.openclaw/workspace"
TWITTER_CLI="/Users/meircohen/Library/Python/3.9/bin/twitter"
OUTPUT_FILE="$WORKSPACE/state/x-performance-$(date +%Y-%m-%d).json"
REPORT_FILE="$WORKSPACE/artifacts/x-daily-report-$(date +%Y-%m-%d).md"

echo "📊 X Performance Analysis - $(date '+%Y-%m-%d %H:%M')"
echo ""

# Fetch ALL recent tweets with full metrics
echo "Fetching tweets from last 7 days..."
$TWITTER_CLI search "from:MeirCohen" --max 200 --json 2>&1 > /tmp/x-all-tweets.json

# Parse and analyze
python3 << 'PYTHON'
import json
import sys
from datetime import datetime, timedelta

with open('/tmp/x-all-tweets.json', 'r') as f:
    data = json.load(f)

tweets = data.get('data', [])

# Filter to last 7 days
cutoff = datetime.now() - timedelta(days=7)
recent = []

for t in tweets:
    try:
        created = datetime.strptime(t['createdAt'], '%a %b %d %H:%M:%S %z %Y')
        if created > cutoff:
            recent.append(t)
    except:
        pass

# Calculate scores
scored = []
for t in recent:
    m = t['metrics']
    score = m['likes'] + (m['replies'] * 3) + (m['retweets'] * 2)
    
    scored.append({
        'id': t['id'],
        'score': score,
        'likes': m['likes'],
        'retweets': m['retweets'],
        'replies': m['replies'],
        'views': m['views'],
        'bookmarks': m.get('bookmarks', 0),
        'text': t['text'][:100],
        'created': t['createdAt'],
        'is_reply': t['text'].startswith('@')
    })

# Sort by score
scored.sort(key=lambda x: x['score'], reverse=True)

# Save full data
with open('/Users/meircohen/.openclaw/workspace/state/x-performance-' + datetime.now().strftime('%Y-%m-%d') + '.json', 'w') as f:
    json.dump(scored, f, indent=2)

# Generate report
print("\n" + "="*70)
print("TOP 10 PERFORMERS (Last 7 Days)")
print("="*70)

for i, t in enumerate(scored[:10], 1):
    type_label = "REPLY" if t['is_reply'] else "POST"
    target = t['text'].split()[0] if t['is_reply'] else "N/A"
    
    print(f"\n#{i} {type_label} (Score: {t['score']})")
    print(f"   {t['likes']}L {t['retweets']}RT {t['replies']}R {t['views']}V {t['bookmarks']}BM")
    if t['is_reply']:
        print(f"   Target: {target}")
    print(f"   \"{t['text']}...\"")

# Pattern analysis
replies = [t for t in scored if t['is_reply']]
posts = [t for t in scored if not t['is_reply']]

reply_avg = sum(t['score'] for t in replies) / len(replies) if replies else 0
post_avg = sum(t['score'] for t in posts) / len(posts) if posts else 0

print("\n" + "="*70)
print("PATTERN ANALYSIS")
print("="*70)
print(f"\nReplies: {len(replies)} total, avg score: {reply_avg:.1f}")
print(f"Original posts: {len(posts)} total, avg score: {post_avg:.1f}")

if replies and posts and reply_avg > post_avg:
    ratio = reply_avg / post_avg
    print(f"\n✅ REPLIES OUTPERFORM by {ratio:.1f}X")

# Identify crossover vs technical
crossover = [t for t in scored[:10] if any(word in t['text'].lower() for word in ['politic', 'fraud', 'official', 'media', 'government', 'business', 'million', 'billion'])]
technical = [t for t in scored[:10] if not any(word in t['text'].lower() for word in ['politic', 'fraud', 'official', 'media', 'government', 'business', 'million', 'billion'])]

if crossover:
    crossover_avg = sum(t['score'] for t in crossover) / len(crossover)
    technical_avg = sum(t['score'] for t in technical) / len(technical) if technical else 0
    
    print(f"\nCrossover content: {len(crossover)} posts, avg {crossover_avg:.0f} score")
    print(f"Pure technical: {len(technical)} posts, avg {technical_avg:.0f} score")
    
    if crossover_avg > technical_avg * 2:
        print(f"\n🎯 CROSSOVER CONTENT DOMINATES ({crossover_avg/technical_avg:.1f}X better)")

# Recommendations
print("\n" + "="*70)
print("RECOMMENDATIONS FOR NEXT /x")
print("="*70)

top = scored[0]
if top['is_reply']:
    target = top['text'].split()[0]
    print(f"\n✅ Best performer was reply to {target}")
    print(f"   Score: {top['score']} ({top['likes']}L {top['retweets']}RT {top['views']}V)")
    print(f"   Look for similar high-reach targets")

# Identify hot topics from top performers
print(f"\nTop performing accounts:")
reply_targets = {}
for t in [x for x in scored[:10] if x['is_reply']]:
    target = t['text'].split()[0]
    reply_targets[target] = reply_targets.get(target, 0) + t['score']

for target, total_score in sorted(reply_targets.items(), key=lambda x: x[1], reverse=True)[:3]:
    print(f"  {target}: {total_score} total engagement")

print("\n" + "="*70)

PYTHON

echo ""
echo "✅ Analysis complete"
echo "   Full data: $OUTPUT_FILE"
echo "   Next /x should target accounts showing in recommendations"
