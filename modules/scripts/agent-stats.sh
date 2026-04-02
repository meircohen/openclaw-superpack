#!/usr/bin/env bash
# agent-stats.sh — Agent performance tracking for the OpenClaw mesh
#
# Tracks task completions, verdicts, durations, and corrections per agent.
# Data stored as JSONL in shared/agent-stats/ (one file per agent).
#
# Usage:
#   bash scripts/agent-stats.sh log <agent> <system> "<task-summary>" <verdict> <duration>
#   bash scripts/agent-stats.sh report [agent]
#   bash scripts/agent-stats.sh corrections [agent]
#   bash scripts/agent-stats.sh rankings

set -euo pipefail

WORKSPACE="/Users/meircohen/.openclaw/workspace"
STATS_DIR="$WORKSPACE/shared/agent-stats"
CORRECTIONS_DIR="$WORKSPACE/shared/corrections"
mkdir -p "$STATS_DIR"

ACTION="${1:-help}"

# ============================================================
# log — Record a completed task
# ============================================================
cmd_log() {
  local agent="${1:?Usage: agent-stats.sh log <agent> <system> <task-summary> <verdict> <duration>}"
  local system="${2:?Missing system (claude-code|codex)}"
  local task_summary="${3:?Missing task summary}"
  local verdict="${4:?Missing verdict (PASS|WARN|FAIL)}"
  local duration="${5:?Missing duration in seconds}"

  local file="$STATS_DIR/${agent}.jsonl"
  local entry
  entry=$(jq -cn \
    --arg agent "$agent" \
    --arg system "$system" \
    --arg task "$task_summary" \
    --arg verdict "$verdict" \
    --arg duration "$duration" \
    --arg ts "$(date -u +%Y-%m-%dT%H:%M:%SZ)" \
    '{timestamp: $ts, agent: $agent, system: $system, task: $task, verdict: $verdict, duration: ($duration | tonumber)}')

  echo "$entry" >> "$file"
  echo "Logged: $agent ($system) — $verdict — ${duration}s"
}

