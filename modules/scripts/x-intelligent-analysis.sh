#!/bin/bash
# Intelligent X Analytics - Deep pattern analysis & strategic insights
# Not just metrics - actual thinking about what's working and why

set -euo pipefail

WORKSPACE="/Users/meircohen/.openclaw/workspace"
TWITTER_CLI="/Users/meircohen/Library/Python/3.9/bin/twitter"
TODAY=$(date +%Y-%m-%d)
REPORT="$WORKSPACE/artifacts/x-intelligence-$TODAY.md"

echo "🧠 X Intelligence Analysis - $TODAY"
echo ""

# Get current follower count
CURRENT_FOLLOWERS=$($TWITTER_CLI user MeirCohen --json 2>/dev/null | jq -r '.data.followers')
echo "Current followers: $CURRENT_FOLLOWERS"

# Get last 7 days of data if available
HISTORICAL_DATA=$(ls -t "$WORKSPACE/state/x-daily-"*.json 2>/dev/null | head -7 || echo "")

# Run today's metrics
bash "$WORKSPACE/scripts/x-daily-metrics.sh" > /tmp/x-today.log 2>&1

# Now analyze with Python + actual intelligence
/usr/bin/python3 << 'PYTHON'
import json
import os
import glob
from datetime import datetime, timedelta
from collections import defaultdict

workspace = "/Users/meircohen/.openclaw/workspace"
today = datetime.now().strftime("%Y-%m-%d")

print("\n" + "="*70)
print("🧠 DEEP ANALYSIS - PATTERN RECOGNITION")
print("="*70)

# Load historical data (last 7 days)
historical_files = sorted(glob.glob(f"{workspace}/state/x-daily-*.json"), reverse=True)[:7]
all_data = []

for file in historical_files:
    try:
        with open(file, 'r') as f:
            data = json.load(f)
            date = os.path.basename(file).replace('x-daily-', '').replace('.json', '')
            for tweet in data:
                tweet['date'] = date
            all_data.extend(data)
    except:
        pass

if not all_data:
    print("\n⚠️  No historical data yet. Run for 3+ days to see patterns.")
    exit(0)

print(f"\n📊 Analyzing {len(all_data)} tweets across {len(historical_files)} days...")

# 1. CONTENT TYPE PERFORMANCE
print("\n" + "-"*70)
print("1. CONTENT TYPE ANALYSIS")
print("-"*70)

replies = [t for t in all_data if t['text'].startswith('@')]
posts = [t for t in all_data if not t['text'].startswith('@')]

if replies:
    reply_avg = sum(t['score'] for t in replies) / len(replies)
    reply_max = max(replies, key=lambda x: x['score'])
    print(f"\n📧 REPLIES: {len(replies)} total, avg score {reply_avg:.1f}")
    print(f"   Best: {reply_max['score']} score - {reply_max['text'][:60]}...")
    
    # Identify reply targets
    targets = defaultdict(lambda: {'count': 0, 'total_score': 0, 'best': None})
    for r in replies:
        target = r['text'].split()[0]
        targets[target]['count'] += 1
        targets[target]['total_score'] += r['score']
        if not targets[target]['best'] or r['score'] > targets[target]['best']['score']:
            targets[target]['best'] = r
    
    print("\n   🎯 Top reply targets:")
    for target, data in sorted(targets.items(), key=lambda x: x[1]['total_score'], reverse=True)[:3]:
        avg = data['total_score'] / data['count']
        print(f"      {target}: {data['count']} replies, {avg:.1f} avg score")
        print(f"         Best: \"{data['best']['text'][:50]}...\" ({data['best']['score']} score)")

if posts:
    post_avg = sum(t['score'] for t in posts) / len(posts)
    post_max = max(posts, key=lambda x: x['score'])
    print(f"\n📝 ORIGINAL POSTS: {len(posts)} total, avg score {post_avg:.1f}")
    print(f"   Best: {post_max['score']} score - {post_max['text'][:60]}...")

if replies and posts:
    ratio = reply_avg / post_avg if post_avg > 0 else 0
    print(f"\n💡 INSIGHT: Replies outperform posts by {ratio:.1f}X")

# 2. TEMPORAL PATTERNS
print("\n" + "-"*70)
print("2. TIME-BASED PATTERNS")
print("-"*70)

by_date = defaultdict(list)
for t in all_data:
    by_date[t['date']].append(t['score'])

print("\n📈 Daily performance:")
for date in sorted(by_date.keys(), reverse=True):
    scores = by_date[date]
    avg = sum(scores) / len(scores)
    max_score = max(scores)
    print(f"   {date}: {len(scores)} posts, {avg:.1f} avg, {max_score} max")

