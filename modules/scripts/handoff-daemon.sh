#!/bin/bash
# handoff-daemon.sh — Autonomous handoff processor
# Routes tasks to Claude Code CLI or Codex CLI based on task type
# Both run on subscriptions = zero extra cost
#
# Usage: bash scripts/handoff-daemon.sh start|stop|status|test
#
# Routing:
#   To: Claude Code  -> claude -p (Anthropic subscription)
#   To: Codex        -> codex exec --full-auto (OpenAI subscription)
#   To: Cowork       -> claude -p (same CLI, different prompt context)
#   Default          -> claude -p

set -uo pipefail

SHARED="$HOME/.openclaw/workspace/shared"
HANDOFFS="$SHARED/handoffs"
MCP_REQUESTS="$SHARED/mcp-proxy/requests"
REPLIES="$SHARED/replies"
MCP_RESPONSES="$SHARED/mcp-proxy/responses"
LOGS="$HOME/.openclaw/workspace/logs"
PID_FILE="$LOGS/handoff-daemon.pid"
LOG_FILE="$LOGS/handoff-daemon.log"

mkdir -p "$LOGS" "$REPLIES" "$MCP_RESPONSES"

log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1" >> "$LOG_FILE"
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1"
}

detect_backend() {
    local file="$1"
    local to_line=$(grep "^To:" "$file" 2>/dev/null | head -1)
    
    # Route based on "To:" field
    if echo "$to_line" | grep -qi "codex"; then
        echo "codex"
    elif echo "$to_line" | grep -qi "claude code\|claude-code"; then
        echo "claude"
    elif echo "$to_line" | grep -qi "cowork"; then
        echo "claude"
    else
        # Smart routing: code tasks -> codex, everything else -> claude
        local content=$(cat "$file")
        if echo "$content" | grep -qiE "refactor|debug|build|deploy|test|code review|write code|fix bug|PR|pull request|commit|git"; then
            echo "codex"
        else
            echo "claude"
        fi
    fi
}

run_claude() {
    local prompt="$1"
    local log_file="$2"
    
    echo "$prompt" | claude -p \
        --no-session-persistence \
        --dangerously-skip-permissions \
        --allowedTools "Bash,Read,Write,Edit" \
        --max-budget-usd 0.50 \
        >> "$log_file" 2>&1
    return $?
}

run_codex() {
    local prompt="$1"
    local log_file="$2"
    
    codex exec \
        --full-auto \
        --ephemeral \
        -c 'sandbox_permissions=["disk-full-read-access","full-disk-write-access"]' \
        "$prompt" \
        >> "$log_file" 2>&1
    return $?
}

process_handoff() {
    local file="$1"
    local basename=$(basename "$file")
    
    # Skip non-pending handoffs
    if ! grep -q "^Status: pending" "$file" 2>/dev/null; then
        return 0
    fi
    
    # Skip handoffs addressed to OpenClaw (those are for us, not the daemon)
    local to_line=$(grep "^To:" "$file" 2>/dev/null)
    if echo "$to_line" | grep -qi "openclaw"; then
        return 0
    fi
    
    local backend=$(detect_backend "$file")
    log "HANDOFF DETECTED: $basename -> routing to $backend"
    
    local content=$(cat "$file")
    local reply_file="$REPLIES/$(echo "$basename" | sed 's/.md$/-reply.md/')"
    
    local prompt="You are processing a handoff request from OpenClaw's autonomous pipeline.

HANDOFF FILE: $file

CONTENT:
$content

INSTRUCTIONS:
1. Fulfill the task described in the handoff
2. Write your response to: $reply_file
3. Use this exact format in the reply file:

# Reply: [task title]

From: $backend (daemon)
To: OpenClaw  
Original Handoff: $basename
Completed: $(date '+%Y-%m-%d %H:%M')
Status: fulfilled

## Result

[Your actual response here]

4. After writing the reply, update the original handoff file: change 'Status: pending' to 'Status: complete'
5. Be concise and direct"

    local call_log="$LOGS/daemon-call-$(date '+%Y%m%d-%H%M%S').log"
    
    if [ "$backend" = "codex" ]; then
        run_codex "$prompt" "$call_log"
    else
        run_claude "$prompt" "$call_log"
    fi
    
    local exit_code=$?
    
    if [ $exit_code -eq 0 ] && [ -f "$reply_file" ]; then
        log "SUCCESS [$backend]: Reply written to $reply_file"
    elif [ $exit_code -eq 0 ]; then
        log "WARNING [$backend]: Exited OK but no reply file at $reply_file"
    else
        log "ERROR [$backend]: Exit code $exit_code for $basename (see $call_log)"
    fi
}

