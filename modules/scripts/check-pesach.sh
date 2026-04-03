#!/bin/bash

# Check Pesach-related conditions  
# Usage: check-pesach.sh [condition]
# Returns: exit 0 if condition met, exit 1 if not

CONDITION="$1"

case "$CONDITION" in
  "days_until_pesach <= 30 AND has_unbooked_items")
    # Pesach 2026 starts April 12, 2026
    PESACH_DATE="2026-04-12"
    TODAY=$(date +%Y-%m-%d)
    
    # Calculate days until Pesach
    if command -v gdate >/dev/null; then
      # macOS with GNU coreutils
      DAYS_UNTIL=$(( ($(gdate -d "$PESACH_DATE" +%s) - $(gdate -d "$TODAY" +%s)) / 86400 ))
    else
      # Try standard date (limited functionality)
      PESACH_EPOCH=$(date -j -f "%Y-%m-%d" "$PESACH_DATE" +%s 2>/dev/null || echo 0)
      TODAY_EPOCH=$(date -j -f "%Y-%m-%d" "$TODAY" +%s 2>/dev/null || echo 0)
      if [[ $PESACH_EPOCH -gt 0 && $TODAY_EPOCH -gt 0 ]]; then
        DAYS_UNTIL=$(( (PESACH_EPOCH - TODAY_EPOCH) / 86400 ))
      else
        # Fallback: manual calculation for 2026
        echo "Warning: Date calculation failed, using manual estimate" >&2
        DAYS_UNTIL=365  # Placeholder
      fi
    fi
    
    # Check if within 30 days and has unbooked items
    if [[ "$DAYS_UNTIL" -le 30 && "$DAYS_UNTIL" -ge 0 ]]; then
      # Check for unbooked Pesach items in pending
      if bash scripts/agent-router/conditions/check-pending.sh "pending_items contains 'Pesach' OR 'Orlando'"; then
        exit 0
      fi
    fi
    exit 1
    ;;
  "days_until <= 3")
    # Generic days until check (for tax deadlines, etc.)
    # This would need context about what deadline we're checking
    echo "Generic days_until check not implemented without specific deadline" >&2
    exit 1
    ;;
  *)
    echo "Unknown Pesach condition: $CONDITION" >&2
    exit 1
    ;;
esac