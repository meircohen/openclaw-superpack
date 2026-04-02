#!/usr/bin/env bash
# mesh-status.sh — Complete mesh overview in one command
#
# Shows: system health, recent dispatches, agent rankings,
# pending items, errors, and overall verdict.
#
# Usage: bash scripts/mesh-status.sh

set -euo pipefail
shopt -s nullglob

WORKSPACE="/Users/meircohen/.openclaw/workspace"
DISPATCH_LOG="$WORKSPACE/shared/dispatch-log"
STATS_DIR="$WORKSPACE/shared/agent-stats"
HANDOFFS_DIR="$WORKSPACE/shared/handoffs"
ESCALATIONS_DIR="$WORKSPACE/shared/escalations"
DISPATCH_RUNS="$WORKSPACE/shared/dispatch-runs"
LOGS_DIR="$WORKSPACE/logs"
CORRECTIONS_DIR="$WORKSPACE/shared/corrections"

DEGRADED=false
DOWN=false
TODAY=$(date +%Y-%m-%d)

# ============================================================
# System Health
# ============================================================
echo "MESH STATUS — $(date '+%Y-%m-%d %H:%M')"
echo "========================================"
echo ""
echo "SYSTEM HEALTH"
echo "--------"

# Claude Code CLI
if command -v claude >/dev/null 2>&1; then
  printf "  %-14s %s\n" "Claude Code:" "OK (CLI found)"
else
  printf "  %-14s %s\n" "Claude Code:" "MISSING"
  DEGRADED=true
fi

# Codex CLI
if command -v codex >/dev/null 2>&1; then
  printf "  %-14s %s\n" "Codex:" "OK (CLI found)"
else
  printf "  %-14s %s\n" "Codex:" "MISSING"
  DEGRADED=true
fi

# Dispatch daemon
DAEMON_RUNNING=false
if [[ -f "$LOGS_DIR/handoff-daemon.pid" ]]; then
  DPID=$(cat "$LOGS_DIR/handoff-daemon.pid" 2>/dev/null || true)
  if [[ -n "$DPID" ]] && kill -0 "$DPID" 2>/dev/null; then
    printf "  %-14s %s\n" "Daemon:" "RUNNING (PID $DPID)"
    DAEMON_RUNNING=true
  else
    printf "  %-14s %s\n" "Daemon:" "STOPPED"
  fi
else
  printf "  %-14s %s\n" "Daemon:" "NOT CONFIGURED"
fi

