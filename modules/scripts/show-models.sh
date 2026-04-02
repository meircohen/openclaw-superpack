#!/bin/bash
# Display model registry in readable format
# Usage: bash scripts/show-models.sh [--tier production] [--status healthy] [--provider anthropic]

REGISTRY="config/models/model-registry.json"
FILTER=""

while [[ $# -gt 0 ]]; do
  case $1 in
    --tier) FILTER="$FILTER | select(.tier==\"$2\")"; shift 2 ;;
    --status) FILTER="$FILTER | select(.status==\"$2\")"; shift 2 ;;
    --provider) FILTER="$FILTER | select(.provider==\"$2\")"; shift 2 ;;
    --help) 
      echo "Usage: show-models.sh [--tier X] [--status X] [--provider X]"
      echo "Tiers: production, premium, economy, reasoning, experimental"
      echo "Status: healthy, error, unknown"
      exit 0
      ;;
    *) echo "Unknown option: $1"; exit 1 ;;
  esac
done

echo "🤖 OpenClaw Model Registry"
echo "Last updated: $(jq -r '.last_updated' "$REGISTRY")"
echo ""

jq -r ".models[] $FILTER | 
  \"\\(.alias) (\\(.tier))
  Provider: \\(.provider)
  Full name: \\(.full_name)
  Context: \\(.context_window | tostring) tokens
  Cost: $\\(.cost_per_1m_tokens.input)/M input, $\\(.cost_per_1m_tokens.output)/M output
  Status: \\(.status // \"unknown\")
  Recommended: \\(.recommended_for | join(\", \"))
  \\(if .restrictions then \"⚠️  \" + (.restrictions | join(\", \")) else \"\" end)
  \"" "$REGISTRY"

echo ""
echo "📊 By tier:"
jq -r '.models | group_by(.tier) | map("  \(.[0].tier): \(length) models") | .[]' "$REGISTRY"

echo ""
echo "🏥 By status:"
jq -r '.models | group_by(.status) | map("  \(length) \(.[0].status)") | .[]' "$REGISTRY"
