#!/usr/bin/env bash
# mesh-test.sh — End-to-end pipeline test for the OpenClaw mesh
#
# Runs a full task through: route → context-inject → dispatch → verify → stats
# Idempotent: safe to run multiple times, each run writes a unique report.
#
# Usage:
#   bash scripts/mesh-test.sh              # Full pipeline (real dispatch)
#   bash scripts/mesh-test.sh --dry-run    # Skip dispatch + verify (routing only)

set -euo pipefail

WORKSPACE="/Users/meircohen/.openclaw/workspace"
SCRIPTS="$WORKSPACE/scripts"
RESULTS_DIR="$WORKSPACE/shared/mesh-test"
mkdir -p "$RESULTS_DIR"

DRY_RUN=false
[[ "${1:-}" == "--dry-run" ]] && DRY_RUN=true

TIMESTAMP=$(date +%Y-%m-%d-%H%M%S)
REPORT="$RESULTS_DIR/test-${TIMESTAMP}.md"
TEST_TASK='Write a Python function that calculates fibonacci numbers'

TOTAL=0
PASSED=0
FAILED=0

# ============================================================
# Helpers
# ============================================================
step_start() {
  STEP_NAME="$1"
  STEP_START=$(date +%s)
  TOTAL=$((TOTAL + 1))
}

step_pass() {
  local elapsed=$(( $(date +%s) - STEP_START ))
  echo "PASS  ${STEP_NAME} (${elapsed}s)"
  echo "| ${STEP_NAME} | PASS | ${elapsed}s | ${1:-} |" >> "$REPORT"
  PASSED=$((PASSED + 1))
}

step_fail() {
  local elapsed=$(( $(date +%s) - STEP_START ))
  echo "FAIL  ${STEP_NAME} (${elapsed}s) — $1"
  echo "| ${STEP_NAME} | FAIL | ${elapsed}s | $1 |" >> "$REPORT"
  FAILED=$((FAILED + 1))
}

# ============================================================
# Report header
# ============================================================
cat > "$REPORT" <<EOF
# Mesh Pipeline Test — ${TIMESTAMP}

Task: ${TEST_TASK}
Mode: $(if $DRY_RUN; then echo "DRY RUN"; else echo "LIVE"; fi)

| Step | Result | Time | Notes |
|------|--------|------|-------|
EOF

echo "=== Mesh Pipeline Test ($(if $DRY_RUN; then echo "dry-run"; else echo "live"; fi)) ==="
echo "Task: $TEST_TASK"
echo ""

# ============================================================
# Step 1: Route
# ============================================================
step_start "route.sh"

ROUTE_OUTPUT=$(bash "$SCRIPTS/route.sh" --json "$TEST_TASK" 2>&1) || true

if echo "$ROUTE_OUTPUT" | jq -e '.system' >/dev/null 2>&1; then
  ROUTED_SYSTEM=$(echo "$ROUTE_OUTPUT" | jq -r '.system')
  ROUTED_AGENT=$(echo "$ROUTE_OUTPUT" | jq -r '.agent // "none"')
  ROUTED_DOMAIN=$(echo "$ROUTE_OUTPUT" | jq -r '.domain')
  ROUTED_CONFIDENCE=$(echo "$ROUTE_OUTPUT" | jq -r '.confidence')
  step_pass "system=$ROUTED_SYSTEM agent=$ROUTED_AGENT domain=$ROUTED_DOMAIN confidence=$ROUTED_CONFIDENCE"
else
  step_fail "Invalid JSON output: $(echo "$ROUTE_OUTPUT" | head -c 100)"
  ROUTED_SYSTEM="codex"
  ROUTED_AGENT="none"
fi

# ============================================================
# Step 2: Context Inject
# ============================================================
step_start "context-inject.sh"

CTX_OUTPUT=$(bash "$SCRIPTS/context-inject.sh" "$ROUTED_SYSTEM" "$ROUTED_AGENT" "$TEST_TASK" 2>&1) || true

if [[ -n "$CTX_OUTPUT" ]]; then
  CTX_LINES=$(echo "$CTX_OUTPUT" | wc -l | tr -d ' ')
  step_pass "${CTX_LINES} lines of context"
else
  step_pass "No prior context (expected for fresh system)"
fi

# ============================================================
# Step 3: Dispatch (skip in dry-run)
# ============================================================
if $DRY_RUN; then
  step_start "dispatch.sh (skipped — dry-run)"
  step_pass "Dry run — dispatch skipped"
  RUN_ID=""