process_mcp_request() {
    local file="$1"
    local basename=$(basename "$file")
    
    log "MCP PROXY REQUEST: $basename"
    
    local content=$(cat "$file")
    local response_file="$MCP_RESPONSES/$basename"
    
    local prompt="You are fulfilling an MCP proxy lookup request. READ-ONLY lookup only.

REQUEST FILE: $file

CONTENT:
$content

Write a concise response (under 500 chars) to: $response_file

Format:
# MCP Proxy Response
Request: $basename
Fulfilled: $(date '+%Y-%m-%d %H:%M')
By: daemon

## Answer
[concise answer]"

    local call_log="$LOGS/daemon-mcp-$(date '+%Y%m%d-%H%M%S').log"
    
    # MCP requests go to claude (better at quick lookups)
    run_claude "$prompt" "$call_log"
    
    if [ -f "$response_file" ]; then
        log "SUCCESS: MCP response -> $response_file"
    else
        log "WARNING: No MCP response created for $basename"
    fi
}

watch_loop() {
    log "Daemon v2 started. Backends: claude (Anthropic sub) + codex (OpenAI sub)"
    log "Watching: $HANDOFFS and $MCP_REQUESTS"
    
    fswatch -0 --event Created --event Updated "$HANDOFFS" "$MCP_REQUESTS" | while IFS= read -r -d '' file; do
        [[ "$file" != *.md ]] && continue
        [[ "$(basename "$file")" == .* ]] && continue
        
        # Let file finish writing
        sleep 2
        
        if [[ "$file" == *handoffs* ]]; then
            process_handoff "$file" &
        elif [[ "$file" == *mcp-proxy/requests* ]]; then
            process_mcp_request "$file" &
        fi
    done
}

case "${1:-}" in
    start)
        if [ -f "$PID_FILE" ] && kill -0 "$(cat "$PID_FILE")" 2>/dev/null; then
            echo "Daemon already running (PID: $(cat "$PID_FILE"))"
            exit 0
        fi
        
        log "Starting handoff daemon v2..."
        watch_loop &
        DAEMON_PID=$!
        echo $DAEMON_PID > "$PID_FILE"
        log "Daemon running with PID: $DAEMON_PID"
        echo "Handoff daemon v2 started (PID: $DAEMON_PID)"
        echo "Backends: claude -p (Anthropic) + codex exec (OpenAI)"
        echo "Log: $LOG_FILE"
        ;;
    
    stop)
        if [ -f "$PID_FILE" ]; then
            PID=$(cat "$PID_FILE")
            if kill -0 "$PID" 2>/dev/null; then
                kill "$PID" 2>/dev/null
                pkill -P "$PID" 2>/dev/null
                rm "$PID_FILE"
                log "Daemon stopped (PID: $PID)"
                echo "Daemon stopped"
            else
                rm "$PID_FILE"
                echo "Stale PID removed. Daemon was not running."
            fi
        else
            echo "Daemon not running"
        fi
        ;;
    
    status)
        if [ -f "$PID_FILE" ] && kill -0 "$(cat "$PID_FILE")" 2>/dev/null; then
            echo "Daemon v2 running (PID: $(cat "$PID_FILE"))"
            echo "Backends: claude (Anthropic) + codex (OpenAI)"
            echo ""
            echo "Last 10 log entries:"
            tail -10 "$LOG_FILE" 2>/dev/null
        else
            echo "Daemon not running"
        fi
        ;;
    
    test)
        log "Running one-shot scan..."
        for f in "$HANDOFFS"/*.md; do
            [ -f "$f" ] || continue
            [[ "$(basename "$f")" == .* ]] && continue
            process_handoff "$f"
        done
        for f in "$MCP_REQUESTS"/*.md; do
            [ -f "$f" ] || continue
            [[ "$(basename "$f")" == .* ]] && continue
            process_mcp_request "$f"
        done
        log "One-shot scan complete"
        ;;
    
    *)
        echo "Usage: $0 {start|stop|status|test}"
        echo ""
        echo "Routing:"
        echo "  To: Claude Code  -> claude -p (Anthropic subscription)"
        echo "  To: Codex        -> codex exec (OpenAI subscription)"
        echo "  Code keywords    -> codex (auto-detected)"
        echo "  Everything else  -> claude"
        exit 1
        ;;
esac
