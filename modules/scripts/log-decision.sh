#!/bin/bash
# Log a routing decision
# Usage: bash log-decision.sh '{"message": "...", "routed_to": "agent-id", "confidence": 0.85}'

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LOG_FILE="$SCRIPT_DIR/routing-log.jsonl"

# Check if JSON input provided
if [ $# -eq 0 ]; then
    echo "Error: No JSON input provided"
    echo "Usage: $0 '{\"message\": \"...\", \"routed_to\": \"agent-id\", \"confidence\": 0.85}'"
    exit 1
fi

JSON_INPUT="$1"

# Validate JSON structure
if ! echo "$JSON_INPUT" | jq -e '.message and .routed_to and .confidence' >/dev/null 2>&1; then
    echo "Error: JSON must contain 'message', 'routed_to', and 'confidence' fields"
    exit 1
fi

# Add timestamp and context signals
TIMESTAMP=$(date -u +"%Y-%m-%dT%H:%M:%SZ")
MESSAGE=$(echo "$JSON_INPUT" | jq -r '.message')
ROUTED_TO=$(echo "$JSON_INPUT" | jq -r '.routed_to')
CONFIDENCE=$(echo "$JSON_INPUT" | jq -r '.confidence')

# Extract context signals from message
WORD_COUNT=$(echo "$MESSAGE" | wc -w | tr -d ' ')
HAS_QUESTION=$(if echo "$MESSAGE" | grep -q '?'; then echo "true"; else echo "false"; fi)
HAS_URGENT=$(if echo "$MESSAGE" | grep -iq 'urgent\|asap\|immediately'; then echo "true"; else echo "false"; fi)
MESSAGE_LENGTH=${#MESSAGE}

# Create log entry
LOG_ENTRY=$(jq -nc \
    --arg timestamp "$TIMESTAMP" \
    --arg message "$MESSAGE" \
    --arg routed_to "$ROUTED_TO" \
    --argjson confidence "$CONFIDENCE" \
    --argjson word_count "$WORD_COUNT" \
    --argjson has_question "$HAS_QUESTION" \
    --argjson has_urgent "$HAS_URGENT" \
    --argjson message_length "$MESSAGE_LENGTH" \
    '{
        timestamp: $timestamp,
        message: $message,
        routed_to: $routed_to,
        confidence: $confidence,
        context_signals: {
            word_count: $word_count,
            has_question: $has_question,
            has_urgent: $has_urgent,
            message_length: $message_length
        },
        outcome: null,
        outcome_timestamp: null
    }')

# Append to log file (ensure we're on a new line)
echo "" >> "$LOG_FILE"
echo "$LOG_ENTRY" >> "$LOG_FILE"

echo "Logged routing decision: $ROUTED_TO (confidence: $CONFIDENCE)"