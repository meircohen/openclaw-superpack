#!/usr/bin/env bash
# token-tracker.sh — Track token spend per agent per day
# Usage:
#   bash scripts/token-tracker.sh log <agent> <tokens_in> <tokens_out> [model]
#   bash scripts/token-tracker.sh today [agent]
#   bash scripts/token-tracker.sh check <agent>  → exits 1 if over budget
#   bash scripts/token-tracker.sh report [days]  → summary of last N days
#   bash scripts/token-tracker.sh set-budget <agent> <daily_limit>
#
# Token costs (approx per 1M tokens):
#   sonnet-4:  $3 in / $15 out
#   haiku:     $0.25 in / $1.25 out
#   opus:      $15 in / $75 out

set -euo pipefail

WORKSPACE="/Users/meircohen/.openclaw/workspace"
TRACKER_DIR="$WORKSPACE/shared/token-tracking"
BUDGETS_FILE="$TRACKER_DIR/budgets.json"
mkdir -p "$TRACKER_DIR"

TODAY=$(date +%Y-%m-%d)
TODAY_FILE="$TRACKER_DIR/${TODAY}.jsonl"

# Initialize budgets file if missing
if [[ ! -f "$BUDGETS_FILE" ]]; then
  cat > "$BUDGETS_FILE" << 'EOF'
{
  "_comment": "Daily token budget per agent (output tokens). 0 = unlimited.",
  "default": 50000,
  "sonnet-4": 100000,
  "haiku": 200000,
  "claude-code": 0,
  "codex": 0,
  "oz": 100000
}
EOF
fi

ACTION="${1:-help}"

