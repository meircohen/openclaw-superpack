#!/bin/bash
# Watch shared/handoffs/ and shared/escalations/ for new files
# Sends a wake event to OpenClaw gateway when changes detected
# Run as background daemon: nohup bash handoff-watcher.sh &

set -euo pipefail

WATCH_DIRS=(
    "$HOME/.openclaw/workspace/shared/handoffs"
    "$HOME/.openclaw/workspace/shared/escalations"
)

LOG="$HOME/.openclaw/workspace/logs/handoff-watcher.log"
mkdir -p "$(dirname "$LOG")"

echo "[$(date '+%Y-%m-%d %H:%M:%S')] Handoff watcher started" >> "$LOG"

fswatch -r --event Created --event Updated "${WATCH_DIRS[@]}" | while read -r file; do
    # Skip hidden files and non-markdown
    [[ "$(basename "$file")" == .* ]] && continue
    [[ "$file" != *.md ]] && continue
    
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] Detected: $file" >> "$LOG"
    
    # Determine if escalation or handoff
    if [[ "$file" == *escalations* ]]; then
        echo "[$(date '+%Y-%m-%d %H:%M:%S')] ESCALATION detected — triggering immediate wake" >> "$LOG"
    else
        echo "[$(date '+%Y-%m-%d %H:%M:%S')] HANDOFF detected — triggering wake" >> "$LOG"
    fi
    
    # Wake the OpenClaw gateway
    # This triggers an immediate heartbeat-like check instead of waiting for the next 30-min cycle
    curl -s -X POST http://localhost:3284/api/wake \
        -H "Content-Type: application/json" \
        -d "{\"reason\": \"handoff-watcher: $(basename "$file")\"}" >> "$LOG" 2>&1 || true
    
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] Wake sent" >> "$LOG"
done
