#!/bin/bash
# Test all models with tool use to verify they work for agent tasks
# This is a full integration test

set -euo pipefail

REGISTRY="config/models/model-registry.json"
TIMESTAMP=$(date -u +"%Y-%m-%dT%H:%M:%SZ")
RESULTS_FILE="artifacts/model-health-$(date +%Y%m%d-%H%M).json"

echo "🧪 Full Model Test Suite - $(date)"
echo "Testing all 37 models with tool use..."
echo ""

# Get all model aliases
MODELS=$(jq -r '.models[].alias' "$REGISTRY")
TOTAL=$(echo "$MODELS" | wc -l | tr -d ' ')

# Initialize results
echo "{\"timestamp\":\"$TIMESTAMP\",\"results\":{}}" > "$RESULTS_FILE"

COUNT=0
for alias in $MODELS; do
  COUNT=$((COUNT + 1))
  echo "[$COUNT/$TOTAL] Testing $alias..."
  
  FULL_NAME=$(jq -r ".models[] | select(.alias==\"$alias\") | .full_name" "$REGISTRY")
  
  # Create test message that requires tool use
  TEST_MSG="Use session_status tool to get the current date and time, then reply with: Model test successful on [date]"
  
  # Create temp file for output
  TEST_OUTPUT=$(mktemp)
  
  # Run test via openclaw send
  if openclaw send \
    --message "$TEST_MSG" \
    --model "$FULL_NAME" \
    --timeout 45 \
    > "$TEST_OUTPUT" 2>&1; then
    
    # Check if response shows tool use and success
    if grep -q -i "successful" "$TEST_OUTPUT" && grep -q -i "2026" "$TEST_OUTPUT"; then
      STATUS="healthy"
      ICON="✅"
    elif grep -q -i "error\|failed\|unauthorized\|forbidden" "$TEST_OUTPUT"; then
      STATUS="error"
      ICON="❌"
    else
      STATUS="partial"
      ICON="⚠️"
    fi
  else
    STATUS="error"
    ICON="❌"
  fi
  
  # Get response snippet
  RESPONSE=$(cat "$TEST_OUTPUT" | tr '\n' ' ' | cut -c1-300)
  
  echo "  $ICON $STATUS"
  
  # Update registry
  jq ".models = [.models[] | if .alias == \"$alias\" then .status = \"$STATUS\" | .last_checked = \"$TIMESTAMP\" else . end]" \
    "$REGISTRY" > "$REGISTRY.tmp" && mv "$REGISTRY.tmp" "$REGISTRY"
  
  # Save to results
  jq ".results[\"$alias\"] = {\"status\":\"$STATUS\",\"full_name\":\"$FULL_NAME\",\"response\":\"$RESPONSE\"}" \
    "$RESULTS_FILE" > "$RESULTS_FILE.tmp" && mv "$RESULTS_FILE.tmp" "$RESULTS_FILE"
  
  rm "$TEST_OUTPUT"
  
  # Rate limit between tests
  sleep 2
done

echo ""
echo "📊 Final Summary:"
jq -r '.models | group_by(.status) | map("\(length) \(.[0].status)") | sort | .[]' "$REGISTRY"

echo ""
echo "✅ Full results saved to: $RESULTS_FILE"
echo "📝 Registry updated: $REGISTRY"

# Show provider breakdown
echo ""
echo "By provider:"
jq -r '.models | group_by(.provider) | map("  \(.[0].provider): \(length) models, \([.[] | select(.status==\"healthy\")] | length) healthy") | .[]' "$REGISTRY"