# Active dispatch processes
ACTIVE_COUNT=0
for pf in "$DISPATCH_RUNS"/*.pid; do
  [[ -f "$pf" ]] || continue
  pid=$(cat "$pf" 2>/dev/null || true)
  [[ -n "$pid" ]] && kill -0 "$pid" 2>/dev/null && ACTIVE_COUNT=$((ACTIVE_COUNT + 1))
done
printf "  %-14s %s\n" "Active runs:" "$ACTIVE_COUNT"

echo ""

# ============================================================
# Recent Dispatches (last 5)
# ============================================================
echo "RECENT DISPATCHES"
echo "--------"

LOG_FILE="$DISPATCH_LOG/${TODAY}.jsonl"
if [[ -f "$LOG_FILE" ]]; then
  DISPATCH_COUNT=$(wc -l < "$LOG_FILE" | tr -d ' ')
  tail -5 "$LOG_FILE" | while IFS= read -r line; do
    rid=$(echo "$line" | jq -r '.run_id // "?"' 2>/dev/null)
    tgt=$(echo "$line" | jq -r '.target // "?"' 2>/dev/null)
    sts=$(echo "$line" | jq -r '.status // "?"' 2>/dev/null)
    ts=$(echo "$line" | jq -r '.started // .completed // "?"' 2>/dev/null)
    ts_short=$(echo "$ts" | sed 's/T/ /;s/Z//')
    printf "  %-12s %-14s %-10s %s\n" "$rid" "$tgt" "$sts" "$ts_short"
  done
  echo "  ($DISPATCH_COUNT total today)"
else
  echo "  (none today)"
fi

echo ""

# ============================================================
# Agent Rankings (top 5 + bottom 5)
# ============================================================
echo "AGENT RANKINGS"
echo "--------"

RANK_TMP=$(mktemp)
for f in "$STATS_DIR"/*.jsonl; do
  [[ -f "$f" ]] || continue
  agent=$(basename "$f" .jsonl)
  total=$(wc -l < "$f" | tr -d ' ')
  pass=$(grep -c '"verdict":"PASS"' "$f" 2>/dev/null || true)
  warn=$(grep -c '"verdict":"WARN"' "$f" 2>/dev/null || true)
  fail=$(grep -c '"verdict":"FAIL"' "$f" 2>/dev/null || true)
  pass=${pass:-0}; warn=${warn:-0}; fail=${fail:-0}
  rate=0
  [[ $total -gt 0 ]] && rate=$(( (pass + warn) * 100 / total ))
  echo "$rate $agent $total $pass $fail" >> "$RANK_TMP"
done

if [[ -s "$RANK_TMP" ]]; then
  AGENT_COUNT=$(wc -l < "$RANK_TMP" | tr -d ' ')
  printf "  %-20s %5s %5s %5s %6s\n" "AGENT" "TOTAL" "PASS" "FAIL" "RATE"

  # Top 5
  sort -rn "$RANK_TMP" | head -5 | while read -r rate agent total pass fail; do
    printf "  %-20s %5s %5s %5s %5s%%\n" "$agent" "$total" "$pass" "$fail" "$rate"
  done

  # Bottom 5 (only if more than 5 agents)
  if [[ $AGENT_COUNT -gt 5 ]]; then
    echo "  ---"
    sort -rn "$RANK_TMP" | tail -5 | while read -r rate agent total pass fail; do
      printf "  %-20s %5s %5s %5s %5s%%\n" "$agent" "$total" "$pass" "$fail" "$rate"
    done
  fi
else
  echo "  (no agent data yet)"
fi
rm -f "$RANK_TMP"

echo ""

# ============================================================
# Pending Items
# ============================================================
echo "PENDING ITEMS"
echo "--------"

# Pending handoffs
PENDING_HO=0
DISPATCHED_HO=0
for hf in "$HANDOFFS_DIR"/*.json; do
  [[ -f "$hf" ]] || continue
  sts=$(jq -r '.status // "unknown"' "$hf" 2>/dev/null)
  case "$sts" in
    pending) PENDING_HO=$((PENDING_HO + 1)) ;;
    dispatched) DISPATCHED_HO=$((DISPATCHED_HO + 1)) ;;
  esac
done
printf "  %-20s %s\n" "Pending handoffs:" "$PENDING_HO"
printf "  %-20s %s\n" "In-flight:" "$DISPATCHED_HO"

# Escalations
ESC_COUNT=0
for ef in "$ESCALATIONS_DIR"/*.json; do
  [[ -f "$ef" ]] || continue
  sts=$(jq -r '.status // ""' "$ef" 2>/dev/null)
  [[ "$sts" == "open" ]] && ESC_COUNT=$((ESC_COUNT + 1))
done
printf "  %-20s %s\n" "Open escalations:" "$ESC_COUNT"
[[ $ESC_COUNT -gt 0 ]] && DEGRADED=true

# Undelivered replies
REPLY_COUNT=0
for rf in "$WORKSPACE/shared/replies"/*.md; do
  [[ -f "$rf" ]] || continue
  REPLY_COUNT=$((REPLY_COUNT + 1))
done
printf "  %-20s %s\n" "Unread replies:" "$REPLY_COUNT"

echo ""

# ============================================================
# Errors (recent failures)
# ============================================================
echo "RECENT ERRORS"
echo "--------"

VERIFY_LOG="$DISPATCH_LOG/verify-${TODAY}.jsonl"
ERROR_COUNT=0
if [[ -f "$VERIFY_LOG" ]]; then
  FAIL_LINES=$(grep '"verdict":"FAIL"' "$VERIFY_LOG" 2>/dev/null || true)
  if [[ -n "$FAIL_LINES" ]]; then
    echo "$FAIL_LINES" | tail -3 | while IFS= read -r line; do
      rid=$(echo "$line" | jq -r '.run_id // "?"' 2>/dev/null)
      notes=$(echo "$line" | jq -r '.notes // ""' 2>/dev/null | head -c 60)
      printf "  %-14s %s\n" "$rid" "$notes"
      ERROR_COUNT=$((ERROR_COUNT + 1))
    done
  fi
fi

# Check daemon log for recent errors
if [[ -f "$LOGS_DIR/handoff-daemon.log" ]]; then
  DAEMON_ERRS=$(grep -i "error\|fail" "$LOGS_DIR/handoff-daemon.log" 2>/dev/null | tail -2 || true)
  if [[ -n "$DAEMON_ERRS" ]]; then
    echo "$DAEMON_ERRS" | while IFS= read -r line; do
      printf "  daemon: %s\n" "$(echo "$line" | head -c 70)"
    done
  fi
fi

if [[ $ERROR_COUNT -eq 0 ]] && [[ -z "${DAEMON_ERRS:-}" ]]; then
  echo "  (none)"
fi

echo ""

# ============================================================
# Verdict
# ============================================================
if $DOWN; then
  echo "MESH: DOWN"
elif $DEGRADED; then
  echo "MESH: DEGRADED"
else
  echo "MESH: OPERATIONAL"
fi
