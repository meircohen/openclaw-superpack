#!/usr/bin/env bash
# x-growth-report.sh - Weekly growth report for @MeirCohen
# Usage: bash scripts/x-growth-report.sh

set -euo pipefail

WORKSPACE="$HOME/.openclaw/workspace"
STATE_DIR="$WORKSPACE/skills/x-growth/state"
REPORTS_DIR="$WORKSPACE/skills/x-growth/reports"

mkdir -p "$STATE_DIR" "$REPORTS_DIR"

TODAY=$(date +%Y-%m-%d)
NOW_HUMAN=$(date +"%Y-%m-%d %H:%M ET")
REPORT_FILE="$REPORTS_DIR/weekly-report-$TODAY.md"
BASELINE_FILE="$STATE_DIR/follower-baseline.json"

# Fetch current profile
PROFILE_JSON=$(twitter user MeirCohen --json 2>/dev/null || true)

if [ -z "$PROFILE_JSON" ] || ! echo "$PROFILE_JSON" | jq -e '.data.followers' >/dev/null 2>&1; then
  echo "❌ Failed to fetch profile data via twitter user MeirCohen --json"
  exit 1
fi

FOLLOWERS_NOW=$(echo "$PROFILE_JSON" | jq -r '.data.followers')
FOLLOWING_NOW=$(echo "$PROFILE_JSON" | jq -r '.data.following')
TWEETS_NOW=$(echo "$PROFILE_JSON" | jq -r '.data.tweets')

# Load baseline
FOLLOWERS_THEN=""
BASELINE_DATE=""
if [ -f "$BASELINE_FILE" ]; then
  FOLLOWERS_THEN=$(jq -r '.followers' "$BASELINE_FILE")
  BASELINE_DATE=$(jq -r '.date' "$BASELINE_FILE")
else
  # Initialize baseline if missing
  jq -n --arg date "$TODAY" --argjson followers "$FOLLOWERS_NOW" '{date:$date, followers:$followers}' > "$BASELINE_FILE"
  FOLLOWERS_THEN=$FOLLOWERS_NOW
  BASELINE_DATE=$TODAY
fi

DELTA_FOLLOWERS=$((FOLLOWERS_NOW - FOLLOWERS_THEN))

# Pull recent Meir posts (last 20) and compute top performers by views
POSTS_JSON=$(twitter user-posts MeirCohen -n 20 --json 2>/dev/null | jq '.data // []')

TOP_POSTS=$(echo "$POSTS_JSON" | jq -r '
  if type == "array" and length > 0 then
    sort_by(.metrics.views // 0) | reverse | .[0:5] | 
    .[] | 
    "- [https://x.com/MeirCohen/status/\(.id)] | \(.metrics.views // 0) views | \(.metrics.likes // 0) likes\n  \"\(.text | gsub("\n";" ") | .[0:160])\""
  else
    "No posts available"
  end
')

# Engagement rate proxy: (likes+replies+RTs) across last 20
ENGAGEMENT=$(echo "$POSTS_JSON" | jq -r '
  if type == "array" and length > 0 then
    map(.metrics | {likes: (.likes // 0), replies: (.replies // 0), retweets: (.retweets // 0)} | .likes + .replies + .retweets) | add
  else
    "0"
  end | tostring
')

# Write report
cat > "$REPORT_FILE" <<EOF
# Weekly X Growth Report - $NOW_HUMAN

## Account Snapshot
- Handle: @MeirCohen
- Followers: $FOLLOWERS_NOW
- Following: $FOLLOWING_NOW
- Tweets: $TWEETS_NOW

## Growth Since Baseline
- Baseline date: $BASELINE_DATE
- Followers then: $FOLLOWERS_THEN
- Followers now: $FOLLOWERS_NOW
- Net change: $DELTA_FOLLOWERS

## Top 5 Posts (last 20)
$TOP_POSTS

## Engagement (last 20 posts)
- Total actions (likes+replies+RTs): $ENGAGEMENT

## Notes
- If growth is flat: increase high-speed replies to @libsoftiktok and other mega accounts.
- If views are strong but follows are weak: make profile bio tighter and pin a "what I do" post.

---

**Next step:** Review top post topics and double down on the winners this week.
EOF

echo "✅ Report written: $REPORT_FILE"

echo ""
echo "📌 Tip: Update baseline monthly if you want longer-term tracking."
