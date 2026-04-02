#!/bin/bash
# smart-spawn.sh - Intelligent sub-agent spawning with automatic routing
# 
# Usage:
#   bash smart-spawn.sh "Build a CLI tool"
#   bash smart-spawn.sh "Fix bug in auth.js" --announce
#   bash smart-spawn.sh "Research BTC" --model sonnet-4
#
# This script:
# 1. Routes task through route-and-spawn-simple.js
# 2. Executes via chosen backend (Claude Code, Codex, or sessions_spawn)
# 3. Returns result

set -euo pipefail

WORKSPACE="${WORKSPACE:-$HOME/.openclaw/workspace}"
TASK="$1"
shift

# Parse additional options
ANNOUNCE=""
FORCE_MODEL=""
TIMEOUT=""

while [[ $# -gt 0 ]]; do
    case $1 in
        --announce)
            ANNOUNCE="--announce"
            shift
            ;;
        --model)
            FORCE_MODEL="$2"
            shift 2
            ;;
        --timeout)
            TIMEOUT="$2"
            shift 2
            ;;
        *)
            shift
            ;;
    esac
done

# If model forced, skip router and go straight to sessions_spawn
if [[ -n "$FORCE_MODEL" ]]; then
    echo "[SMART-SPAWN] Model forced: $FORCE_MODEL (skipping router)"
    
    # Build openclaw command
    CMD="openclaw agent send main \"Spawn sub-agent for: $TASK\" --model \"$FORCE_MODEL\""
    [[ -n "$ANNOUNCE" ]] && CMD="$CMD --announce"
    [[ -n "$TIMEOUT" ]] && CMD="$CMD --timeout $TIMEOUT"
    
    eval "$CMD"
    exit $?
fi

# Route the task
echo "[SMART-SPAWN] Routing task: $TASK"
DECISION=$(node "$WORKSPACE/scripts/route-and-spawn-simple.js" "$TASK")

ACTION=$(echo "$DECISION" | jq -r '.action')
BACKEND=$(echo "$DECISION" | jq -r '.backend // empty')
MODEL=$(echo "$DECISION" | jq -r '.model // empty')
REASON=$(echo "$DECISION" | jq -r '.reason')

echo "[SMART-SPAWN] Decision: $ACTION → $BACKEND ($REASON)"

# Execute based on decision
case "$ACTION" in
    spawn)
        case "$BACKEND" in
            claude-code)
                echo "[SMART-SPAWN] Executing via Claude Code CLI..."
                # Check if Claude Code is logged in
                if ! claude --version &>/dev/null; then
                    echo "[SMART-SPAWN] ⚠️  Claude Code CLI not available, falling back to API"
                    BACKEND="api"
                    MODEL="anthropic/claude-sonnet-4-20250514"
                else
                    # Create temp file for task
                    TASK_FILE=$(mktemp -t claude-task.XXXXXX.md)
                    echo "# Task" > "$TASK_FILE"
                    echo "" >> "$TASK_FILE"
                    echo "$TASK" >> "$TASK_FILE"
                    
                    # Run Claude Code (interactive, so this blocks)
                    claude "$TASK_FILE"
                    EXIT_CODE=$?
                    
                    rm -f "$TASK_FILE"
                    exit $EXIT_CODE
                fi
                ;;
                
            codex)
                echo "[SMART-SPAWN] Executing via Codex CLI..."
                # Check if Codex is available
                if ! codex-cli --version &>/dev/null; then
                    echo "[SMART-SPAWN] ⚠️  Codex CLI not available, falling back to API"
                    BACKEND="api"
                    MODEL="anthropic/claude-sonnet-4-20250514"
                else
                    # Run Codex
                    codex-cli run "$TASK"
                    exit $?
                fi
                ;;
        esac
        
        # If we get here, either API was chosen or we fell back
        if [[ "$BACKEND" == "api" ]] || [[ -n "$MODEL" ]]; then
            echo "[SMART-SPAWN] Executing via sessions_spawn (model: $MODEL)..."
            
            # Build the spawn command via OpenClaw sessions tool
            # Note: This returns JSON that openclaw will parse
            cat <<EOF
{
    "tool": "sessions_spawn",
    "task": "$TASK",
    "model": "$MODEL",
    "mode": "run",
    "timeoutSeconds": ${TIMEOUT:-600}
}
EOF
            exit 0
        fi
        ;;
        
    self-handle)
        echo "[SMART-SPAWN] Router says: self-handle"
        echo "Reason: $REASON"
        echo ""
        echo "This task doesn't need a sub-agent. You can answer it directly."
        exit 0
        ;;
        
    *)
        echo "[SMART-SPAWN] ❌ Unknown action: $ACTION"
        exit 1
        ;;
esac
