#!/bin/bash
# GitHub Issue Bot - Auto-spawn agents for issues
# Usage: github-issue-bot.sh <owner/repo> [--label bug] [--limit 5]

set -euo pipefail

WORKSPACE="$HOME/.openclaw/workspace"

# Parse arguments
REPO="$1"
shift

LABEL_FILTER=""
LIMIT=5
DRY_RUN=false

while [[ $# -gt 0 ]]; do
    case $1 in
        --label)
            LABEL_FILTER="$2"
            shift 2
            ;;
        --limit)
            LIMIT="$2"
            shift 2
            ;;
        --dry-run)
            DRY_RUN=true
            shift
            ;;
        *)
            echo "Unknown option: $1"
            exit 1
            ;;
    esac
done

echo "🔍 Scanning $REPO for issues..."
if [ -n "$LABEL_FILTER" ]; then
    echo "   Filter: label=$LABEL_FILTER"
fi
echo "   Limit: $LIMIT issues"
echo ""

# Fetch open issues
if [ -n "$LABEL_FILTER" ]; then
    ISSUES=$(gh issue list --repo "$REPO" --label "$LABEL_FILTER" --limit "$LIMIT" --json number,title,body,url)
else
    ISSUES=$(gh issue list --repo "$REPO" --limit "$LIMIT" --json number,title,body,url)
fi

ISSUE_COUNT=$(echo "$ISSUES" | jq 'length')

if [ "$ISSUE_COUNT" -eq 0 ]; then
    echo "✅ No open issues found"
    exit 0
fi

echo "📋 Found $ISSUE_COUNT issue(s)"
echo ""

# Process each issue
echo "$ISSUES" | jq -c '.[]' | while read -r issue; do
    NUMBER=$(echo "$issue" | jq -r '.number')
    TITLE=$(echo "$issue" | jq -r '.title')
    BODY=$(echo "$issue" | jq -r '.body // ""')
    URL=$(echo "$issue" | jq -r '.url')
    
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo "Issue #$NUMBER: $TITLE"
    echo "URL: $URL"
    echo ""
    
    if [ "$DRY_RUN" = true ]; then
        echo "   [DRY RUN] Would spawn agent for this issue"
        continue
    fi
    
    # Create task for sub-agent
    TASK="Fix GitHub issue #$NUMBER in $REPO:

Title: $TITLE

Description:
$BODY

Repository: $REPO
Issue URL: $URL

Instructions:
1. Read the issue description carefully
2. Clone the repository and investigate the problem
3. Implement a fix
4. Test the fix thoroughly
5. Create a pull request with clear description
6. Link PR to issue #$NUMBER

Report back with PR URL when complete."
    
    # Spawn sub-agent (fire-and-forget)
    echo "   🚀 Spawning sub-agent..."
    
    SUB_AGENT_RESULT=$(openclaw sessions spawn \
        --runtime subagent \
        --task "$TASK" \
        --label "github-issue-$NUMBER" \
        --model "anthropic/claude-sonnet-4-5" \
        --timeout 3600 \
        2>&1)
    
    if [ $? -eq 0 ]; then
        SESSION_KEY=$(echo "$SUB_AGENT_RESULT" | grep "sessionKey" | awk '{print $2}' || echo "unknown")
        echo "   ✅ Agent spawned: $SESSION_KEY"
        
        # Add comment to issue
        gh issue comment "$NUMBER" --repo "$REPO" --body "🤖 AI agent spawned to investigate and fix this issue.

Session: \`$SESSION_KEY\`

I'll report back with a PR when ready." || echo "   ⚠️ Could not comment on issue"
    else
        echo "   ❌ Failed to spawn agent"
        echo "   Error: $SUB_AGENT_RESULT"
    fi
    
    echo ""
    
    # Rate limit: wait 2 seconds between spawns
    sleep 2
done

echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "✅ GitHub issue bot complete"
echo ""
echo "📊 Summary:"
echo "   Issues found: $ISSUE_COUNT"
echo "   Agents spawned: $ISSUE_COUNT"
