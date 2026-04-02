#!/bin/bash
# Test models by spawning sub-agents with specific model overrides
# This actually works with OpenClaw's architecture

set -euo pipefail

REGISTRY="config/models/model-registry.json"
TIMESTAMP=$(date -u +"%Y-%m-%dT%H:%M:%SZ")
RESULTS_FILE="artifacts/model-health-$(date +%Y%m%d-%H%M).json"

echo "🧪 Testing Models via Sub-Agent Spawning - $(date)"
echo ""

# Get all untested and error models
MODELS=$(jq -r '.models[] | select(.status=="untested" or .status=="error") | .alias' "$REGISTRY")
TOTAL=$(echo "$MODELS" | wc -l | tr -d ' ')

echo "Testing $TOTAL models..."
echo ""

# Initialize results
echo "{\"timestamp\":\"$TIMESTAMP\",\"results\":{}}" > "$RESULTS_FILE"

COUNT=0
for alias in $MODELS; do
  COUNT=$((COUNT + 1))
  echo "[$COUNT/$TOTAL] Testing $alias..."
  
  FULL_NAME=$(jq -r ".models[] | select(.alias==\"$alias\") | .full_name" "$REGISTRY")
  
  # Create temp dir for this test
  TEST_DIR=$(mktemp -d)
  TEST_LOG="$TEST_DIR/output.log"
  
  # Spawn a sub-agent with this specific model
  # Use sessions_spawn functionality via node
  node << EOJS > "$TEST_LOG" 2>&1 &
const { spawn } = require('child_process');

const proc = spawn('openclaw', [
  'agent',
  '--message', 'Reply with exactly: OK',
  '--session-id', 'model-test-${alias}-$(date +%s)',
  '--timeout', '30',
  '--json'
], {
  env: {
    ...process.env,
    OPENCLAW_AGENT_MODEL: '${FULL_NAME}'
  }
});

let output = '';
proc.stdout.on('data', d => output += d.toString());
proc.stderr.on('data', d => output += d.toString());

proc.on('close', code => {
  console.log(output);
  process.exit(code);
});

// Kill after 35 seconds
setTimeout(() => {
  proc.kill();
  console.log('TIMEOUT');
  process.exit(1);
}, 35000);
EOJS
  
  PID=$!
  
  # Wait for completion
  wait $PID 2>/dev/null
  EXIT_CODE=$?
  
  # Check result
  if [ -f "$TEST_LOG" ]; then
    OUTPUT=$(cat "$TEST_LOG")
    
    if echo "$OUTPUT" | grep -q -i "\"ok\"\|successful\|model test"; then
      STATUS="healthy"
      ICON="✅"
    elif echo "$OUTPUT" | grep -q -i "timeout\|timed out"; then
      STATUS="timeout"
      ICON="⏱️"
    elif echo "$OUTPUT" | grep -q -i "error\|failed\|unauthorized\|forbidden\|invalid"; then
      STATUS="error"
      ICON="❌"
    else
      STATUS="unknown"
      ICON="⚠️"
    fi
    
    RESPONSE=$(echo "$OUTPUT" | head -10 | tr '\n' ' ' | cut -c1-200)
  else
    STATUS="error"
    ICON="❌"
    RESPONSE="No output file"
  fi
  
  echo "  $ICON $STATUS"
  
  # Update registry
  jq ".models = [.models[] | if .alias == \"$alias\" then .status = \"$STATUS\" | .last_checked = \"$TIMESTAMP\" else . end]" \
    "$REGISTRY" > "$REGISTRY.tmp" && mv "$REGISTRY.tmp" "$REGISTRY"
  
  # Save to results
  jq ".results[\"$alias\"] = {\"status\":\"$STATUS\",\"full_name\":\"$FULL_NAME\",\"response\":\"$RESPONSE\"}" \
    "$RESULTS_FILE" > "$RESULTS_FILE.tmp" && mv "$RESULTS_FILE.tmp" "$RESULTS_FILE"
  
  # Cleanup
  rm -rf "$TEST_DIR"
  
  # Rate limit - don't hammer the APIs
  sleep 3
done

echo ""
echo "📊 Final Summary:"
jq -r '.models | group_by(.status) | map("\(length) \(.[0].status)") | .[]' "$REGISTRY"

echo ""
echo "✅ Results: $RESULTS_FILE"
echo "📝 Registry: $REGISTRY"

# Show breakdown by provider
echo ""
echo "By provider:"
for provider in anthropic openai xai google deepseek mistral meta moonshot qwen amazon ollama; do
  healthy=$(jq -r "[.models[] | select(.provider==\"$provider\" and .status==\"healthy\")] | length" "$REGISTRY")
  total=$(jq -r "[.models[] | select(.provider==\"$provider\")] | length" "$REGISTRY")
  if [ "$total" -gt 0 ]; then
    echo "  $provider: $healthy/$total healthy"
  fi
done
