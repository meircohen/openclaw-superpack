#!/bin/bash
# Log an outcome for a routing decision
# Usage: bash log-outcome.sh '{"message": "...", "routed_to": "agent-id", "outcome": "success|bounce|partial"}'

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LOG_FILE="$SCRIPT_DIR/routing-log.jsonl"

# Check if JSON input provided
if [ $# -eq 0 ]; then
    echo "Error: No JSON input provided"
    echo "Usage: $0 '{\"message\": \"...\", \"routed_to\": \"agent-id\", \"outcome\": \"success\"}'"
    exit 1
fi

JSON_INPUT="$1"

# Validate JSON structure
if ! echo "$JSON_INPUT" | jq -e '.message and .routed_to and .outcome' >/dev/null 2>&1; then
    echo "Error: JSON must contain 'message', 'routed_to', and 'outcome' fields"
    exit 1
fi

# Validate outcome value
OUTCOME=$(echo "$JSON_INPUT" | jq -r '.outcome')
if [[ ! "$OUTCOME" =~ ^(success|bounce|partial)$ ]]; then
    echo "Error: outcome must be one of: success, bounce, partial"
    exit 1
fi

MESSAGE=$(echo "$JSON_INPUT" | jq -r '.message')
ROUTED_TO=$(echo "$JSON_INPUT" | jq -r '.routed_to')
TIMESTAMP=$(date -u +"%Y-%m-%dT%H:%M:%SZ")

# Use Python to update the outcome
python3 << PYEOF
import json
import os

log_file = "$LOG_FILE"
message = """$MESSAGE"""
routed_to = "$ROUTED_TO"
outcome = "$OUTCOME"
outcome_timestamp = "$TIMESTAMP"

entries = []

# Read existing log entries
if os.path.exists(log_file):
    with open(log_file, 'r') as f:
        lines = f.readlines()
    
    # Parse entries, preserving comments
    for line in lines:
        line = line.strip()
        if line.startswith('#') or not line:
            continue
        try:
            entry = json.loads(line)
            entries.append(entry)
        except json.JSONDecodeError:
            continue

# Find the most recent matching entry without an outcome
matching_idx = -1
for i in range(len(entries) - 1, -1, -1):  # Search from newest to oldest
    entry = entries[i]
    if (entry.get('message') == message and 
        entry.get('routed_to') == routed_to and 
        entry.get('outcome') is None):
        matching_idx = i
        break

if matching_idx >= 0:
    entries[matching_idx]['outcome'] = outcome
    entries[matching_idx]['outcome_timestamp'] = outcome_timestamp
    
    # Write back all entries
    with open(log_file, 'w') as f:
        f.write('# JSONL log of routing decisions and outcomes\\n')
        f.write('# Format: one JSON object per line\\n')
        f.write('# Fields: timestamp, message, routed_to, confidence, context_signals, outcome, outcome_timestamp\\n')
        for entry in entries:
            f.write(json.dumps(entry) + '\\n')
    
    print(f'Updated outcome for: {routed_to} -> {outcome}')
else:
    print(f'Warning: No matching log entry found for message to {routed_to}')
    exit(1)
PYEOF