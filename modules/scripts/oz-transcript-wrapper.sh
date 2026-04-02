#!/bin/bash
# Oz Transcript Processor Wrapper - with file existence check

TODAY=$(date +%Y-%m-%d)
TRANSCRIPT_FILE="$HOME/.openclaw/workspace/oz-voice/transcripts/${TODAY}.jsonl"

# Exit if no transcript file exists
if [[ ! -f "$TRANSCRIPT_FILE" ]]; then
    echo "No transcript file for $TODAY, skipping"
    exit 0
fi

# File exists, run the actual processing
# (Original cron task would go here)
echo "Processing transcript file: $TRANSCRIPT_FILE"
