#!/bin/bash
# Collect baseline token usage data for budget enforcement
# Run weekly to build historical data before implementing auto-downgrade

set -e

WORKSPACE_ROOT="$HOME/.openclaw/workspace"
DATA_DIR="$WORKSPACE_ROOT/data/token-baselines"
OUTPUT_FILE="$DATA_DIR/baseline-$(date +%Y-%m-%d).json"

mkdir -p "$DATA_DIR"

echo "[$(date -Iseconds)] Collecting token baseline data..."

# Aggregate all agent sessions
AGENTS_DIR="$HOME/.openclaw/agents"
TEMP_FILE="/tmp/all-sessions-$$.json"

echo "[]" > "$TEMP_FILE"

for agent_dir in "$AGENTS_DIR"/*; do
  if [[ -d "$agent_dir" ]]; then
    SESSIONS_FILE="$agent_dir/sessions/sessions.json"
    if [[ -f "$SESSIONS_FILE" ]]; then
      agent_name=$(basename "$agent_dir")
      echo "  Found sessions for agent: $agent_name"
      # Add agent field and append to temp
      jq --arg agent "$agent_name" 'map(. + {agent: $agent})' "$SESSIONS_FILE" > /tmp/agent-sessions-$$.json
      jq -s '.[0] + .[1]' "$TEMP_FILE" /tmp/agent-sessions-$$.json > /tmp/merged-$$.json
      mv /tmp/merged-$$.json "$TEMP_FILE"
      rm -f /tmp/agent-sessions-$$.json
    fi
  fi
done

# Parse aggregated sessions for token usage by model
jq -r '
  # Group by model
  group_by(.model) | 
  map({
    model: .[0].model,
    session_count: length,
    total_input_tokens: map(.usage.inputTokens // 0) | add,
    total_output_tokens: map(.usage.outputTokens // 0) | add,
    total_cost: map(.usage.cost // 0) | add
  }) |
  # Sort by cost descending
  sort_by(.total_cost) | reverse
' "$TEMP_FILE" > "$OUTPUT_FILE"

rm -f "$TEMP_FILE"

# Calculate per-agent totals (requires agent ID in session metadata - may not exist yet)
# For now, just report model totals

# Summary stats
TOTAL_SESSIONS=$(jq 'map(.session_count) | add' "$OUTPUT_FILE")
TOTAL_COST=$(jq 'map(.total_cost) | add' "$OUTPUT_FILE")
TOTAL_INPUT=$(jq 'map(.total_input_tokens) | add' "$OUTPUT_FILE")
TOTAL_OUTPUT=$(jq 'map(.total_output_tokens) | add' "$OUTPUT_FILE")

echo "
📊 Token Baseline Snapshot
==========================
Date: $(date +%Y-%m-%d)
Total sessions: $TOTAL_SESSIONS
Total input tokens: $TOTAL_INPUT
Total output tokens: $TOTAL_OUTPUT
Total cost: \$$TOTAL_COST

Top 3 models by cost:
$(jq -r 'limit(3; .[]) | "  \(.model): $\(.total_cost | tonumber | . * 100 | round / 100) (\(.session_count) sessions)"' "$OUTPUT_FILE")

📁 Full data saved to: $OUTPUT_FILE
"

# Store summary in artifact
ARTIFACT_FILE="$WORKSPACE_ROOT/artifacts/ops/token-budget-baseline-latest.json"
jq -n \
  --argjson models "$(cat $OUTPUT_FILE)" \
  --arg date "$(date -Iseconds)" \
  --argjson total_sessions "$TOTAL_SESSIONS" \
  --argjson total_cost "$TOTAL_COST" \
  --argjson total_input "$TOTAL_INPUT" \
  --argjson total_output "$TOTAL_OUTPUT" \
  '{
    collected_at: $date,
    total_sessions: $total_sessions,
    total_input_tokens: $total_input,
    total_output_tokens: $total_output,
    total_cost_usd: $total_cost,
    models: $models
  }' > "$ARTIFACT_FILE"

echo "✅ Baseline data collected successfully"
