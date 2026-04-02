#!/bin/bash
# Weekly Update Check — Notify about available updates, don't auto-apply
# Runs Sunday 10am, includes in morning digest

set -euo pipefail

WORKSPACE="$HOME/.openclaw/workspace"
UPDATE_MANAGER="$WORKSPACE/scripts/update-manager.sh"

# Check if update manager exists
if [[ ! -x "$UPDATE_MANAGER" ]]; then
    echo "❌ Update manager not found or not executable"
    exit 1
fi

# Run update check
REPORT=$("$UPDATE_MANAGER" check 2>&1)

# Parse report
UPDATE_COUNT=$(echo "$REPORT" | grep -oE '[0-9]+ updates available' | grep -oE '[0-9]+' || echo "0")

if [[ "$UPDATE_COUNT" -eq 0 ]]; then
    # All up to date, silent success
    exit 0
fi

# Updates available — format for digest
echo "📦 Software Updates Available ($UPDATE_COUNT)"
echo ""
echo "$REPORT"
echo ""
echo "To review: update-manager.sh check"
echo "To apply: update-manager.sh apply --all"
echo "Creates backup first, health check after."
