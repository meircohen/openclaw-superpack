#!/bin/bash
# Heartbeat Memory Blocks Check
# Reads active_guidance and pending_items for heartbeat context

set -euo pipefail

WORKSPACE="$HOME/.openclaw/workspace"
BLOCKS_DIR="$WORKSPACE/memory/blocks"

echo "🧠 Memory Blocks Check"
echo ""

# Read active guidance
if [ -f "$BLOCKS_DIR/active_guidance.md" ]; then
    echo "📋 Active Guidance:"
    echo ""
    # Extract just the content sections (skip header and timestamp)
    sed -n '/^## Current Session Focus/,/^## Pending Decisions/p' "$BLOCKS_DIR/active_guidance.md" | grep -v "^## Pending Decisions"
    echo ""
fi

# Read pending items
if [ -f "$BLOCKS_DIR/pending_items.md" ]; then
    echo "⏳ Pending Items:"
    echo ""
    # Extract awaiting approval section
    sed -n '/^## Awaiting Approval/,/^## Active Tasks/p' "$BLOCKS_DIR/pending_items.md" | grep -v "^## Active Tasks"
    echo ""
fi

# Check for high-priority items
URGENT_COUNT=0

# Check for items awaiting approval
if grep -q "Awaiting Approval" "$BLOCKS_DIR/pending_items.md" 2>/dev/null; then
    APPROVAL_ITEMS=$(sed -n '/^## Awaiting Approval/,/^##/p' "$BLOCKS_DIR/pending_items.md" | grep "^-" | wc -l | tr -d ' ')
    if [ "$APPROVAL_ITEMS" -gt 0 ]; then
        echo "⚠️  $APPROVAL_ITEMS item(s) awaiting approval"
        URGENT_COUNT=$((URGENT_COUNT + APPROVAL_ITEMS))
    fi
fi

# Check for overdue next actions
CURRENT_HOUR=$(date +%H)
if [ "$CURRENT_HOUR" -gt 12 ]; then
    # After noon, check if morning actions were completed
    if grep -q "Next Actions" "$BLOCKS_DIR/active_guidance.md" 2>/dev/null; then
        echo "📌 Next actions to review (it's past noon):"
        sed -n '/^## Next Actions/,/^##/p' "$BLOCKS_DIR/active_guidance.md" | grep "^[0-9]" | head -3
        echo ""
    fi
fi

# Summary
if [ "$URGENT_COUNT" -eq 0 ]; then
    echo "✅ No urgent items requiring attention"
else
    echo "⚡ $URGENT_COUNT item(s) need attention"
fi
