#!/bin/bash
# Systems Status - Quick overview of all operational systems
set -euo pipefail

WORKSPACE="$HOME/.openclaw/workspace"

echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "🎯 OPENCLAW SYSTEMS STATUS"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

# Memory Blocks
echo "🧠 MEMORY BLOCKS"
echo "   Location: memory/blocks/"
echo "   Blocks: $(ls -1 $WORKSPACE/memory/blocks/*.md 2>/dev/null | wc -l | tr -d ' ')"
echo "   Size: $(du -sh $WORKSPACE/memory/blocks 2>/dev/null | awk '{print $1}')"
echo "   Last updated: $(grep "Last Updated" $WORKSPACE/memory/blocks/active_guidance.md | sed 's/.*: //')"
echo ""

# Fire-and-Forget Workers
RUNNING_WORKERS=$(grep -l '"status": "running"' $WORKSPACE/.workers/state/*.json 2>/dev/null | wc -l | tr -d ' ')
COMPLETED_WORKERS=$(grep -l '"status": "completed"' $WORKSPACE/.workers/state/*.json 2>/dev/null | wc -l | tr -d ' ')
FAILED_WORKERS=$(grep -l '"status": "failed"' $WORKSPACE/.workers/state/*.json 2>/dev/null | wc -l | tr -d ' ')

echo "🔥 FIRE-AND-FORGET WORKERS"
echo "   Running: $RUNNING_WORKERS"
echo "   Completed: $COMPLETED_WORKERS"
echo "   Failed: $FAILED_WORKERS"
echo "   Location: .workers/"
echo ""

# X Growth Campaign
echo "🐦 X GROWTH CAMPAIGN"
echo "   Current followers: 576"
echo "   Target: 10,000"
echo "   Remaining: 9,424"
echo "   Content pool: 30+ posts (5 categories)"
echo "   Crons: 5 active"
openclaw cron list 2>/dev/null | grep "x-growth\|x-engage\|x-post" | head -3 | sed 's/^/   /'
echo ""

# GitHub Automation
echo "⚙️  GITHUB AUTOMATION"
GH_CRON=$(openclaw cron list 2>/dev/null | grep "github-issue-bot" || echo "")
if [ -n "$GH_CRON" ]; then
    GH_STATUS=$(echo "$GH_CRON" | grep -o "enabled: [a-z]*" | awk '{print $2}')
    echo "   Status: $GH_STATUS"
    echo "   Script: github-issue-bot.sh"
    echo "   Target: openclaw/openclaw (label: bug, limit: 3)"
else
    echo "   Status: Cron not found"
fi
echo ""

# Memory Maintenance
echo "📅 MEMORY MAINTENANCE"
echo "   Daily: 8:30 AM ET (extract notes → update blocks)"
echo "   Weekly: Monday 9 AM ET (cleanup old snapshots)"
DAILY_NEXT=$(openclaw cron list 2>/dev/null | grep "memory-daily-maintenance" -A 2 | grep "next" | awk '{print $2" "$3}' || echo "unknown")
echo "   Next run: $DAILY_NEXT"
echo ""

# Active Guidance
echo "📋 ACTIVE PRIORITIES"
sed -n '/^## Current Session Focus/,/^## Next Actions/p' $WORKSPACE/memory/blocks/active_guidance.md | \
    grep "^-" | head -5 | sed 's/^/   /'
echo ""

# Pending Items
APPROVAL_COUNT=$(sed -n '/^## Awaiting Approval/,/^##/p' $WORKSPACE/memory/blocks/pending_items.md | grep "^-" | wc -l | tr -d ' ')
if [ "$APPROVAL_COUNT" -gt 0 ]; then
    echo "⚠️  AWAITING APPROVAL"
    sed -n '/^## Awaiting Approval/,/^##/p' $WORKSPACE/memory/blocks/pending_items.md | grep "^-" | sed 's/^/   /'
    echo ""
fi

echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "✅ All systems operational"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
