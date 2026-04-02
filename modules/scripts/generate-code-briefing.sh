#!/bin/bash
# Generate shared/CLAUDE-CODE-BRIEFING.md — coding-specific context
# Run on heartbeat to keep fresh for Claude Code sessions

set -uo pipefail

SHARED="$HOME/.openclaw/workspace/shared"
OUTPUT="$SHARED/CLAUDE-CODE-BRIEFING.md"
NOW=$(date '+%Y-%m-%d %I:%M %p EDT')

cat > "$OUTPUT" << EOF
# Claude Code Session Briefing
**Generated:** $NOW by OpenClaw (auto-refreshed every heartbeat)
**Purpose:** Coding-specific context. Read this ONE file before writing any code.

EOF

# Active code tasks from QUEUE.md
echo "## Active Code Tasks" >> "$OUTPUT"
if [ -f "$SHARED/QUEUE.md" ]; then
    # Get In Progress items
    IN_PROGRESS=$(sed -n '/## In Progress/,/## Queued/p' "$SHARED/QUEUE.md" | grep -v "^##" | grep -v "^<!--" | grep -v "^$" | head -10)
    if [ -n "$IN_PROGRESS" ]; then
        echo "$IN_PROGRESS" >> "$OUTPUT"
    else
        echo "None in progress" >> "$OUTPUT"
    fi
    echo "" >> "$OUTPUT"
    # Get Queued items that look code-related
    echo "### Queued (code-related)" >> "$OUTPUT"
    sed -n '/## Queued/,/## Blocked/p' "$SHARED/QUEUE.md" | grep -iE "(deploy|fix|build|test|refactor|code|pr |merge|bug|feature|api|worker|page)" | head -10 >> "$OUTPUT" 2>/dev/null || echo "None" >> "$OUTPUT"
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
            echo "\`\`\`" >> "$OUTPUT"
            echo "$RECENT" >> "$OUTPUT"
            echo "\`\`\`" >> "$OUTPUT"
        fi
    fi
done
# Check if we found anything
if ! grep -q "^###" "$OUTPUT" 2>/dev/null; then
    echo "No recent commits found in tracked repos" >> "$OUTPUT"
fi
echo "" >> "$OUTPUT"

# Open PRs (if gh cli available)
echo "## Open PRs" >> "$OUTPUT"
if command -v gh &>/dev/null; then
    for repo in \
        "$HOME/Desktop/icare-diagnostics" \
        "$HOME/Desktop/doss-ai"; do
        if [ -d "$repo/.git" ]; then
            REPO_NAME=$(basename "$repo")
            PRS=$(cd "$repo" && gh pr list --limit 5 2>/dev/null)
            if [ -n "$PRS" ]; then
                echo "### $REPO_NAME" >> "$OUTPUT"
                echo "$PRS" >> "$OUTPUT"
            fi
        fi
    done
fi
if ! grep -q "^###" <(tail -5 "$OUTPUT") 2>/dev/null; then
    echo "None found (or gh cli not configured for these repos)" >> "$OUTPUT"
fi
echo "" >> "$OUTPUT"

# Recent deploys (check wrangler logs)
echo "## Recent Deploys" >> "$OUTPUT"
WRANGLER_LOG=$(find /tmp -name "wrangler*.log" -mtime -3 2>/dev/null | head -1)
if [ -n "$WRANGLER_LOG" ]; then
    tail -10 "$WRANGLER_LOG" >> "$OUTPUT"
else
    # Check git for deploy-related commits
    for repo in "$HOME/.openclaw"; do
        if [ -d "$repo/.git" ]; then
            DEPLOYS=$(cd "$repo" && git log --oneline --since="3 days ago" --grep="deploy" -5 2>/dev/null)
            if [ -n "$DEPLOYS" ]; then
                echo "$DEPLOYS" >> "$OUTPUT"
            fi
        fi
    done
fi
echo "Check Cloudflare dashboard or wrangler CLI for latest deploy status" >> "$OUTPUT"
echo "" >> "$OUTPUT"

# Architecture decisions from DECISION-LOG.md
echo "## Relevant Architecture Decisions" >> "$OUTPUT"
if [ -f "$SHARED/DECISION-LOG.md" ]; then
    grep -E "^\- \[" "$SHARED/DECISION-LOG.md" | grep -iE "(code|deploy|stack|framework|api|database|worker|model|babylon|three)" | tail -5 >> "$OUTPUT" 2>/dev/null || echo "None code-specific" >> "$OUTPUT"
fi
echo "" >> "$OUTPUT"

# Blocked items needing code
echo "## Blocked Items Needing Code" >> "$OUTPUT"
if [ -f "$SHARED/QUEUE.md" ]; then
    sed -n '/## Blocked/,/## Done/p' "$SHARED/QUEUE.md" | grep -iE "(deploy|fix|build|test|bug|code|api|worker)" | head -5 >> "$OUTPUT" 2>/dev/null || echo "None" >> "$OUTPUT"
fi
echo "" >> "$OUTPUT"

# Pending MCP proxy requests
echo "## Pending MCP Proxy Requests" >> "$OUTPUT"
MCP_REQUESTS=$(find "$SHARED/mcp-proxy/requests" -name "*.md" -newer "$SHARED/mcp-proxy/requests/.gitkeep" 2>/dev/null | head -5)
if [ -n "$MCP_REQUESTS" ]; then
    for f in $MCP_REQUESTS; do
        echo "- $(head -1 "$f"): $(grep "^Query:" "$f" 2>/dev/null)" >> "$OUTPUT"
    done
else
    echo "None" >> "$OUTPUT"
fi
echo "" >> "$OUTPUT"

# Context from Cowork (last session summary)
echo "## Context from Cowork" >> "$OUTPUT"
if [ -f "$SHARED/CONTEXT.md" ]; then
    COWORK_STATE=$(sed -n '/### Claude Code \/ Cowork/,/^##/p' "$SHARED/CONTEXT.md" | head -10)
    if [ -n "$COWORK_STATE" ]; then
        echo "$COWORK_STATE" >> "$OUTPUT"
    else
        echo "No recent Cowork session summary" >> "$OUTPUT"
    fi
fi
echo "" >> "$OUTPUT"

echo "---" >> "$OUTPUT"
echo "*Under 100 lines. For full context: BRIEFING.md. For deep memory: MEMORY-SNAPSHOT.md*" >> "$OUTPUT"

LINES=$(wc -l < "$OUTPUT")
echo "[$(date '+%Y-%m-%d %H:%M:%S')] Code briefing generated: $LINES lines" >&2
