#!/bin/bash
# Create an Apple Reminder
# Usage: bash scripts/apple-remind.sh "Buy milk" "Groceries"
TITLE="$1"
LIST="${2:-Reminders}"

osascript -e "
tell application \"Reminders\"
    tell list \"$LIST\"
        make new reminder with properties {name:\"$TITLE\"}
    end tell
end tell
" 2>/dev/null && echo "Reminder created: $TITLE" || echo "Failed to create reminder"
