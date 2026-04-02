#!/bin/bash
# AI Insights Processor — Extract patterns from weekly synthesis data
# Usage: knowledge-synthesis-ai-extract.sh <weekly-insights-file>

set -euo pipefail

INSIGHTS_FILE="$1"

if [[ ! -f "$INSIGHTS_FILE" ]]; then
    echo "❌ File not found: $INSIGHTS_FILE"
    exit 1
fi

echo "🧠 Processing weekly insights..."
echo ""

# Prepare AI prompt
AI_PROMPT=$(cat <<EOF
You are analyzing weekly synthesis data to extract actionable insights.

DATA:
$(cat "$INSIGHTS_FILE")

EXTRACT:

## Top 3 Insights
For each insight, provide:
1. **Pattern**: What emerged from the data
2. **Evidence**: Specific data points supporting it
3. **Action**: Concrete next step

Format as markdown with clear sections.

GUIDELINES:
- Focus on actionable patterns, not obvious facts
- Compare stated goals (active_guidance) vs actual behavior (meetings, time spent)
- Flag any gaps between intention and execution
- Highlight relationships deepening (recurring participants)
- Note any commitment tracking issues (promises made but not kept)
- Ignore common word noise (with, from, status) — look for meaningful themes

Be direct and specific. No fluff.
EOF
)

# Call OpenClaw AI
EXTRACTION=$(echo "$AI_PROMPT" | openclaw run --model sonnet-4 --prompt "$(cat)" 2>&1)

echo "$EXTRACTION"
echo ""

# Save to memory blocks (append to session_patterns)
TIMESTAMP=$(date +"%Y-%m-%d")
MEMORY_BLOCK="$HOME/.openclaw/workspace/memory/blocks/session_patterns.md"

if [[ -f "$MEMORY_BLOCK" ]]; then
    echo "" >> "$MEMORY_BLOCK"
    echo "## Weekly Insights ($TIMESTAMP)" >> "$MEMORY_BLOCK"
    echo "" >> "$MEMORY_BLOCK"
    echo "$EXTRACTION" >> "$MEMORY_BLOCK"
    echo "" >> "$MEMORY_BLOCK"
    
    echo "✅ Insights appended to memory/blocks/session_patterns.md"
fi
