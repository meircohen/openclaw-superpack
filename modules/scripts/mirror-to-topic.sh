#!/bin/bash
# mirror-to-topic.sh
# Mirror a message to the appropriate Telegram topic

set -euo pipefail

MESSAGE="$1"
TOPIC_ID="${2:-}"

# Load topic config
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CONFIG_FILE="$SCRIPT_DIR/../config/integrations/telegram-topics.json"
GROUP_CHAT_ID=$(jq -r '.group_chat_id' "$CONFIG_FILE")

# If topic ID not provided, classify the message
if [[ -z "$TOPIC_ID" ]]; then
    CLASSIFICATION=$(node "$SCRIPT_DIR/telegram-topic-router.js" "$MESSAGE")
    TOPIC_NAME=$(echo "$CLASSIFICATION" | grep "Topic:" | sed 's/.*(\(.*\))/\1/')
    TOPIC_ID=$(jq -r ".topics.${TOPIC_NAME}.thread_id" "$CONFIG_FILE")
fi

# Send to topic
openclaw message send \
    --channel telegram \
    --target "$GROUP_CHAT_ID" \
    --thread-id "$TOPIC_ID" \
    --message "$MESSAGE" \
    >/dev/null 2>&1

echo "✅ Mirrored to topic $TOPIC_ID"
