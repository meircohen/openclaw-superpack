#!/bin/bash
# Get full metrics for specific tweets using twitter CLI search
# Usage: bash x-get-tweet-metrics.sh "<search text>"

set -euo pipefail

TWITTER_CLI="/Users/meircohen/Library/Python/3.9/bin/twitter"
SEARCH_TEXT="$1"

if [ -z "$SEARCH_TEXT" ]; then
    echo "Usage: $0 \"<search text>\""
    exit 1
fi

echo "Searching for: $SEARCH_TEXT"
echo ""

$TWITTER_CLI search "$SEARCH_TEXT" --json 2>&1 | jq -r '.data[] | 
    select(.author.screenName == "MeirCohen") | 
    {
        id: .id,
        likes: .metrics.likes,
        retweets: .metrics.retweets,
        replies: .metrics.replies,
        views: .metrics.views,
        bookmarks: .metrics.bookmarks,
        score: (.metrics.likes + (.metrics.replies * 3) + (.metrics.retweets * 2)),
        text: .text[:100]
    } | "Score: \(.score) | \(.likes)L \(.retweets)RT \(.replies)R \(.views)V \(.bookmarks)BM\n  \(.text)...\n"'
