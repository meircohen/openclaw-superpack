#!/bin/bash
# Generate shared/CODEX-BRIEFING.md — coding-specific context for Codex sessions
# Run on heartbeat alongside generate-code-briefing.sh
# Modeled after generate-code-briefing.sh but tailored for Codex's async code workflow

set -uo pipefail

SHARED="$HOME/.openclaw/workspace/shared"
SCRIPTS="$HOME/.openclaw/workspace/scripts"
OUTPUT="$SHARED/CODEX-BRIEFING.md"
NOW=$(date '+%Y-%m-%d %I:%M %p EDT')

cat > "$OUTPUT" << EOF
# Codex Session Briefing
**Generated:** $NOW by OpenClaw (auto-refreshed every heartbeat)
**Purpose:** Coding-specific context for Codex. Read this before writing any code.
**Startup checklist:** shared/CODEX-STARTUP.md

EOF

# Active code tasks from QUEUE.md
echo "## Active Code Tasks" >> "$OUTPUT"
if [ -f "$SHARED/QUEUE.md" ]; then
    IN_PROGRESS=$(sed -n '/## In Progress/,/## Queued/p' "$SHARED/QUEUE.md" | grep -v "^##" | grep -v "^<!--" | grep -v "^$" | head -10)
    if [ -n "$IN_PROGRESS" ]; then
        echo "$IN_PROGRESS" >> "$OUTPUT"
    else
        echo "None in progress" >> "$OUTPUT"
    fi
    echo "" >> "$OUTPUT"
    echo "### Queued (code-related)" >> "$OUTPUT"
    sed -n '/## Queued/,/## Blocked/p' "$SHARED/QUEUE.md" | grep -iE "(deploy|fix|build|test|refactor|code|pr |merge|bug|feature|api|worker|page|component)" | head -10 >> "$OUTPUT" 2>/dev/null || echo "None" >> "$OUTPUT"
fi
echo "" >> "$OUTPUT"

# Recent git activity across known repos
echo "## Recent Git Activity (Last 3 Days)" >> "$OUTPUT"
for repo in \
    "$HOME/Desktop/icare-diagnostics" \
    "$HOME/Desktop/doss-ai" \
    "$HOME/Desktop/beis-hamikdash" \
    "$HOME/Desktop/entityx" \
    "$HOME/.openclaw"; do
    if [ -d "$repo/.git" ]; then
        REPO_NAME=$(basename "$repo")
        RECENT=$(cd "$repo" && git log --oneline --since="3 days ago" -5 2>/dev/null)
        if [ -n "$RECENT" ]; then
            echo "### $REPO_NAME" >> "$OUTPUT"
            echo '```' >> "$OUTPUT"
            echo "$RECENT" >> "$OUTPUT"
            echo '```' >> "$OUTPUT"
        fi
    fi
done
echo "" >> "$OUTPUT"

# Pending handoffs for Codex
echo "## Pending Handoffs for Codex" >> "$OUTPUT"
CODEX_HANDOFFS=$(grep -rl "codex" "$SHARED/handoffs/" 2>/dev/null | while read f; do
    if grep -q "pending" "$f" 2>/dev/null; then
        echo "- $(basename "$f")"
    fi
done)
if [ -n "$CODEX_HANDOFFS" ]; then
    echo "$CODEX_HANDOFFS" >> "$OUTPUT"
else
    echo "None pending." >> "$OUTPUT"
fi
echo "" >> "$OUTPUT"

# Recent corrections for Codex
echo "## Recent Corrections" >> "$OUTPUT"
if [ -f "$SHARED/corrections/codex.md" ]; then
    CORRECTIONS=$(tail -10 "$SHARED/corrections/codex.md" 2>/dev/null)
    if [ -n "$CORRECTIONS" ]; then
        echo "$CORRECTIONS" >> "$OUTPUT"
    else
        echo "No corrections logged yet." >> "$OUTPUT"
    fi
else
    echo "No corrections file found." >> "$OUTPUT"
fi
echo "" >> "$OUTPUT"

# Architecture decisions (last 7 days)
echo "## Recent Architecture Decisions" >> "$OUTPUT"
if [ -f "$SHARED/DECISION-LOG.md" ]; then
    # Get recent entries (last 20 lines that look like decisions)
    grep -E "^\[2026-03-2" "$SHARED/DECISION-LOG.md" | tail -10 >> "$OUTPUT" 2>/dev/null || echo "None recent." >> "$OUTPUT"
else
    echo "No decision log found." >> "$OUTPUT"
fi
echo "" >> "$OUTPUT"

# What other systems are working on (avoid conflicts)
echo "## Other Systems — Currently Working On" >> "$OUTPUT"
if [ -f "$SHARED/CONTEXT.md" ]; then
    sed -n '/## Currently Working On/,/## Active Projects/p' "$SHARED/CONTEXT.md" | grep -v "^##" | grep -v "^<!--" | grep -v "^$" | head -10 >> "$OUTPUT" 2>/dev/null
fi
echo "" >> "$OUTPUT"

# Routing reminder
cat >> "$OUTPUT" << 'EOF'
## Routing Reminder

Before starting any task, read `shared/ROUTING.md` and confirm this is Codex work:
- Component builds, feature branches, test suites, parallel code generation: YES
- Deployment, monitoring, email, Slack: create a handoff to the right system
- Interactive debugging with Meir: handoff to Claude Code

---
*Under 100 lines. For full context: CONTEXT.md. For routing: ROUTING.md.*
EOF

echo "Generated CODEX-BRIEFING.md at $NOW"
