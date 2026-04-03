#!/bin/bash

# Sentiment Detection for Auto-Rating
# Usage: echo "user response" | bash detect-sentiment.sh
# Output: good, bad, partial, or neutral

# Read input from stdin
INPUT=$(cat)

# Convert to lowercase for matching
INPUT_LOWER=$(echo "$INPUT" | tr '[:upper:]' '[:lower:]')

# Good keywords (high confidence positive)
GOOD_KEYWORDS="thanks|perfect|great|good|nice|👍|love it|exactly|awesome|excellent|wonderful|fantastic"

# Bad keywords (clear negative)
BAD_KEYWORDS="wrong|no|incorrect|that's not|useless|terrible|👎|awful|horrible|bad|failed|doesn't work"

# Partial keywords (needs improvement)
PARTIAL_KEYWORDS="close|almost|change|fix|update|tweak|but|however|except|modify|adjust|improve"

# Check for bad first (most important to catch)
if echo "$INPUT_LOWER" | grep -qE "$BAD_KEYWORDS"; then
    echo "bad"
    exit 0
fi

# Then check for good
if echo "$INPUT_LOWER" | grep -qE "$GOOD_KEYWORDS"; then
    echo "good"
    exit 0
fi

# Then check for partial
if echo "$INPUT_LOWER" | grep -qE "$PARTIAL_KEYWORDS"; then
    echo "partial"
    exit 0
fi

# Default to neutral if no clear sentiment
echo "neutral"