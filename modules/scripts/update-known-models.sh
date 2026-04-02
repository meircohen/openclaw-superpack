#!/bin/bash
# Update registry with known working models from actual usage

REGISTRY="config/models/model-registry.json"
TIMESTAMP=$(date -u +"%Y-%m-%dT%H:%M:%SZ")

# Models we KNOW work from actual usage
declare -A KNOWN_WORKING=(
  ["sonnet-4"]="verified"
  ["sonnet-4.5"]="verified"
  ["opus-4.6"]="verified"
  ["haiku-4.5"]="verified"
  ["gpt-4o"]="verified"
  ["gpt-4o-mini"]="verified"
)

# Update each known model
for alias in "${!KNOWN_WORKING[@]}"; do
  jq ".models = [.models[] | if .alias == \"$alias\" then .status = \"healthy\" | .last_checked = \"$TIMESTAMP\" else . end]" \
    "$REGISTRY" > "$REGISTRY.tmp" && mv "$REGISTRY.tmp" "$REGISTRY"
  echo "✅ Marked $alias as healthy"
done

# Mark Gemini Flash as banned
jq '.models = [.models[] | if .alias == "gemini-2.5-flash" then .status = "banned" | .last_checked = "'$TIMESTAMP'" else . end]' \
  "$REGISTRY" > "$REGISTRY.tmp" && mv "$REGISTRY.tmp" "$REGISTRY"
echo "🚫 Marked gemini-2.5-flash as banned"

# Update timestamp
jq ".last_updated = \"$TIMESTAMP\"" "$REGISTRY" > "$REGISTRY.tmp" && mv "$REGISTRY.tmp" "$REGISTRY"

echo ""
echo "📊 Updated status:"
jq -r '.models | group_by(.status) | map("\(length) \(.[0].status)") | .[]' "$REGISTRY"
