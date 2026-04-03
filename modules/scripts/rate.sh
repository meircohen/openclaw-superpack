#!/bin/bash

# Rating Logger for Agent Router Feedback Loop
# Usage: bash rate.sh "agent-id" "task-description" "rating"
# Ratings: good, bad, partial

if [ $# -ne 3 ]; then
    echo "Usage: $0 <agent-id> <task-description> <rating>"
    echo "Ratings: good, bad, partial"
    exit 1
fi

AGENT_ID="$1"
TASK_DESC="$2"
RATING="$3"

# Validate rating
if [[ ! "$RATING" =~ ^(good|bad|partial)$ ]]; then
    echo "Error: Rating must be 'good', 'bad', or 'partial'"
    exit 1
fi

# Get script directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
RATINGS_FILE="$SCRIPT_DIR/ratings.jsonl"

# Generate timestamp in ISO 8601 format
TIMESTAMP=$(date -u +"%Y-%m-%dT%H:%M:%S")

# Create JSON entry
JSON_ENTRY=$(cat << EOF
{"timestamp": "$TIMESTAMP", "agent": "$AGENT_ID", "task": "$TASK_DESC", "rating": "$RATING"}
EOF
)

# Append to ratings file
echo "$JSON_ENTRY" >> "$RATINGS_FILE"

echo "Rating logged: $AGENT_ID -> $RATING"