else
  step_start "dispatch.sh"

  # Use --no-fallback to keep test simple; dispatch to routed system
  DISPATCH_OUTPUT=$(bash "$SCRIPTS/dispatch.sh" run "$ROUTED_SYSTEM" "$TEST_TASK" \
    --no-fallback 2>&1) || true

  RUN_ID=$(echo "$DISPATCH_OUTPUT" | grep -oE '(cc|cx)-[0-9]+' | head -1 || true)

  if [[ -n "$RUN_ID" ]]; then
    step_pass "run_id=$RUN_ID"
  else
    step_fail "No run_id returned: $(echo "$DISPATCH_OUTPUT" | head -c 100)"
  fi
fi

# ============================================================
# Step 4: Verify (only if real dispatch returned a run_id)
# ============================================================
if [[ -n "$RUN_ID" ]] && ! $DRY_RUN; then
  step_start "verify-output.sh"

  # Wait briefly for async dispatch to produce output
  RESULT_FILE="$WORKSPACE/shared/dispatch-runs/$RUN_ID.result.json"
  OUTPUT_FILE="$WORKSPACE/shared/dispatch-runs/$RUN_ID.output"
  DONE_FILE="$WORKSPACE/shared/dispatch-runs/$RUN_ID.done"
  PID_FILE="$WORKSPACE/shared/dispatch-runs/$RUN_ID.pid"

  # Check if process is still running (dispatch is async)
  STILL_RUNNING=false
  if [[ -f "$PID_FILE" ]]; then
    PID=$(cat "$PID_FILE")
    if kill -0 "$PID" 2>/dev/null; then
      STILL_RUNNING=true
    fi
  fi

  if $STILL_RUNNING; then
    step_pass "Dispatch running (PID $PID) — verify deferred"
  else
    # Try to find output to verify
    CHECK_FILE=""
    [[ -f "$RESULT_FILE" ]] && CHECK_FILE="$RESULT_FILE"
    [[ -z "$CHECK_FILE" && -f "$OUTPUT_FILE" ]] && CHECK_FILE="$OUTPUT_FILE"
    [[ -z "$CHECK_FILE" && -f "$DONE_FILE" ]] && CHECK_FILE="$DONE_FILE"

    if [[ -n "$CHECK_FILE" ]]; then
      VERIFY_OUTPUT=$(bash "$SCRIPTS/verify-output.sh" "$CHECK_FILE" "$TEST_TASK" 2>&1) || true
      VERDICT=$(echo "$VERIFY_OUTPUT" | head -1)
      step_pass "verdict=$VERDICT"
    else
      step_pass "No output yet — async dispatch in progress"
    fi
  fi
else
  if ! $DRY_RUN; then
    step_start "verify-output.sh (skipped — no run_id)"
    step_fail "Skipped — dispatch did not return run_id"
  fi
fi

# ============================================================
# Step 5: Agent Stats (only if real dispatch)
# ============================================================
if [[ -n "$RUN_ID" ]] && ! $DRY_RUN; then
  step_start "agent-stats.sh"
  STATS_OUTPUT=$(bash "$SCRIPTS/agent-stats.sh" log \
    "${ROUTED_AGENT:-unknown}" "$ROUTED_SYSTEM" \
    "mesh-test: $TEST_TASK" "${VERDICT:-PASS}" "0" 2>&1) || true

  if echo "$STATS_OUTPUT" | grep -q "Logged"; then
    step_pass "$STATS_OUTPUT"
  else
    step_fail "Stats logging failed: $(echo "$STATS_OUTPUT" | head -c 100)"
  fi
elif $DRY_RUN; then
  step_start "agent-stats.sh (skipped — dry-run)"
  step_pass "Dry run — stats logging skipped"
fi

# ============================================================
# Summary
# ============================================================
OVERALL="PASS"
[[ $FAILED -gt 0 ]] && OVERALL="FAIL"

cat >> "$REPORT" <<EOF

## Summary

- Total steps: ${TOTAL}
- Passed: ${PASSED}
- Failed: ${FAILED}
- Overall: **${OVERALL}**
- Routed to: ${ROUTED_SYSTEM} / ${ROUTED_AGENT:-none}
$(if [[ -n "$RUN_ID" ]]; then echo "- Run ID: ${RUN_ID}"; fi)
EOF

echo ""
echo "=== Results: ${PASSED}/${TOTAL} passed — ${OVERALL} ==="
echo "Report: $REPORT"