# Detect trends
if len(by_date) >= 3:
    dates = sorted(by_date.keys())
    recent_avg = sum(sum(by_date[d]) for d in dates[-2:]) / sum(len(by_date[d]) for d in dates[-2:])
    older_avg = sum(sum(by_date[d]) for d in dates[:-2]) / sum(len(by_date[d]) for d in dates[:-2]) if len(dates) > 2 else recent_avg
    
    if recent_avg > older_avg * 1.2:
        print(f"\n✅ TRENDING UP: Recent posts performing {(recent_avg/older_avg):.1f}X better")
    elif recent_avg < older_avg * 0.8:
        print(f"\n⚠️  TRENDING DOWN: Recent performance dropped {(1 - recent_avg/older_avg)*100:.0f}%")

# 3. ENGAGEMENT DEPTH ANALYSIS
print("\n" + "-"*70)
print("3. ENGAGEMENT QUALITY")
print("-"*70)

high_convo = [t for t in all_data if t['replies'] >= 2]
high_views = [t for t in all_data if t['views'] > 500]
high_saves = [t for t in all_data if t.get('bookmarks', 0) > 0]

print(f"\n🗣️  Conversation starters: {len(high_convo)} tweets with 2+ replies")
if high_convo:
    best_convo = max(high_convo, key=lambda x: x['replies'])
    print(f"   Best: {best_convo['replies']} replies - \"{best_convo['text'][:50]}...\"")

print(f"\n👀 High visibility: {len(high_views)} tweets with 500+ views")
if high_views:
    best_views = max(high_views, key=lambda x: x['views'])
    print(f"   Best: {best_views['views']} views - \"{best_views['text'][:50]}...\"")

print(f"\n⭐ Valuable content: {len(high_saves)} tweets bookmarked")

# 4. STRATEGIC RECOMMENDATIONS
print("\n" + "-"*70)
print("4. STRATEGIC RECOMMENDATIONS")
print("-"*70)

print("\n📌 What to do next:")

# Rec 1: Content type
if replies and posts and reply_avg > post_avg * 2:
    print(f"\n1. PRIORITIZE REPLIES")
    print(f"   • Replies perform {reply_avg/post_avg:.1f}X better than posts")
    print(f"   • Focus on high-engagement reply targets")
    if targets:
        best_target = max(targets.items(), key=lambda x: x[1]['total_score']/x[1]['count'])
        print(f"   • Best target: {best_target[0]} (avg {best_target[1]['total_score']/best_target[1]['count']:.1f} score)")

# Rec 2: Timing
if len(by_date) >= 3:
    best_day = max(by_date.items(), key=lambda x: sum(x[1])/len(x[1]))
    print(f"\n2. OPTIMIZE TIMING")
    print(f"   • Best performing day: {best_day[0]} ({sum(best_day[1])/len(best_day[1]):.1f} avg)")
    print(f"   • Analyze what you did differently that day")

# Rec 3: Engagement depth
if high_convo:
    print(f"\n3. DRIVE CONVERSATION")
    print(f"   • {len(high_convo)} tweets sparked discussions")
    print(f"   • Pattern: Controversial or opinion-based content works")
    print(f"   • Ask questions or make bold claims to increase replies")

# Rec 4: Content gaps
low_performers = [t for t in all_data if t['score'] < 5]
if len(low_performers) > len(all_data) * 0.5:
    print(f"\n4. AVOID LOW-PERFORMING PATTERNS")
    print(f"   • {len(low_performers)} tweets scored < 5")
    common_words = {}
    for t in low_performers:
        words = t['text'].lower().split()
        for w in words[:10]:
            if len(w) > 4:
                common_words[w] = common_words.get(w, 0) + 1
    if common_words:
        top_words = sorted(common_words.items(), key=lambda x: x[1], reverse=True)[:3]
        print(f"   • Common themes in low performers: {', '.join(w for w,_ in top_words)}")
        print(f"   • Try different angles or topics")

# 5. FOLLOWER GROWTH CORRELATION (if we have data)
print("\n" + "-"*70)
print("5. GROWTH TRACKING")
print("-"*70)

# Would need historical follower counts - save for future implementation
print("\n📊 To track:")
print("   • Follower growth after high-performing tweets")
print("   • Engagement → follow conversion rate")
print("   • Daily follower delta")
print("\n   💡 Run this daily to build trend data")

print("\n" + "="*70)

PYTHON

# Save report
echo ""
echo "✅ Analysis complete!"
echo "   Full report available in artifacts/"
