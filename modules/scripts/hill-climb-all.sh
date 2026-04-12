#!/usr/bin/env bash
# hill-climb-all.sh — Run all 10 hill-climbing optimizers in sequence.
#
# Usage:
#   scripts/hill-climb-all.sh              # Analyze only (default)
#   scripts/hill-climb-all.sh --dry-run    # Preview mode
#   scripts/hill-climb-all.sh --apply      # Apply all changes
#   scripts/hill-climb-all.sh --quick      # Skip slow optimizers (prompt tuner, evaluator)

set -euo pipefail

WORKSPACE="$HOME/.openclaw/workspace"
STATE="$WORKSPACE/state"
LOG="$STATE/hill-climb-all-log.jsonl"
TIMESTAMP=$(date -u +"%Y-%m-%dT%H:%M:%SZ")

DRY_RUN=""
APPLY=""
QUICK=false
for arg in "$@"; do
  case "$arg" in
    --dry-run) DRY_RUN="--dry-run" ;;
    --apply)   APPLY="--apply" ;;
    --quick)   QUICK=true ;;
    --help|-h)
      echo "Usage: hill-climb-all.sh [--dry-run] [--apply] [--quick]"
      echo ""
      echo "  --dry-run   Preview mode — no state changes"
      echo "  --apply     Apply optimized results"
      echo "  --quick     Skip slow optimizers (prompt tuner, evaluator)"
      exit 0
      ;;
  esac
done

mkdir -p "$STATE"

TOTAL=10
if $QUICK; then TOTAL=8; fi
PASS=0
FAIL=0
START_SEC=$(date +%s)

echo "========================================"
echo "Hill-Climb All ($TOTAL optimizers) — $TIMESTAMP"
echo "========================================"

run_optimizer() {
  local num="$1"
  local total="$2"
  local name="$3"
  local cmd="$4"
  local status="success"

  echo ""
  echo "--- [$num/$total] $name ---"
  local step_start
  step_start=$(date +%s)

  if eval "$cmd" 2>&1; then
    PASS=$((PASS + 1))
    echo "OK: $name"
  else
    FAIL=$((FAIL + 1))
    status="failed"
    echo "FAIL: $name (non-fatal, continuing)"
  fi

  local step_end
  step_end=$(date +%s)
  local duration=$((step_end - step_start))

  printf '{"timestamp":"%s","optimizer":"%s","status":"%s","duration_s":%d,"flags":"%s"}\n' \
    "$(date -u +"%Y-%m-%dT%H:%M:%SZ")" "$name" "$status" "$duration" "$DRY_RUN $APPLY" >> "$LOG"
}

# 1. Tweet Engagement Hill-Climber
run_optimizer 1 $TOTAL "tweet-hill-climber" \
  "python3 $WORKSPACE/scripts/tweet-hill-climber.py $DRY_RUN $APPLY"

# 2. Routing Decision Optimizer
if [ -n "$APPLY" ]; then
  ROUTING_CMD="python3 $WORKSPACE/scripts/routing-optimizer.py apply $DRY_RUN"
else
  ROUTING_CMD="python3 $WORKSPACE/scripts/routing-optimizer.py recommend"
fi
run_optimizer 2 $TOTAL "routing-optimizer" "$ROUTING_CMD"

# 3. Intel Signal Optimizer
run_optimizer 3 $TOTAL "intel-signal-optimizer" \
  "python3 $WORKSPACE/scripts/intel-signal-optimizer.py --report $APPLY"

# 4. Email Triage Optimizer
run_optimizer 4 $TOTAL "email-triage-optimizer" \
  "python3 $WORKSPACE/scripts/email-triage-optimizer.py --report"

# 5. Agent Roster Optimizer
run_optimizer 5 $TOTAL "agent-roster-optimizer" \
  "python3 $WORKSPACE/scripts/agent-roster-optimizer.py --report"

# 6. Cost/Quality Pareto Optimizer
run_optimizer 6 $TOTAL "cost-quality-optimizer" \
  "python3 $WORKSPACE/scripts/cost-quality-optimizer.py --report"

# 7. Memory Retrieval Optimizer
run_optimizer 7 $TOTAL "memory-retrieval-optimizer" \
  "python3 $WORKSPACE/scripts/memory-retrieval-optimizer.py --report"

# 8. Cron Schedule Optimizer
run_optimizer 8 $TOTAL "cron-schedule-optimizer" \
  "python3 $WORKSPACE/scripts/cron-schedule-optimizer.py --report"

# 9. System Prompt Auto-Tuner (slow — uses Claude CLI)
if ! $QUICK; then
  TUNER_FLAGS="--iterations 3"
  if [ -n "$DRY_RUN" ]; then TUNER_FLAGS="$TUNER_FLAGS --dry-run"; fi
  run_optimizer 9 $TOTAL "prompt-tuner" \
    "python3 $WORKSPACE/scripts/prompt-tuner.py tweet-engagement $TUNER_FLAGS"
fi

# 10. Evaluator Agent — voice guide comparison (slow — uses Claude CLI)
if ! $QUICK; then
  EVAL_CMD="python3 $WORKSPACE/scripts/evaluator-agent.py voice-guide $WORKSPACE/skills/delegation/voice/default.md --json"
  run_optimizer 10 $TOTAL "evaluator-agent" "$EVAL_CMD"
fi

END_SEC=$(date +%s)
TOTAL_DURATION=$((END_SEC - START_SEC))

echo ""
echo "========================================"
echo "Done: $PASS passed, $FAIL failed, ${TOTAL_DURATION}s total"
echo "========================================"
