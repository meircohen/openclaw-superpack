#!/bin/bash

# Agent Router Script
# Usage: bash scripts/agent-router.sh "user message text"

set -e

# Input validation
if [ $# -eq 0 ]; then
    echo '{"agent": "main", "confidence": 0.0, "reason": "no input provided"}'
    exit 0
fi

MESSAGE="$1"
CAPABILITIES_FILE="config/agent-router/capabilities.json"

# Check if capabilities file exists
if [ ! -f "$CAPABILITIES_FILE" ]; then
    echo '{"agent": "main", "confidence": 0.0, "reason": "capabilities file not found"}'
    exit 1
fi

# Convert message to lowercase for matching
MESSAGE_LOWER=$(echo "$MESSAGE" | tr '[:upper:]' '[:lower:]')

# Track best match
BEST_AGENT="main"
BEST_SCORE=0
BEST_MATCHES=""
CONFIDENCE_THRESHOLD=0.6

# Skip routing for certain patterns
if echo "$MESSAGE_LOWER" | grep -qE "(how are you|what's up|hello|hi|thanks|thank you)\b"; then
    echo '{"agent": "main", "confidence": 1.0, "reason": "casual chat or personal query"}'
    exit 0
fi

if echo "$MESSAGE_LOWER" | grep -qE "\bwhoop\b|(twitter|x\.com)|(personal|preference|remember|memory)"; then
    echo '{"agent": "main", "confidence": 1.0, "reason": "personal query or social media"}'
    exit 0
fi

# Parse JSON and score each agent
python3 -c "
import json
import sys
import re

# Load capabilities
with open('$CAPABILITIES_FILE', 'r') as f:
    data = json.load(f)

message = '''$MESSAGE_LOWER'''
best_agent = 'main'
best_score = 0
best_matches = []

for agent in data['agents']:
    score = 0
    matches = []
    
    # Score keywords
    for keyword in agent['keywords']:
        if keyword.lower() in message:
            score += 1
            matches.append(keyword)
    
    # Boost for task types
    for task_type in agent['task_types']:
        if any(word in message for word in task_type.split('-')):
            score += 0.5
    
    # Priority weighting (higher priority = lower number = higher weight)
    if agent['priority'] == 1:
        score *= 1.5
    elif agent['priority'] == 2:
        score *= 1.2
    
    # Apply priority weighting but don't normalize by keyword count
    # (normalization was making all scores too low)
    
    if score > best_score:
        best_score = score
        best_agent = agent['id']
        best_matches = matches

# Calculate confidence (scale to reasonable range)
confidence = min(best_score / 3.0, 1.0)  # Scale by expected max matches

if confidence < $CONFIDENCE_THRESHOLD:
    best_agent = 'main'
    confidence = 0.0

result = {
    'agent': best_agent,
    'confidence': round(confidence, 2),
    'reason': f'matched: {', '.join(best_matches[:3])}' if best_matches else 'no strong matches'
}

print(json.dumps(result))
"