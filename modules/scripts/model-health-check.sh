#!/bin/bash
# Test all models in the registry and update their status
# Usage: bash scripts/model-health-check.sh [--model alias] [--quick]

set -euo pipefail

REGISTRY="config/models/model-registry.json"
QUICK_MODE=false
SPECIFIC_MODEL=""

while [[ $# -gt 0 ]]; do
  case $1 in
    --model) SPECIFIC_MODEL="$2"; shift 2 ;;
    --quick) QUICK_MODE=true; shift ;;
    *) echo "Unknown option: $1"; exit 1 ;;
  esac
done

# Get list of models to test
if [ -n "$SPECIFIC_MODEL" ]; then
  MODELS=$(jq -r ".models[] | select(.alias==\"$SPECIFIC_MODEL\") | .alias" "$REGISTRY")
else
  MODELS=$(jq -r '.models[].alias' "$REGISTRY")
fi

TIMESTAMP=$(date -u +"%Y-%m-%dT%H:%M:%SZ")
RESULTS_FILE="artifacts/model-health-$(date +%Y%m%d).json"

echo "🧪 Model Health Check - $(date)"
echo "Testing $(echo "$MODELS" | wc -l | tr -d ' ') models..."
echo ""

# Initialize results
echo '{"timestamp":"'$TIMESTAMP'","results":{}}' > "$RESULTS_FILE"

for alias in $MODELS; do
  echo -n "Testing $alias... "
  
  FULL_NAME=$(jq -r ".models[] | select(.alias==\"$alias\") | .full_name" "$REGISTRY")
  
  # Create test session
  TEST_OUTPUT=$(mktemp)
  
  # Use OpenClaw to test the model
  if $QUICK_MODE; then
    TIMEOUT=10
    TEST_MSG="Reply with: OK"
  else
    TIMEOUT=30
    TEST_MSG="You are a helpful AI assistant. Reply with exactly: 'Model test successful.' Then state today's date if you can determine it."
  fi
  
  # Run test via sessions_spawn
  # Create a simple test task
  TEST_ID=$(date +%s)
  TEST_SESSION="model-test-$TEST_ID"
  
  # Spawn test agent with specific model
  openclaw agent send \
    --task "$TEST_MSG" \
    --model "$FULL_NAME" \
    --timeout $TIMEOUT \
    > "$TEST_OUTPUT" 2>&1 || true
  
  # Check result
  if grep -q -i "successful\|OK" "$TEST_OUTPUT"; then
    STATUS="healthy"
    ICON="✅"
  elif grep -q -i "error\|failed\|timeout" "$TEST_OUTPUT"; then
    STATUS="error"
    ICON="❌"
  else
    STATUS="unknown"
    ICON="⚠️"
  fi
  
  # Get response snippet
  RESPONSE=$(head -100 "$TEST_OUTPUT" | tr '\n' ' ' | cut -c1-200)
  
  echo "$ICON $STATUS"
  
  # Update registry
  jq ".models = [.models[] | if .alias == \"$alias\" then .status = \"$STATUS\" | .last_checked = \"$TIMESTAMP\" else . end]" \
    "$REGISTRY" > "$REGISTRY.tmp" && mv "$REGISTRY.tmp" "$REGISTRY"
  
  # Save to results
  jq ".results[\"$alias\"] = {\"status\":\"$STATUS\",\"response\":\"$RESPONSE\"}" \
    "$RESULTS_FILE" > "$RESULTS_FILE.tmp" && mv "$RESULTS_FILE.tmp" "$RESULTS_FILE"
  
  rm "$TEST_OUTPUT"
  
  # Rate limit
  sleep 2
done

echo ""
echo "📊 Summary:"
jq -r '.models | group_by(.status) | map("\(length) \(.[0].status)") | .[]' "$REGISTRY"

echo ""
echo "Full results: $RESULTS_FILE"
echo "Registry updated: $REGISTRY"
