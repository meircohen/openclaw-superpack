#!/bin/bash
# Generate shared/BRIEFING.md -- single-file context for Claude Code/Cowork sessions
# Run on every heartbeat to keep it fresh
#
# Customize the sections below for your setup. The briefing is the single file
# that other agents read at session start to understand current state.

set -euo pipefail

WORKSPACE="${OPENCLAW_WORKSPACE:-$HOME/.openclaw/workspace}"
SHARED="$WORKSPACE/shared"
MEMORY="$WORKSPACE/memory/blocks"
OUTPUT="$SHARED/BRIEFING.md"

NOW=$(date '+%Y-%m-%d %I:%M %p')
TODAY=$(date '+%Y-%m-%d')

cat > "$OUTPUT" << 'HEADER'
# Session Briefing
HEADER

echo "**Generated:** $NOW by orchestrator (auto-refreshed every heartbeat)" >> "$OUTPUT"
echo "**Read this first.** This is your single source of context. Don't read 6 files; this has everything." >> "$OUTPUT"
echo "" >> "$OUTPUT"

# Currently Working On
echo "## Currently Working On" >> "$OUTPUT"
grep -A5 "## Currently Working On" "$SHARED/CONTEXT.md" | grep -E "^(OpenClaw|Cowork|Claude)" >> "$OUTPUT" 2>/dev/null || echo "All systems idle" >> "$OUTPUT"
echo "" >> "$OUTPUT"

# Active priorities from memory blocks
echo "## Active Priorities" >> "$OUTPUT"
if [ -f "$MEMORY/active_guidance.md" ]; then
    sed -n '/## Current Priorities/,/^##/p' "$MEMORY/active_guidance.md" | head -20 | grep -v "^##" >> "$OUTPUT" 2>/dev/null
fi
echo "" >> "$OUTPUT"

# Hard rules -- CUSTOMIZE THESE FOR YOUR SETUP
echo "## Hard Rules (Never Violate)" >> "$OUTPUT"
echo "- Action over clarification. Fix first, explain second." >> "$OUTPUT"
# Add your own hard rules here:
# echo "- Your rule here" >> "$OUTPUT"
echo "" >> "$OUTPUT"

# Shabbat status (remove this section if not applicable)
if [ -f "$WORKSPACE/scripts/shabbat-times.sh" ]; then
    echo "## Shabbat Status" >> "$OUTPUT"
    SHABBAT_STATUS=$(bash "$WORKSPACE/scripts/shabbat-times.sh" check 2>/dev/null || echo "unknown")
    if [ "$SHABBAT_STATUS" = "shabbat" ]; then
        echo "**CURRENTLY SHABBAT** -- No non-emergency work. Only P0 escalations." >> "$OUTPUT"
    else
        bash "$WORKSPACE/scripts/shabbat-times.sh" summary 2>/dev/null | head -6 >> "$OUTPUT"
    fi
    echo "" >> "$OUTPUT"
fi

# Pending handoffs
echo "## Pending Handoffs" >> "$OUTPUT"
PENDING=$(find "$SHARED/handoffs" -name "*.md" ! -name ".gitkeep" -newer "$SHARED/handoffs/.gitkeep" 2>/dev/null | head -10)
if [ -n "$PENDING" ]; then
    for f in $PENDING; do
        STATUS=$(grep "^Status:" "$f" 2>/dev/null | head -1)
        TITLE=$(grep "^# Handoff:" "$f" 2>/dev/null | head -1)
        if echo "$STATUS" | grep -q "pending"; then
            echo "- PENDING: $TITLE ($STATUS)" >> "$OUTPUT"
        fi
    done
else
    echo "None" >> "$OUTPUT"
fi
echo "" >> "$OUTPUT"

# Escalations
echo "## Escalations" >> "$OUTPUT"
ESC=$(find "$SHARED/escalations" -name "*.md" 2>/dev/null | head -5)
if [ -n "$ESC" ]; then
    for f in $ESC; do
        echo "- WARNING: $(basename "$f")" >> "$OUTPUT"
    done
else
    echo "None" >> "$OUTPUT"
fi
echo "" >> "$OUTPUT"

# Queue snapshot
echo "## Work Queue (Top Items)" >> "$OUTPUT"
if [ -f "$SHARED/QUEUE.md" ]; then
    sed -n '/## In Progress/,/## Queued/p' "$SHARED/QUEUE.md" | head -10 >> "$OUTPUT" 2>/dev/null
    sed -n '/## Queued/,/## Blocked/p' "$SHARED/QUEUE.md" | head -10 >> "$OUTPUT" 2>/dev/null
    sed -n '/## Blocked/,/## Done/p' "$SHARED/QUEUE.md" | head -10 >> "$OUTPUT" 2>/dev/null
fi
echo "" >> "$OUTPUT"

# Recent sync log (last 5 entries)
echo "## Recent Sync Log" >> "$OUTPUT"
grep "^\- \[" "$SHARED/CONTEXT.md" | tail -5 >> "$OUTPUT" 2>/dev/null
echo "" >> "$OUTPUT"

# MCP Proxy status
echo "## Pending MCP Proxy Requests" >> "$OUTPUT"
MCP_PENDING=$(find "$SHARED/mcp-proxy/requests" -name "*.md" ! -name ".gitkeep" 2>/dev/null | head -5)
if [ -n "$MCP_PENDING" ]; then
    for f in $MCP_PENDING; do
        echo "- $(basename "$f")" >> "$OUTPUT"
    done
else
    echo "None" >> "$OUTPUT"
fi
echo "" >> "$OUTPUT"

echo "---" >> "$OUTPUT"
echo "*For full details: CONTEXT.md, DECISIONS.md, CAPABILITIES.md, ESCALATION.md, PROJECTS.md*" >> "$OUTPUT"