case "$ACTION" in
  log)
    AGENT="${2:?Usage: token-tracker.sh log <agent> <tokens_in> <tokens_out> [model]}"
    TOKENS_IN="${3:?Missing tokens_in}"
    TOKENS_OUT="${4:?Missing tokens_out}"
    MODEL="${5:-unknown}"
    
    ENTRY=$(jq -n \
      --arg agent "$AGENT" \
      --argjson tin "$TOKENS_IN" \
      --argjson tout "$TOKENS_OUT" \
      --arg model "$MODEL" \
      --arg ts "$(date -u +"%Y-%m-%dT%H:%M:%SZ")" \
      --arg task_type "${TASK_TYPE:-unknown}" \
      '{timestamp: $ts, agent: $agent, model: $model, tokens_in: $tin, tokens_out: $tout, task_type: $task_type}')
    
    echo "$ENTRY" >> "$TODAY_FILE"
    
    TOTAL_OUT=$(jq -r "select(.agent==\"$AGENT\") | .tokens_out" "$TODAY_FILE" 2>/dev/null | awk '{s+=$1} END {print s+0}')
    echo "Logged: ${AGENT} +${TOKENS_IN}in/${TOKENS_OUT}out (today total out: ${TOTAL_OUT})"
    ;;
    
  today)
    AGENT="${2:-}"
    if [[ ! -f "$TODAY_FILE" ]]; then
      echo "No activity today"
      exit 0
    fi
    
    if [[ -n "$AGENT" ]]; then
      IN=$(jq -r "select(.agent==\"$AGENT\") | .tokens_in" "$TODAY_FILE" | awk '{s+=$1} END {print s+0}')
      OUT=$(jq -r "select(.agent==\"$AGENT\") | .tokens_out" "$TODAY_FILE" | awk '{s+=$1} END {print s+0}')
      CALLS=$(jq -r "select(.agent==\"$AGENT\")" "$TODAY_FILE" | wc -l | tr -d ' ')
      BUDGET=$(jq -r ".\"$AGENT\" // .default // 50000" "$BUDGETS_FILE")
      echo "${AGENT}: ${IN} in / ${OUT} out (${CALLS} calls) — budget: ${OUT}/${BUDGET}"
    else
      echo "=== Token Usage: ${TODAY} ==="
      jq -r '.agent' "$TODAY_FILE" | sort -u | while read -r a; do
        IN=$(jq -r "select(.agent==\"$a\") | .tokens_in" "$TODAY_FILE" | awk '{s+=$1} END {print s+0}')
        OUT=$(jq -r "select(.agent==\"$a\") | .tokens_out" "$TODAY_FILE" | awk '{s+=$1} END {print s+0}')
        CALLS=$(jq -r "select(.agent==\"$a\")" "$TODAY_FILE" | wc -l | tr -d ' ')
        BUDGET=$(jq -r ".\"$a\" // .default // 50000" "$BUDGETS_FILE")
        PCT=$((OUT * 100 / (BUDGET > 0 ? BUDGET : 1)))
        FLAG=""
        [[ $BUDGET -gt 0 && $OUT -gt $BUDGET ]] && FLAG=" ⚠️ OVER BUDGET"
        [[ $BUDGET -gt 0 && $PCT -gt 80 ]] && FLAG=" ⚡ 80%+ used"
        echo "  ${a}: ${IN}in/${OUT}out (${CALLS} calls) [${PCT}% of ${BUDGET}]${FLAG}"
      done
    fi
    ;;
    
  check)
    AGENT="${2:?Usage: token-tracker.sh check <agent>}"
    if [[ ! -f "$TODAY_FILE" ]]; then
      exit 0  # No usage = under budget
    fi
    
    TOTAL_OUT=$(jq -r "select(.agent==\"$AGENT\") | .tokens_out" "$TODAY_FILE" 2>/dev/null | awk '{s+=$1} END {print s+0}')
    BUDGET=$(jq -r ".\"$AGENT\" // .default // 50000" "$BUDGETS_FILE")
    
    if [[ "$BUDGET" == "0" ]]; then
      exit 0  # Unlimited
    fi
    
    if [[ $TOTAL_OUT -gt $BUDGET ]]; then
      echo "OVER_BUDGET: ${AGENT} used ${TOTAL_OUT} of ${BUDGET} output tokens today" >&2
      exit 1
    fi
    
    REMAINING=$((BUDGET - TOTAL_OUT))
    echo "OK: ${AGENT} has ${REMAINING} tokens remaining today"
    ;;
    
  set-budget)
    AGENT="${2:?Usage: token-tracker.sh set-budget <agent> <daily_limit>}"
    LIMIT="${3:?Missing daily_limit}"
    
    TMP=$(mktemp)
    jq --arg agent "$AGENT" --argjson limit "$LIMIT" '.[$agent] = $limit' "$BUDGETS_FILE" > "$TMP" && mv "$TMP" "$BUDGETS_FILE"
    echo "Set daily budget for ${AGENT}: ${LIMIT} output tokens"
    ;;
    
  report)
    DAYS="${2:-7}"
    echo "=== Token Report (last ${DAYS} days) ==="
    TOTAL_IN=0
    TOTAL_OUT=0
    for i in $(seq 0 $((DAYS - 1))); do
      DAY=$(date -v-${i}d +%Y-%m-%d 2>/dev/null || date -d "$i days ago" +%Y-%m-%d)
      FILE="$TRACKER_DIR/${DAY}.jsonl"
      if [[ -f "$FILE" ]]; then
        DIN=$(jq -r '.tokens_in' "$FILE" | awk '{s+=$1} END {print s+0}')
        DOUT=$(jq -r '.tokens_out' "$FILE" | awk '{s+=$1} END {print s+0}')
        DCALLS=$(wc -l < "$FILE" | tr -d ' ')
        echo "  ${DAY}: ${DIN}in/${DOUT}out (${DCALLS} calls)"
        TOTAL_IN=$((TOTAL_IN + DIN))
        TOTAL_OUT=$((TOTAL_OUT + DOUT))
      fi
    done
    echo "  ---"
    echo "  Total: ${TOTAL_IN}in/${TOTAL_OUT}out"
    
    # Rough cost estimate (assumes sonnet-4 pricing)
    COST_IN=$(echo "scale=2; $TOTAL_IN * 3 / 1000000" | bc 2>/dev/null || echo "?")
    COST_OUT=$(echo "scale=2; $TOTAL_OUT * 15 / 1000000" | bc 2>/dev/null || echo "?")
    echo "  Est. cost: \$${COST_IN} (in) + \$${COST_OUT} (out)"
    ;;
    
  help|*)
    echo "Usage:"
    echo "  token-tracker.sh log <agent> <tokens_in> <tokens_out> [model]"
    echo "  token-tracker.sh today [agent]"
    echo "  token-tracker.sh check <agent>  → exits 1 if over budget"
    echo "  token-tracker.sh report [days]"
    echo "  token-tracker.sh set-budget <agent> <daily_limit>"
    ;;
esac
