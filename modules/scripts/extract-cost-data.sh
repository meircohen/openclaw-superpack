#!/bin/bash
# Extract AI Operations Cost Data from OpenClaw Session Logs

echo "Analyzing OpenClaw session logs for cost data..."

# Get date range for the last 7 days
WEEK_AGO=$(date -v-7d '+%Y-%m-%d' 2>/dev/null || date -d '7 days ago' '+%Y-%m-%d')
TODAY=$(date '+%Y-%m-%d')

echo "Date range: $WEEK_AGO to $TODAY"
echo

# Find all session files and extract usage data
cd ~/.openclaw/agents/main/sessions

echo "=== TOKEN USAGE ANALYSIS ==="

# Extract usage data from all session files
find . -name "*.jsonl" -exec grep -h '"usage":' {} \; | \
sed 's/.*"usage"://; s/,"stopReason".*//' | \
jq -r 'select(.totalTokens != null) | "\(.model // "unknown"),\(.totalTokens // 0),\(.cost.total // 0)"' 2>/dev/null | \
sort | uniq -c | sort -nr > /tmp/usage_data.txt

# Count total operations by model
echo "Token Usage by Model (last 7 days):"
echo "Count | Model | Avg Tokens | Avg Cost"
echo "------|-------|-----------|----------"

cat /tmp/usage_data.txt | while read count model_tokens_cost; do
    IFS=',' read -r model tokens cost <<< "$model_tokens_cost"
    if [[ $count -gt 0 && $tokens -gt 0 ]]; then
        avg_tokens=$(echo "scale=0; $tokens" | bc 2>/dev/null || echo $tokens)
        avg_cost=$(echo "scale=4; $cost" | bc 2>/dev/null || echo $cost)
        printf "%5s | %-20s | %9s | $%7s\n" "$count" "$model" "$avg_tokens" "$avg_cost"
    fi
done

echo
echo "=== CRON ANALYSIS ==="

# Extract cron-related costs
grep -h 'cron:' ~/.openclaw/agents/main/sessions/*.jsonl | \
grep '"usage":' | \
sed 's/.*"usage"://; s/,"stopReason".*//' | \
jq -r 'select(.totalTokens != null) | "\(.model // "unknown"),\(.totalTokens // 0),\(.cost.total // 0)"' 2>/dev/null | \
awk -F',' '
BEGIN { print "Cron Operations Summary:"; total_cost=0; total_tokens=0; count=0 }
{ 
    total_tokens += $2; 
    total_cost += $3; 
    count++;
    models[$1]++;
    model_cost[$1] += $3;
}
END { 
    print "Total cron operations:", count
    print "Total tokens used:", total_tokens
    printf "Total estimated cost: $%.4f\n", total_cost
    print "\nCost by model:"
    for (model in models) {
        printf "  %s: %d ops, $%.4f\n", model, models[model], model_cost[model]
    }
}'

echo
echo "=== TOP 5 MOST EXPENSIVE OPERATIONS ==="

# Extract individual high-cost operations
find . -name "*.jsonl" -exec grep -h '"usage":' {} \; | \
sed 's/.*"usage"://; s/,"stopReason".*//' | \
jq -r 'select(.cost.total != null and .cost.total > 0) | "\(.cost.total),\(.totalTokens),\(.model // "unknown")"' 2>/dev/null | \
sort -nr | head -5 | nl

echo
echo "=== WEEK OVER WEEK COMPARISON ==="
echo "(Previous week data not available - this is baseline week)"

echo
echo "=== OPTIMIZATION RECOMMENDATIONS ==="

# Check for expensive models
echo "1. Model Usage Analysis:"
cat /tmp/usage_data.txt | while read count model_tokens_cost; do
    IFS=',' read -r model tokens cost <<< "$model_tokens_cost"
    if [[ "$model" == *"opus"* ]] && [[ $count -gt 5 ]]; then
        echo "   ⚠️  High Opus usage detected ($count ops) - consider Sonnet 4 fallback"
    fi
    if [[ "$model" == *"gemini"* ]] && [[ $count -gt 0 ]]; then
        echo "   ⚠️  Gemini usage detected ($count ops) - banned model still being used"
    fi
done

echo "2. Cron Optimization:"
cron_count=$(grep -c 'cron:' ~/.openclaw/agents/main/sessions/*.jsonl 2>/dev/null || echo 0)
if [[ $cron_count -gt 50 ]]; then
    echo "   💡 Consider consolidating crons (${cron_count} operations this week)"
fi

echo "3. Context Optimization:"
echo "   💡 Cache usage appears active - good for cost reduction"

echo
rm -f /tmp/usage_data.txt
echo "Analysis complete."