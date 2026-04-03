#!/bin/bash

# Check time-based conditions
# Usage: check-time.sh [condition]
# Returns: exit 0 if condition met, exit 1 if not

CONDITION="$1"
CURRENT_HOUR=${CURRENT_HOUR:-$(date +"%H" | sed 's/^0//')}
CURRENT_DAY=${CURRENT_DAY:-$(date +"%A")}

case "$CONDITION" in
  "day_of_week == Wednesday")
    [[ "$CURRENT_DAY" == "Wednesday" ]] && exit 0 || exit 1
    ;;
  "day_of_week in Monday-Friday AND hour == 7")
    if [[ "$CURRENT_DAY" =~ ^(Monday|Tuesday|Wednesday|Thursday|Friday)$ ]] && [[ "$CURRENT_HOUR" == "7" ]]; then
      exit 0
    else
      exit 1
    fi
    ;;
  "current_hour >= 1 AND current_hour <= 5 AND user_active")
    # Check if it's late night hours (1-5 AM)
    if [[ "$CURRENT_HOUR" -ge 1 && "$CURRENT_HOUR" -le 5 ]]; then
      # Check if user is active (recent shell activity or processes)
      LAST_ACTIVITY=$(stat -f "%m" ~/.bash_history 2>/dev/null || echo 0)
      NOW=$(date +%s)
      DIFF=$((NOW - LAST_ACTIVITY))
      
      # Consider user active if shell history updated in last 10 minutes
      if [[ $DIFF -lt 600 ]]; then
        exit 0
      fi
    fi
    exit 1
    ;;
  *)
    echo "Unknown time condition: $CONDITION" >&2
    exit 1
    ;;
esac