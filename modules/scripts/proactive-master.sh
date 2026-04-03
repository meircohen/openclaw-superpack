#!/bin/bash

# Master Proactive Trigger Script
# Runs proactive-check.sh and sends messages to agents when triggers fire
# Usage: bash scripts/agent-router/proactive-master.sh

SCRIPT_DIR="$(dirname "$0")"
RESULT=$(bash "$SCRIPT_DIR/proactive-check.sh")

# Parse the JSON result
FIRES_COUNT=$(echo "$RESULT" | grep -o '"fires":\s*\[' | wc -l | tr -d ' ')

if [[ "$FIRES_COUNT" -eq 0 ]]; then
  echo "No proactive triggers fired at $(date)"
  exit 0
fi

echo "=== Proactive Triggers Fired at $(date) ==="
echo "$RESULT"

# Extract fired triggers and format messages
echo "$RESULT" | grep -o '"id":\s*"[^"]*"' | while read -r line; do
  TRIGGER_ID=$(echo "$line" | grep -o '"[^"]*"$' | tr -d '"')
  
  # Get corresponding agent and action from the result
  AGENT=$(echo "$RESULT" | grep -A 3 "\"id\": \"$TRIGGER_ID\"" | grep '"agent"' | grep -o '"[^"]*"$' | tr -d '"')
  ACTION=$(echo "$RESULT" | grep -A 3 "\"id\": \"$TRIGGER_ID\"" | grep '"action"' | cut -d'"' -f4)
  REASON=$(echo "$RESULT" | grep -A 3 "\"id\": \"$TRIGGER_ID\"" | grep '"reason"' | cut -d'"' -f4)
  
  if [[ -n "$AGENT" && -n "$ACTION" ]]; then
    echo "🔔 [$AGENT] — $REASON"
    echo "$ACTION"
    echo ""
    
    # TODO: Here you could integrate with OpenClaw's agent messaging system
    # For example: openclaw agent send "$AGENT" "$ACTION"
    # Or post to a specific channel/session
  fi
done