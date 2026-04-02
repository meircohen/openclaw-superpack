#!/bin/bash
# Weekly budget report - shows spending by agent
set -e

WORKSPACE_ROOT="$HOME/.openclaw/workspace"
cd "$WORKSPACE_ROOT"

echo "📊 Weekly Token Budget Report"
echo "=============================="
echo ""

# Get current usage report
node lib/smart-router.js report | jq -r '
  "Month: \(.month)",
  "Total Spent: $\(.total_spent) / $\(.total_budget) (\(.total_pct_used)%)",
  "",
  "Per-Agent Breakdown:",
  (
    .agents | to_entries | map(
      "  \(.key | ascii_upcase): $\(.value.spent)/$\(.value.budget) (\(.value.pct_used)%) - \(.value.sessions) sessions - \(.value.status)"
    ) | .[]
  ),
  "",
  (
    if (.total_pct_used | tonumber) >= 90 then
      "🚨 ALERT: Total budget at 90%+ - auto-downgrade in effect"
    elif (.total_pct_used | tonumber) >= 75 then
      "⚠️ WARNING: Total budget at 75%+ - approaching limit"
    else
      "✅ Budget healthy"
    end
  )
'

# Check for any agents over budget
OVER_BUDGET=$(node lib/smart-router.js report | jq -r '.agents | to_entries[] | select(.value.status == "downgrade") | .key' | wc -l)

if [ "$OVER_BUDGET" -gt 0 ]; then
  echo ""
  echo "🚨 Agents over budget: $OVER_BUDGET"
  echo "   Non-critical tasks auto-downgraded to cheaper models"
fi
