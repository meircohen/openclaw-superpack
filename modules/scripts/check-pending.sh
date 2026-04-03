#!/bin/bash

# Check pending items conditions
# Usage: check-pending.sh [condition]
# Returns: exit 0 if condition met, exit 1 if not

CONDITION="$1"
PENDING_FILE="pending_items.md"

case "$CONDITION" in
  "pending_items contains 'tax deadline'")
    if [[ -f "$PENDING_FILE" ]]; then
      grep -i "tax deadline" "$PENDING_FILE" >/dev/null && exit 0 || exit 1
    else
      exit 1
    fi
    ;;
  "pending_items contains 'Pesach' OR 'Orlando'")
    if [[ -f "$PENDING_FILE" ]]; then
      if grep -i -E "(pesach|orlando)" "$PENDING_FILE" >/dev/null; then
        exit 0
      else
        exit 1
      fi
    else
      exit 1
    fi
    ;;
  *)
    echo "Unknown pending items condition: $CONDITION" >&2
    exit 1
    ;;
esac