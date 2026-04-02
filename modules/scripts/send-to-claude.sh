#!/bin/bash
# Send a message to Claude Code/Cowork via the shared layer
# This creates an instant notification file that Claude reads
# Usage: bash send-to-claude.sh "Your WHOOP data: Recovery 35%, HRV 31ms"
# Usage: bash send-to-claude.sh --priority high "Deployment failed, need manual fix"

set -euo pipefail

SHARED="$HOME/.openclaw/workspace/shared"
INBOX="$SHARED/inbox"
mkdir -p "$INBOX"

PRIORITY="normal"
if [ "${1:-}" = "--priority" ]; then
    PRIORITY="$2"
    shift 2
fi

MESSAGE="${1:-}"
if [ -z "$MESSAGE" ]; then
    echo "Usage: send-to-claude.sh [--priority high|normal|low] \"message\""
    exit 1
fi

TIMESTAMP=$(date '+%Y-%m-%d-%H%M%S')
FILENAME="$INBOX/$TIMESTAMP-from-openclaw.md"

cat > "$FILENAME" << EOF
# Message from OpenClaw
**Time:** $(date '+%Y-%m-%d %I:%M:%S %p EDT')
**Priority:** $PRIORITY
**Status:** unread

## Message

$MESSAGE

---
*Delivered via OpenClaw session bridge. Mark as read by changing Status to "read".*
EOF

echo "Sent to $FILENAME"

# If high priority, also write to escalations
if [ "$PRIORITY" = "high" ]; then
    cp "$FILENAME" "$SHARED/escalations/P1-$TIMESTAMP-openclaw-message.md"
    echo "Also escalated to P1"
fi
