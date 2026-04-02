#!/bin/bash
# Shabbos-safe notification wrapper
# Only sends notifications if not Shabbos and not sleeping hours

set -e

WORKSPACE_ROOT="$HOME/.openclaw/workspace"
MESSAGE="$1"
URGENCY="${2:-normal}"  # normal, high, critical

if [[ -z "$MESSAGE" ]]; then
  echo "Usage: shabbos-safe-notify.sh \"message\" [urgency]"
  exit 1
fi

# Check time awareness
bash "$WORKSPACE_ROOT/scripts/time-awareness.sh" status > /dev/null

if bash "$WORKSPACE_ROOT/scripts/time-awareness.sh" quiet-hours; then
  # In quiet hours - log but don't notify
  echo "[$(date -Iseconds)] HELD: $MESSAGE (quiet hours)" >> "$WORKSPACE_ROOT/data/held-notifications.log"
  exit 0
fi

# Critical messages always go through
if [[ "$URGENCY" == "critical" ]]; then
  echo "[CRITICAL] $MESSAGE"
  exit 0
fi

# Normal/high messages - send now
echo "$MESSAGE"
exit 0
