#!/bin/bash
# Get metrics for all recent tweets using batch processing
# Works around the "argument list too long" error

set -euo pipefail

TWITTER_CLI="/Users/meircohen/Library/Python/3.9/bin/twitter"
OUTPUT_FILE="/Users/meircohen/.openclaw/workspace/state/x-metrics-$(date +%Y-%m-%d).json"

echo "📊 Fetching X metrics (batch mode)..."
echo ""

# Get list of our recent tweet IDs from engagement log
echo "Step 1: Getting tweet IDs from engagement log..."
TWEET_IDS=$(grep -o '"reply_id":"[0-9]*"' /Users/meircohen/.openclaw/workspace/artifacts/x-engagement-log.jsonl 2>/dev/null | cut -d'"' -f4 | sort -u | tail -20 || echo "")

if [ -z "$TWEET_IDS" ]; then
    echo "No tweet IDs found in engagement log. Trying different approach..."
    # Fallback: get from our recent posts (last 20 only)
    TWEET_IDS=$($TWITTER_CLI user-posts MeirCohen --max 20 --json 2>/dev/null | jq -r '.data[]?.id' 2>/dev/null || echo "")
fi

if [ -z "$TWEET_IDS" ]; then
    echo "❌ Could not get tweet IDs"
    exit 1
fi

echo "Found $(echo "$TWEET_IDS" | wc -l | tr -d ' ') tweets to check"
echo ""

# Fetch metrics for each tweet individually
echo "Step 2: Fetching metrics..."
echo "[" > "$OUTPUT_FILE"
FIRST=true

for id in $TWEET_IDS; do
    echo -n "  Checking $id..."
    
    # Search for this specific tweet
    result=$($TWITTER_CLI user-posts MeirCohen --max 20 --json 2>/dev/null | jq ".data[] | select(.id == \"$id\")" 2>/dev/null || echo "")
    
    if [ -n "$result" ]; then
        # Add comma if not first
        if [ "$FIRST" = false ]; then
            echo "," >> "$OUTPUT_FILE"
        fi
        FIRST=false
        
        # Save the tweet data
        echo "$result" | jq -c '{
            id,
            text: .text[:100],
            likes: .metrics.likes,
            retweets: .metrics.retweets,
            replies: .metrics.replies,
            views: .metrics.views,
            bookmarks: .metrics.bookmarks,
            created: .createdAt,
            score: (.metrics.likes + (.metrics.replies * 3) + (.metrics.retweets * 2))
        }' >> "$OUTPUT_FILE"
        
        likes=$(echo "$result" | jq -r '.metrics.likes')
        echo " ✓ ($likes likes)"
    else
        echo " (not found)"
    fi
    
    # Small delay to avoid rate limits
    sleep 0.5
done

echo "]" >> "$OUTPUT_FILE"

echo ""
echo "✅ Complete! Data saved to: $OUTPUT_FILE"
echo ""

# Show top 5
echo "Top 5 performers:"
jq -r 'sort_by(.score) | reverse | .[:5] | .[] | "  \(.score) score | \(.likes)L \(.retweets)RT \(.views)V | \(.text)..."' "$OUTPUT_FILE" 2>/dev/null || echo "  (Could not parse results)"
