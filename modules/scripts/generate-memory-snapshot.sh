#!/bin/bash
# Generate shared/MEMORY-SNAPSHOT.md — curated extract of OpenClaw's memory blocks
# Run once per day at first heartbeat after 8 AM

set -euo pipefail

MEMORY="$HOME/.openclaw/workspace/memory/blocks"
OUTPUT="$HOME/.openclaw/workspace/shared/MEMORY-SNAPSHOT.md"
NOW=$(date '+%Y-%m-%d %I:%M %p EDT')

cat > "$OUTPUT" << EOF
# Memory Snapshot
**Generated:** $NOW by OpenClaw
**Purpose:** Curated extract from OpenClaw's persistent memory. Gives Claude Code/Cowork the context depth that OpenClaw has natively.

---

EOF

# Active guidance (the most important block)
if [ -f "$MEMORY/active_guidance.md" ]; then
    echo "## Active Guidance" >> "$OUTPUT"
    cat "$MEMORY/active_guidance.md" >> "$OUTPUT"
    echo -e "\n---\n" >> "$OUTPUT"
fi

# Pending items
if [ -f "$MEMORY/pending_items.md" ]; then
    echo "## Pending Items" >> "$OUTPUT"
    cat "$MEMORY/pending_items.md" >> "$OUTPUT"
    echo -e "\n---\n" >> "$OUTPUT"
fi

# Session patterns (if exists)
if [ -f "$MEMORY/session_patterns.md" ]; then
    echo "## Session Patterns" >> "$OUTPUT"
    cat "$MEMORY/session_patterns.md" >> "$OUTPUT"
    echo -e "\n---\n" >> "$OUTPUT"
fi

# Tool usage (if exists)
if [ -f "$MEMORY/tool_usage.md" ]; then
    echo "## Tool Usage Patterns" >> "$OUTPUT"
    cat "$MEMORY/tool_usage.md" >> "$OUTPUT"
    echo -e "\n---\n" >> "$OUTPUT"
fi

# User profile from longterm
PROFILE="$HOME/.openclaw/workspace/memory/LONGTERM_PROFILE.md"
if [ -f "$PROFILE" ]; then
    echo "## Meir's Profile (Longterm)" >> "$OUTPUT"
    cat "$PROFILE" >> "$OUTPUT"
    echo -e "\n---\n" >> "$OUTPUT"
fi

# SOUL.md for personality consistency
SOUL="$HOME/.openclaw/workspace/SOUL.md"
if [ -f "$SOUL" ]; then
    echo "## Oz Personality (SOUL.md)" >> "$OUTPUT"
    cat "$SOUL" >> "$OUTPUT"
    echo -e "\n---\n" >> "$OUTPUT"
fi

echo "*End of memory snapshot. This file is regenerated daily.*" >> "$OUTPUT"
echo "[$(date '+%Y-%m-%d %H:%M:%S')] Memory snapshot generated: $(wc -l < "$OUTPUT") lines" >&2
