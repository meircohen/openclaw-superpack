#!/bin/bash
# log-event.sh — Append a structured log entry to the unified log
# Usage: ./log-event.sh <agent> <category> <action> <result> [details]
# Example: ./log-event.sh oz cron morning-briefing success "Delivered 3 items"

AGENT="${1:?Usage: log-event.sh <agent> <category> <action> <result> [details]}"
CATEGORY="${2:?Missing category}"
ACTION="${3:?Missing action}"
RESULT="${4:?Missing result}"
DETAILS="${5:-}"

LOG_DIR="$HOME/.openclaw/workspace/logs"
mkdir -p "$LOG_DIR"

DATE=$(date +%Y-%m-%d)
TS=$(date -u +%Y-%m-%dT%H:%M:%SZ)
HOST=$(hostname -s 2>/dev/null || echo "unknown")

# Determine host type
if [ "$HOST" = "guardian" ]; then
  HOST_TYPE="gcp"
else
  HOST_TYPE="imac"
fi

# Write JSONL entry
echo "{\"ts\":\"$TS\",\"agent\":\"$AGENT\",\"host\":\"$HOST_TYPE\",\"category\":\"$CATEGORY\",\"action\":\"$ACTION\",\"result\":\"$RESULT\",\"details\":\"$DETAILS\"}" >> "$LOG_DIR/$AGENT-$DATE.jsonl"
