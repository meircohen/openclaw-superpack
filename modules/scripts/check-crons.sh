#!/bin/bash

# Check cron health conditions
# Usage: check-crons.sh [condition]
# Returns: exit 0 if condition met, exit 1 if not

CONDITION="$1"

case "$CONDITION" in
  "cron_errors > 2")
    # Check OpenClaw cron errors
    ERROR_COUNT=$(openclaw cron list 2>/dev/null | grep -i error | wc -l | tr -d ' ')
    
    if [[ -z "$ERROR_COUNT" ]]; then
      ERROR_COUNT=0
    fi
    
    if [[ "$ERROR_COUNT" -gt 2 ]]; then
      exit 0
    else
      exit 1
    fi
    ;;
  *)
    echo "Unknown cron condition: $CONDITION" >&2
    exit 1
    ;;
esac