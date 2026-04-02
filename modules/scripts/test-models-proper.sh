#!/bin/bash
# Test all untested models with the correct openclaw agent command

set -euo pipefail

REGISTRY="config/models/model-registry.json"
TIMESTAMP=$(date -u +"%Y-%m-%dT%H:%M:%SZ")
RESULTS_FILE="artifacts/model-health-$(date +%Y%m%d-%H%M).json"

echo "🧪 Testing All Untested Models - $(date)"
echo ""

# Get untested models
MODELS=$(jq -r '.models[] | select(.status=="untested") | .alias' "$REGISTRY")
TOTAL=$(echo "$MODELS" | wc -l | tr -d ' ')

echo "Found $TOTAL untested models"
echo ""

# Initialize results
echo "{\"timestamp\":\"$TIMESTAMP\",\"results\":{}}" > "$RESULTS_FILE"

COUNT=0
for alias in $MODELS; do
  COUNT=$((COUNT + 1))
  echo "[$COUNT/$TOTAL] Testing $alias..."
  
  FULL_NAME=$(jq -r ".models[] | select(.alias==\"$alias\") | .full_name" "$REGISTRY")
  
  # Test with simple message
  TEST_MSG="Reply with exactly: OK"
  
  # Create temp file
  TEST_OUTPUT=$(mktemp)
  
  # Run test (30 second timeout)
  if timeout 30 openclaw agent \
    --message "$TEST_MSG" \
    --model "$FULL_NAME" \
    > "$TEST_OUTPUT" 2>&1; then
    
    OUTPUT=$(cat "$TEST_OUTPUT")
    if echo "$OUTPUT" | grep -q -i "ok\|successful"; then
      STATUS="healthy"
      ICON="✅"
    else
      STATUS="unknown"
      ICON="⚠️"
    fi
  else
    STATUS="error"
    ICON="❌"
  fi
  
  # Get response snippet
  RESPONSE=$(cat "$TEST_OUTPUT" | head -20 | tr '\n' ' ' | cut -c1-200)
  
  echo "  $ICON $STATUS"
  
  # Update registry
  jq ".models = [.models[] | if .alias == \"$alias\" then .status = \"$STATUS\" | .last_checked = \"$TIMESTAMP\" else . end]" \
    "$REGISTRY" > "$REGISTRY.tmp" && mv "$REGISTRY.tmp" "$REGISTRY"
  
  # Save to results
  jq ".results[\"$alias\"] = {\"status\":\"$STATUS\",\"full_name\":\"$FULL_NAME\",\"response\":\"$RESPONSE\"}" \
    "$RESULTS_FILE" > "$RESULTS_FILE.tmp" && mv "$RESULTS_FILE.tmp" "$RESULTS_FILE"
  
  rm "$TEST_OUTPUT"
  
  # Rate limit
  sleep 3
done

echo ""
echo "📊 Final Summary:"
jq -r '.models | group_by(.status) | map("\(length) \(.[0].status)") | .[]' "$REGISTRY"

echo ""
echo "Results saved to: $RESULTS_FILE"
