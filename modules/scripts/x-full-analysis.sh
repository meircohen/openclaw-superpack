#!/bin/bash
# Comprehensive X performance analysis
# Analyzes ALL posts/replies since last check

set -euo pipefail

WORKSPACE="/Users/meircohen/.openclaw/workspace"
STATE_FILE="$WORKSPACE/state/x-last-analysis.timestamp"
TWITTER_CLI="/Users/meircohen/Library/Python/3.9/bin/twitter"

# Get last analysis timestamp (or default to 7 days ago)
if [ -f "$STATE_FILE" ]; then
    LAST_CHECK=$(cat "$STATE_FILE")
    echo "📊 Analyzing X activity since $(date -r $LAST_CHECK '+%Y-%m-%d %H:%M')"
else
    LAST_CHECK=$(($(date +%s) - 604800))  # 7 days ago
    echo "📊 First analysis - looking at last 7 days"
fi

echo ""

# Fetch comprehensive activity
echo "Fetching posts and replies..."
$TWITTER_CLI user-posts MeirCohen --max 50 --json > /tmp/x-posts.json 2>/dev/null
$TWITTER_CLI search "from:MeirCohen" --max 50 --json > /tmp/x-all.json 2>/dev/null

# Analyze with jq + basic stats
echo ""
echo "TOP 10 POSTS/REPLIES BY ENGAGEMENT:"
echo "===================================="

cat /tmp/x-all.json | jq -r '.data[] | 
    select(.createdAt | fromdateiso8601 > '$LAST_CHECK') |
    {
        id: .id,
        score: (.metrics.likes + (.metrics.replies * 3) + (.metrics.retweets * 2)),
        likes: .metrics.likes,
        replies: .metrics.replies,
        retweets: .metrics.retweets,
        views: .metrics.views,
        text: .text[0:80],
        is_reply: (.text | startswith("@"))
    } |
    "\(.score)|\(.likes)|\(.replies)|\(.retweets)|\(.views)|\(.is_reply)|\(.text)"
' | sort -t'|' -k1 -rn | head -10 | while IFS='|' read score likes replies rts views is_reply text; do
    type="POST"
    [ "$is_reply" = "true" ] && type="REPLY"
    
    echo ""
    echo "$type (Score: $score)"
    echo "  Metrics: $likes L, $replies R, $rts RT, $views V"
    echo "  Text: $text..."
done

echo ""
echo "===================================="
echo ""
echo "PATTERN ANALYSIS:"

# Count reply vs original performance
REPLY_AVG=$(cat /tmp/x-all.json | jq '[.data[] | select(.createdAt | fromdateiso8601 > '$LAST_CHECK') | select(.text | startswith("@")) | (.metrics.likes + (.metrics.replies * 3) + (.metrics.retweets * 2))] | add / length' 2>/dev/null || echo 0)
ORIG_AVG=$(cat /tmp/x-all.json | jq '[.data[] | select(.createdAt | fromdateiso8601 > '$LAST_CHECK') | select(.text | startswith("@") | not) | (.metrics.likes + (.metrics.replies * 3) + (.metrics.retweets * 2))] | add / length' 2>/dev/null || echo 0)

echo "  Average engagement score:"
echo "    Replies: $REPLY_AVG"
echo "    Original posts: $ORIG_AVG"

if [ $(echo "$REPLY_AVG > $ORIG_AVG" | bc -l 2>/dev/null || echo 0) -eq 1 ]; then
    DIFF=$(echo "scale=0; ($REPLY_AVG - $ORIG_AVG) / $ORIG_AVG * 100" | bc -l 2>/dev/null || echo 0)
    echo ""
    echo "  ✅ REPLIES OUTPERFORM by ${DIFF}%"
    echo "     Strategy: Prioritize high-reach reply targets"
else
    echo ""
    echo "  📝 Original posts performing better"
    echo "     Strategy: Focus on standalone content"
fi

echo ""
echo "===================================="

# Update timestamp
date +%s > "$STATE_FILE"
echo ""
echo "✅ Analysis complete. Next run will analyze from $(date '+%Y-%m-%d %H:%M')"
