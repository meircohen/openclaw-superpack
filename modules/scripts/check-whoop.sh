#!/bin/bash

# Check WHOOP-related conditions
# Usage: check-whoop.sh [condition]
# Returns: exit 0 if condition met, exit 1 if not

CONDITION="$1"

case "$CONDITION" in
  "whoop_recovery < 50 for 3 consecutive days")
    # Check if scripts/whoop.sh exists
    if [[ ! -f "scripts/whoop.sh" ]]; then
      echo "WHOOP script not found, condition not met" >&2
      exit 1
    fi
    
    # Get recovery data for last 3 days
    RECOVERY_DATA=$(bash scripts/whoop.sh summary 2>/dev/null | grep -i "recovery" || echo "Recovery: N/A")
    
    # Extract recovery percentage (simple pattern matching)
    RECOVERY_PCT=$(echo "$RECOVERY_DATA" | grep -o '[0-9]\+%' | head -1 | tr -d '%')
    
    if [[ -z "$RECOVERY_PCT" ]]; then
      echo "Could not parse recovery data: $RECOVERY_DATA" >&2
      exit 1
    fi
    
    # For now, just check current recovery < 50
    # TODO: Implement 3-day consecutive check with historical data
    if [[ "$RECOVERY_PCT" -lt 50 ]]; then
      exit 0
    else
      exit 1
    fi
    ;;
  *)
    echo "Unknown WHOOP condition: $CONDITION" >&2
    exit 1
    ;;
esac