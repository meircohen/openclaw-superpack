#!/usr/bin/env bash
# x-mutual-engagement.sh - Fast monitoring of mutual follows for immediate reply opportunities
# Usage: bash scripts/x-mutual-engagement.sh

set -euo pipefail

WORKSPACE="$HOME/.openclaw/workspace"
STATE_DIR="$WORKSPACE/skills/x-growth/state"

mkdir -p "$STATE_DIR"

# Mutual follows (accounts that follow Meir AND he follows back)
MUTUALS=(
  "libsoftiktok"   # 4.7M followers - TOP PRIORITY
  "darrenmarble"   # 59K followers
)

TIMESTAMP=$(date +%s)
ALERT_FILE="$STATE_DIR/mutual-alerts-$(date +%Y-%m-%d).md"

echo "⚡ MUTUAL FOLLOW MONITOR"
echo "📅 $(date)"
echo ""

# Check if alert file exists, if not create header
if [ ! -f "$ALERT_FILE" ]; then
  cat > "$ALERT_FILE" <<EOF
# Mutual Follow Alerts - $(date +%Y-%m-%d)

**Purpose:** Fast notifications for fresh posts from mutual follows
**Action required:** Reply within 5 minutes for maximum visibility

---

EOF
fi

NEW_ALERTS=0

for handle in "${MUTUALS[@]}"; do
  echo "👤 Checking @$handle..."
  
  # Fetch latest post only (n=1 for speed)
  LATEST_POST=$(twitter search "from:$handle" -n 1 --json 2>&1)
  
  # Check if it's a valid response
  if echo "$LATEST_POST" | jq -e '. | length > 0' >/dev/null 2>&1; then
    POST_ID=$(echo "$LATEST_POST" | jq -r '.[0].id')
    POST_TIME=$(echo "$LATEST_POST" | jq -r '.[0].createdAt')
    POST_TEXT=$(echo "$LATEST_POST" | jq -r '.[0].text')
    POST_LIKES=$(echo "$LATEST_POST" | jq -r '.[0].metrics.likes')
    POST_URL="https://x.com/$handle/status/$POST_ID"
    
    # Calculate age in minutes
    POST_TIMESTAMP=$(date -j -f "%a %b %d %H:%M:%S %z %Y" "$POST_TIME" +%s 2>/dev/null || echo "0")
    AGE_MINUTES=$(( (TIMESTAMP - POST_TIMESTAMP) / 60 ))
    
    # Alert if post is <30 minutes old
    if [ $AGE_MINUTES -lt 30 ] && [ $AGE_MINUTES -ge 0 ]; then
      echo "   🔴 FRESH POST: $AGE_MINUTES minutes ago"
      echo "   💬 \"${POST_TEXT:0:100}...\""
      echo "   🔗 $POST_URL"
      
      # Check if we've already alerted on this post
      if ! grep -q "$POST_ID" "$ALERT_FILE" 2>/dev/null; then
        # New alert!
        NEW_ALERTS=$((NEW_ALERTS + 1))
        
        cat >> "$ALERT_FILE" <<EOF

## 🔴 ALERT: @$handle posted $AGE_MINUTES minutes ago

**Time:** $(date)
**Post ID:** $POST_ID
**URL:** $POST_URL
**Engagement:** $POST_LIKES likes (at time of scan)

**Text:**
\`\`\`
$POST_TEXT
\`\`\`

**ACTION:** Reply NOW for visibility (target: top 10 replies)

**Suggested approach:**
EOF
        
        # Add tailored suggestions based on account
        if [ "$handle" = "libsoftiktok" ]; then
          cat >> "$ALERT_FILE" <<EOF
- Lead with emotion: "This is insane", "Unbelievable", "Parents need to see this"
- Add personal angle: "As a father of 4..." or "As a Jew watching this..."
- Amplify her message, don't nitpick
- Keep it punchy (1-2 sentences max)

EOF
        elif [ "$handle" = "darrenmarble" ]; then
          cat >> "$ALERT_FILE" <<EOF
- Thoughtful, personal response (he values relationships)
- If it's Jewish content: share similar experience
- If it's venture content: add agent/zero-employee angle
- Congratulate on wins, ask smart questions on insights

EOF
        fi
        
        cat >> "$ALERT_FILE" <<EOF
**Reply deadline:** $(date -v+5M +"%H:%M ET") (5 min from now)

---

EOF
        
        echo ""
        echo "   ✅ NEW ALERT LOGGED"
      else
        echo "   ℹ️  Already alerted on this post"
      fi
    else
      echo "   ⚪ Latest post is $AGE_MINUTES minutes old (not urgent)"
    fi
  else
    echo "   ⚠️  Failed to fetch posts"
  fi
  
  # Rate limit
  sleep 1
done

echo ""
if [ $NEW_ALERTS -gt 0 ]; then
  echo "🚨 $NEW_ALERTS NEW ALERT(S) - REPLY NOW!"
  echo "📄 Details: $ALERT_FILE"
  echo ""
  echo "Quick view:"
  tail -30 "$ALERT_FILE"
else
  echo "✅ No new alerts (all posts >30min old or already seen)"
fi

echo ""
echo "📊 Full alert log: cat $ALERT_FILE"