# ============================================================
# report — Show stats for one or all agents
# ============================================================
cmd_report() {
  local target_agent="${1:-}"

  if [[ -n "$target_agent" ]]; then
    report_agent "$target_agent"
  else
    for f in "$STATS_DIR"/*.jsonl; do
      [[ -f "$f" ]] || continue
      report_agent "$(basename "$f" .jsonl)"
      echo ""
    done
    if ! ls "$STATS_DIR"/*.jsonl &>/dev/null; then
      echo "No agent stats recorded yet."
    fi
  fi
}

report_agent() {
  local agent="$1"
  local file="$STATS_DIR/${agent}.jsonl"

  if [[ ! -f "$file" ]]; then
    echo "No stats for agent: $agent"
    return
  fi

  local total pass warn fail avg_dur
  total=$(wc -l < "$file" | tr -d ' ')
  pass=$(grep -c '"verdict":"PASS"' "$file" || true)
  warn=$(grep -c '"verdict":"WARN"' "$file" || true)
  fail=$(grep -c '"verdict":"FAIL"' "$file" || true)
  pass=${pass:-0}; warn=${warn:-0}; fail=${fail:-0}

  avg_dur=$(jq -s 'if length > 0 then (map(.duration) | add / length | . * 10 | floor / 10) else 0 end' "$file" 2>/dev/null || echo 0)

  local success_rate=0
  if [[ $total -gt 0 ]]; then
    success_rate=$(( (pass + warn) * 100 / total ))
  fi

  local corrections=0
  if [[ -f "$CORRECTIONS_DIR/${agent}.jsonl" ]]; then
    corrections=$(wc -l < "$CORRECTIONS_DIR/${agent}.jsonl" | tr -d ' ')
  fi

  echo "=== $agent ==="
  echo "  Total tasks:   $total"
  echo "  PASS:          $pass"
  echo "  WARN:          $warn"
  echo "  FAIL:          $fail"
  echo "  Success rate:  ${success_rate}%"
  echo "  Avg duration:  ${avg_dur}s"
  echo "  Corrections:   $corrections"

  # Show recent tasks
  if [[ $total -gt 0 ]]; then
    echo "  Recent:"
    tail -3 "$file" | while IFS= read -r line; do
      local ts task verdict dur
      ts=$(echo "$line" | jq -r '.timestamp // "?"' 2>/dev/null)
      task=$(echo "$line" | jq -r '.task // "?"' 2>/dev/null | head -c 60)
      verdict=$(echo "$line" | jq -r '.verdict // "?"' 2>/dev/null)
      dur=$(echo "$line" | jq -r '.duration // "?"' 2>/dev/null)
      echo "    [$ts] $verdict (${dur}s) — $task"
    done
  fi
}

# ============================================================
# corrections — Show correction history for an agent
# ============================================================
cmd_corrections() {
  local agent="${1:-}"

  if [[ -n "$agent" ]]; then
    if [[ -f "$CORRECTIONS_DIR/${agent}.jsonl" ]]; then
      echo "=== Corrections: $agent ==="
      while IFS= read -r line; do
        local ts cat what fix
        ts=$(echo "$line" | jq -r '.timestamp // "?"' 2>/dev/null)
        cat=$(echo "$line" | jq -r '.category // "?"' 2>/dev/null)
        what=$(echo "$line" | jq -r '.what // "?"' 2>/dev/null)
        fix=$(echo "$line" | jq -r '.correction // "?"' 2>/dev/null)
        echo "  [$ts] [$cat] $what → $fix"
      done < "$CORRECTIONS_DIR/${agent}.jsonl"
    else
      echo "No corrections for agent: $agent"
    fi
  else
    for f in "$CORRECTIONS_DIR"/*.jsonl; do
      [[ -f "$f" ]] || continue
      local a
      a=$(basename "$f" .jsonl)
      local count
      count=$(wc -l < "$f" | tr -d ' ')
      echo "$a: $count corrections"
      tail -3 "$f" | while IFS= read -r line; do
        local cat what
        cat=$(echo "$line" | jq -r '.category // "?"' 2>/dev/null)
        what=$(echo "$line" | jq -r '.what // "?"' 2>/dev/null | head -c 80)
        echo "  [$cat] $what"
      done
      echo ""
    done
  fi
}

# ============================================================
# rankings — Rank agents by success rate
# ============================================================
cmd_rankings() {
  echo "=== Agent Rankings (by success rate) ==="
  echo ""
  printf "%-20s %6s %6s %6s %6s %8s %8s %11s\n" \
    "AGENT" "TOTAL" "PASS" "WARN" "FAIL" "AVG(s)" "CORR" "SUCCESS%"
  printf "%-20s %6s %6s %6s %6s %8s %8s %11s\n" \
    "--------------------" "------" "------" "------" "------" "--------" "--------" "-----------"

  # Build ranking data, sort by success rate
  local tmpfile
  tmpfile=$(mktemp)

  for f in "$STATS_DIR"/*.jsonl; do
    [[ -f "$f" ]] || continue
    local agent total pass warn fail avg_dur corrections success_rate
    agent=$(basename "$f" .jsonl)
    total=$(wc -l < "$f" | tr -d ' ')
    pass=$(grep -c '"verdict":"PASS"' "$f" || true)
    warn=$(grep -c '"verdict":"WARN"' "$f" || true)
    fail=$(grep -c '"verdict":"FAIL"' "$f" || true)
    pass=${pass:-0}; warn=${warn:-0}; fail=${fail:-0}
    avg_dur=$(jq -s 'if length > 0 then (map(.duration) | add / length | . * 10 | floor / 10) else 0 end' "$f" 2>/dev/null || echo 0)

    corrections=0
    if [[ -f "$CORRECTIONS_DIR/${agent}.jsonl" ]]; then
      corrections=$(wc -l < "$CORRECTIONS_DIR/${agent}.jsonl" | tr -d ' ')
    fi

    success_rate=0
    if [[ $total -gt 0 ]]; then
      success_rate=$(( (pass + warn) * 100 / total ))
    fi

    echo "$success_rate $agent $total $pass $warn $fail $avg_dur $corrections" >> "$tmpfile"
  done

  if [[ ! -s "$tmpfile" ]]; then
    echo "(no agent data yet — run 'agent-stats.sh log' to start tracking)"
    rm -f "$tmpfile"
    return
  fi

  sort -rn "$tmpfile" | while read -r sr agent total pass warn fail avg_dur corrections; do
    printf "%-20s %6s %6s %6s %6s %8s %8s %10s%%\n" \
      "$agent" "$total" "$pass" "$warn" "$fail" "$avg_dur" "$corrections" "$sr"
  done

  rm -f "$tmpfile"
}

# ============================================================
# Main
# ============================================================
case "$ACTION" in
  log) shift; cmd_log "$@" ;;
  report) shift; cmd_report "${1:-}" ;;
  corrections) shift; cmd_corrections "${1:-}" ;;
  rankings) shift 2>/dev/null || true; cmd_rankings ;;
  help|*)
    echo "Usage: agent-stats.sh <log|report|corrections|rankings>"
    echo "  log <agent> <system> <task> <verdict> <duration>  — Record a task"
    echo "  report [agent]                                     — Show agent stats"
    echo "  corrections [agent]                                — Show corrections"
    echo "  rankings                                           — Rank by success rate"
    ;;
esac
