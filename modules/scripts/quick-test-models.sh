#!/bin/bash
# Quick test: just verify each model is recognized by OpenClaw
# If it's in 'openclaw models list' with Auth:yes, it's available

set -euo pipefail

REGISTRY="config/models/model-registry.json"
TIMESTAMP=$(date -u +"%Y-%m-%dT%H:%M:%SZ")

echo "🧪 Quick Model Availability Check"
echo ""

# Get the list of configured models from OpenClaw
CONFIGURED=$(openclaw models list 2>/dev/null | tail -n +2 | awk '{print $1}' | grep -v "^$")

# Check each model in registry
MODELS=$(jq -r '.models[] | .full_name' "$REGISTRY")

HEALTHY=0
UNAVAILABLE=0

for model in $MODELS; do
  alias=$(jq -r ".models[] | select(.full_name==\"$model\") | .alias" "$REGISTRY")
  
  if echo "$CONFIGURED" | grep -q "^$model$"; then
    # Model is configured
    jq ".models = [.models[] | if .full_name == \"$model\" then .status = \"healthy\" | .last_checked = \"$TIMESTAMP\" else . end]" \
      "$REGISTRY" > "$REGISTRY.tmp" && mv "$REGISTRY.tmp" "$REGISTRY"
    echo "✅ $alias ($model)"
    HEALTHY=$((HEALTHY + 1))
  else
    # Model not found
    jq ".models = [.models[] | if .full_name == \"$model\" then .status = \"unavailable\" | .last_checked = \"$TIMESTAMP\" else . end]" \
      "$REGISTRY" > "$REGISTRY.tmp" && mv "$REGISTRY.tmp" "$REGISTRY"
    echo "❌ $alias - not configured"
    UNAVAILABLE=$((UNAVAILABLE + 1))
  fi
done

# Update registry timestamp
jq ".last_updated = \"$TIMESTAMP\"" "$REGISTRY" > "$REGISTRY.tmp" && mv "$REGISTRY.tmp" "$REGISTRY"

echo ""
echo "📊 Summary:"
echo "  ✅ $HEALTHY models available"
echo "  ❌ $UNAVAILABLE models unavailable"
echo ""

# Show by status
echo "Registry status:"
jq -r '.models | group_by(.status) | map("\(length) \(.[0].status)") | .[]' "$REGISTRY"

echo ""
echo "By provider:"
for provider in anthropic openai xai google deepseek mistral meta moonshot qwen amazon ollama; do
  healthy=$(jq -r "[.models[] | select(.provider==\"$provider\" and .status==\"healthy\")] | length" "$REGISTRY")
  total=$(jq -r "[.models[] | select(.provider==\"$provider\")] | length" "$REGISTRY")
  if [ "$total" -gt 0 ]; then
    echo "  $provider: $healthy/$total"
  fi
done
