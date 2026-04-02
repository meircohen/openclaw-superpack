#!/bin/bash
# Pattern Recognition Engine - Proactive Insights
# Scans recent sessions for patterns and surfaces insights

set -euo pipefail

WORKSPACE="$HOME/.openclaw/workspace"
PATTERN_STATE="$WORKSPACE/state/pattern-recognition.json"
INSIGHTS_LOG="$WORKSPACE/memory/pattern-insights.md"

# Ensure state file exists
mkdir -p "$WORKSPACE/state"
if [[ ! -f "$PATTERN_STATE" ]]; then
    echo '{"last_scan":"","patterns":{}}' > "$PATTERN_STATE"
fi

# Time window: last 7 days of sessions
SINCE_DATE=$(date -v-7d +%Y-%m-%d 2>/dev/null || date -d "7 days ago" +%Y-%m-%d)

echo "🔍 Scanning sessions since $SINCE_DATE for patterns..."

# Find session logs (adjust path based on where OpenClaw stores them)
# This is placeholder - need actual session log location
SESSION_LOGS=$(find "$HOME/.openclaw/logs" -name "*.jsonl" -mtime -7 2>/dev/null || echo "")

if [[ -z "$SESSION_LOGS" ]]; then
    echo "⚠️  No session logs found. Pattern recognition needs session history."
    exit 0
fi

# Scan session logs for patterns
# Note: bash 3.2 compatible - use temp files instead of associative arrays
while IFS= read -r log_file; do
    if [[ ! -f "$log_file" ]]; then continue; fi
    
    # Extract user messages (adjust jq filter based on actual log format)
    USER_MESSAGES=$(jq -r 'select(.role=="user") | .content' "$log_file" 2>/dev/null || echo "")
    
    if [[ -z "$USER_MESSAGES" ]]; then continue; fi
    
    # Count topic mentions
    echo "$USER_MESSAGES" | grep -io "btc\|bitcoin\|mining" | wc -l | xargs echo "bitcoin" >> /tmp/pattern_topics
    echo "$USER_MESSAGES" | grep -io "x\|twitter\|tweet\|post" | wc -l | xargs echo "x_growth" >> /tmp/pattern_topics
    echo "$USER_MESSAGES" | grep -io "eli\|partner\|trust" | wc -l | xargs echo "partnership" >> /tmp/pattern_topics
    echo "$USER_MESSAGES" | grep -io "tax\|filing\|1065\|k-1" | wc -l | xargs echo "tax" >> /tmp/pattern_topics
    echo "$USER_MESSAGES" | grep -io "nechie\|family\|kids" | wc -l | xargs echo "family" >> /tmp/pattern_topics
    echo "$USER_MESSAGES" | grep -io "george\|coaching\|routine" | wc -l | xargs echo "coaching" >> /tmp/pattern_topics
    
    # Detect decision loops (same question within 48h)
    echo "$USER_MESSAGES" | grep -i "should i\|what do you think\|advice" >> /tmp/pattern_decisions 2>/dev/null || true
    
    # Stress indicators
    echo "$USER_MESSAGES" | grep -i "stressed\|overwhelmed\|anxious\|worried" >> /tmp/pattern_stress 2>/dev/null || true
    
done <<< "$SESSION_LOGS"

# Analyze patterns
INSIGHTS=""

# Topic frequency analysis
if [[ -f /tmp/pattern_topics ]]; then
    TOP_TOPICS=$(sort /tmp/pattern_topics | uniq -c | sort -rn | head -3)
    
    while read -r count topic; do
        if [[ $count -gt 5 ]]; then
            INSIGHTS="${INSIGHTS}\n- **${topic}** mentioned ${count}x this week (high frequency)"
        fi
    done <<< "$TOP_TOPICS"
fi

# Decision loop detection
if [[ -f /tmp/pattern_decisions ]]; then
    DECISION_COUNT=$(wc -l < /tmp/pattern_decisions | tr -d ' ')
    if [[ $DECISION_COUNT -gt 3 ]]; then
        INSIGHTS="${INSIGHTS}\n- Detected ${DECISION_COUNT} decision-seeking questions this week (possible analysis paralysis)"
    fi
fi

# Stress pattern
if [[ -f /tmp/pattern_stress ]]; then
    STRESS_COUNT=$(wc -l < /tmp/pattern_stress | tr -d ' ')
    if [[ $STRESS_COUNT -gt 2 ]]; then
        INSIGHTS="${INSIGHTS}\n- Stress indicators detected ${STRESS_COUNT}x this week (consider coaching check-in)"
    fi
fi

# Cross-domain opportunities (check if multiple high-frequency topics that could connect)
BTC_COUNT=$(grep -c "bitcoin" /tmp/pattern_topics 2>/dev/null || echo "0")
X_COUNT=$(grep -c "x_growth" /tmp/pattern_topics 2>/dev/null || echo "0")
if [[ $BTC_COUNT -gt 3 && $X_COUNT -gt 3 ]]; then
    INSIGHTS="${INSIGHTS}\n- **Cross-domain opportunity**: High activity in both Bitcoin and X growth → could create mining infrastructure content for X audience"
fi

# Cleanup temp files
rm -f /tmp/pattern_topics /tmp/pattern_decisions /tmp/pattern_stress

# Write insights if any found
if [[ -n "$INSIGHTS" ]]; then
    echo "" >> "$INSIGHTS_LOG"
    echo "## Pattern Recognition - $(date +%Y-%m-%d)" >> "$INSIGHTS_LOG"
    echo -e "$INSIGHTS" >> "$INSIGHTS_LOG"
    echo "" >> "$INSIGHTS_LOG"
    
    echo "✅ Insights logged to memory/pattern-insights.md"
    echo ""
    echo "📊 Patterns detected:"
    echo -e "$INSIGHTS"
else
    echo "✅ Scan complete. No significant patterns detected this week."
fi

# Update state
jq --arg date "$(date -u +%Y-%m-%dT%H:%M:%SZ)" '.last_scan = $date' "$PATTERN_STATE" > "$PATTERN_STATE.tmp"
mv "$PATTERN_STATE.tmp" "$PATTERN_STATE"
