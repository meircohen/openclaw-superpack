#!/bin/bash
# sync-topic-context.sh
# Sync context between DM and topic sessions

set -euo pipefail

ACTION="${1:-pull}"  # pull or push
TOPIC_ID="${2:-}"

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SESSIONS_DIR="$HOME/.openclaw/agents/main/sessions"
DM_SESSION="fb0e857c-cd05-4655-a027-eaed927e39ef.jsonl"

# Find topic session file
if [[ -n "$TOPIC_ID" ]]; then
    TOPIC_SESSION=$(ls -t "$SESSIONS_DIR"/*-topic-${TOPIC_ID}.jsonl 2>/dev/null | head -1)
else
    echo "Usage: $0 <pull|push> <topic_id>"
    exit 1
fi

if [[ ! -f "$TOPIC_SESSION" ]]; then
    echo "No session found for topic $TOPIC_ID"
    exit 1
fi

case "$ACTION" in
    pull)
        # Pull recent topic messages into DM memory
        echo "Pulling context from topic $TOPIC_ID to DM..."
        
        # Get last 5 exchanges from topic
        TOPIC_SUMMARY=$(tail -50 "$TOPIC_SESSION" | \
            jq -r 'select(.type=="message") | 
                   "\(.message.role): \(.message.content[0].text // "")"' | \
            tail -10)
        
        # Append to DM memory as system note
        TIMESTAMP=$(date -u +"%Y-%m-%dT%H:%M:%SZ")
        MEMORY_NOTE="[Context from topic $TOPIC_ID at $TIMESTAMP]
$TOPIC_SUMMARY
[End context sync]"
        
        echo "$MEMORY_NOTE" >> "$SCRIPT_DIR/../memory/topic-context-sync.log"
        echo "✅ Synced topic context to memory log"
        ;;
        
    push)
        # Push recent DM context to topic session
        echo "Pushing DM context to topic $TOPIC_ID..."
        
        # Get last 5 DM exchanges
        DM_SUMMARY=$(tail -50 "$SESSIONS_DIR/$DM_SESSION" | \
            jq -r 'select(.type=="message") | 
                   "\(.message.role): \(.message.content[0].text // "")"' | \
            tail -10)
        
        # Write context to topic session as system message
        # (This would require modifying the session file, which is risky)
        # Instead, just log it for now
        echo "[DM context for topic $TOPIC_ID]
$DM_SUMMARY
[End DM context]" >> "$SCRIPT_DIR/../memory/topic-context-sync.log"
        
        echo "⚠️  Push to topic session not fully implemented (requires session file modification)"
        echo "✅ Logged DM context for reference"
        ;;
        
    *)
        echo "Invalid action: $ACTION (use 'pull' or 'push')"
        exit 1
        ;;
esac
