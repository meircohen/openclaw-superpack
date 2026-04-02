#!/usr/bin/env bash
# x-top-followers-scan.sh - Monitor top followers for reply opportunities
# Usage: bash scripts/x-top-followers-scan.sh [--notify]

set -euo pipefail

WORKSPACE="$HOME/.openclaw/workspace"
STATE_DIR="$WORKSPACE/skills/x-growth/state"
NOTIFY_FLAG="${1:-}"

mkdir -p "$STATE_DIR"

# Top 10 high-value followers to monitor (prioritized by engagement potential)
TARGETS=(
  "libsoftiktok"    # 4.7M - TIER 1 MUTUAL
  "darrenmarble"    # 59K - TIER 1 MUTUAL
  "larrykim"        # 685K - TIER 2
  "briankrebs"      # 331K - TIER 2
  "bitcoin_dad"     # 135K - TIER 2
  "smartviewai"     # 70K - TIER 2
  "Awesome_Jew_"    # 65K - TIER 2
  "balajis"         # 1.4M - TIER 3
  "ShaanVP"         # 463K - TIER 3
  "paulg"           # 2.3M - TIER 3
)

TIMESTAMP=$(date +%s)
OUTPUT_FILE="$STATE_DIR/scan-$(date +%Y-%m-%d-%H%M).json"
OPPORTUNITIES_FILE="$STATE_DIR/opportunities-latest.md"

echo "🔍 Scanning top followers for reply opportunities..."
echo "📅 $(date)"
echo ""

# Initialize opportunities file
cat > "$OPPORTUNITIES_FILE" <<EOF
# Reply Opportunities - $(date +"%Y-%m-%d %H:%M ET")

**Scan completed:** $(date)
**Accounts monitored:** ${#TARGETS[@]}

---

EOF

OPPORTUNITY_COUNT=0

# Scan each target
for handle in "${TARGETS[@]}"; do
  echo "👤 Checking @$handle..."
  
  # Fetch last 3 posts
  POSTS_FILE="$STATE_DIR/posts-$handle-latest.json"
  twitter search "from:$handle" -n 3 --json > "$POSTS_FILE" 2>&1 || {
    echo "   ⚠️  Failed to fetch posts from @$handle"
    continue
  }
  
  # Extract posts from last 24 hours with >100 likes (engagement threshold)
  RECENT_POSTS=$(jq -r --arg cutoff "$((TIMESTAMP - 86400))" '
    .[] | select(
      (.createdAt | fromdateiso8601) > ($cutoff | tonumber) and
      .metrics.likes > 100
    ) | {
      id: .id,
      text: .text,
      likes: .metrics.likes,
      replies: .metrics.replies,
      views: .metrics.views,
      age_hours: (($cutoff | tonumber) - (.createdAt | fromdateiso8601)) / 3600 | floor,
      url: "https://x.com/\(.author.screenName)/status/\(.id)"
    }
  ' "$POSTS_FILE" 2>/dev/null || echo "[]")
  
  if [ "$RECENT_POSTS" != "[]" ] && [ -n "$RECENT_POSTS" ]; then
    # Found opportunities
    POST_COUNT=$(echo "$RECENT_POSTS" | jq -s 'length')
    OPPORTUNITY_COUNT=$((OPPORTUNITY_COUNT + POST_COUNT))
    
    echo "   ✅ Found $POST_COUNT high-engagement post(s)"
    
    # Add to opportunities file
    cat >> "$OPPORTUNITIES_FILE" <<EOF
## @$handle

EOF
    
    echo "$RECENT_POSTS" | jq -r '. | 
      "**Post ID:** \(.id)\n" +
      "**Engagement:** \(.likes) likes, \(.replies) replies, \(.views) views\n" +
      "**Posted:** \(.age_hours)h ago\n" +
      "**URL:** \(.url)\n\n" +
      "**Text:**\n> \(.text)\n\n" +
      "**Reply window:** \(if .age_hours < 2 then "🔴 HOT (reply NOW)" elif .age_hours < 6 then "🟡 WARM (reply soon)" else "⚪ COLD (optional)" end)\n\n---\n"
    ' >> "$OPPORTUNITIES_FILE"
  else
    echo "   ℹ️  No high-engagement posts in last 24h"
  fi
  
  # Rate limit protection
  sleep 2
done

# Summary
cat >> "$OPPORTUNITIES_FILE" <<EOF

## Summary

**Total opportunities:** $OPPORTUNITY_COUNT
**Recommended action:** Review opportunities above and draft 3-5 high-value replies

**Priority order:**
1. 🔴 HOT posts (<2h old) - reply immediately for visibility
2. @libsoftiktok + @darrenmarble - ALWAYS prioritize (mutual follows)
3. Posts with 500+ likes - high viral potential
4. Topics in Meir's lanes: Israel, antisemitism, AI/tech, woke overreach

**Next scan:** In 2 hours (auto-scheduled via cron)

EOF

echo ""
echo "✅ Scan complete"
echo "📊 Found $OPPORTUNITY_COUNT reply opportunities"
echo "📄 Details: $OPPORTUNITIES_FILE"

# Optional: Send notification (if --notify flag passed)
if [ "$NOTIFY_FLAG" = "--notify" ] && [ $OPPORTUNITY_COUNT -gt 0 ]; then
  echo ""
  echo "📢 Sending notification..."
  
  # Create summary for notification
  SUMMARY="🎯 X Engagement Scan: Found $OPPORTUNITY_COUNT opportunities"
  HOT_COUNT=$(grep -c "🔴 HOT" "$OPPORTUNITIES_FILE" || true)
  
  if [ $HOT_COUNT -gt 0 ]; then
    SUMMARY="$SUMMARY\n\n🔴 $HOT_COUNT HOT posts (reply now!)"
  fi
  
  SUMMARY="$SUMMARY\n\nFull report: $OPPORTUNITIES_FILE"
  
  # TODO: Add notification command here (message tool or other)
  # For now, just echo
  echo -e "$SUMMARY"
fi

echo ""
echo "🔗 Quick review: cat $OPPORTUNITIES_FILE"
