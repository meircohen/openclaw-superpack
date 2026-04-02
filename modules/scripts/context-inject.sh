#!/usr/bin/env bash
# context-inject.sh — Cross-system context injection for dispatch prompts
#
# Gathers relevant context before a dispatch:
#   - Recent tasks to same system/agent from dispatch-log/
#   - Relevant corrections from corrections/
#   - Agent stats and known issues from agent-stats/
#
# Output: A context block (max ~500 words) to prepend to dispatch prompts.
#
# Usage:
#   bash scripts/context-inject.sh <system> [agent] [task-description]
#   bash scripts/context-inject.sh claude-code security-auditor "Review auth code"

set -euo pipefail

WORKSPACE="/Users/meircohen/.openclaw/workspace"
DISPATCH_LOG="$WORKSPACE/shared/dispatch-log"
CORRECTIONS_DIR="$WORKSPACE/shared/corrections"
STATS_DIR="$WORKSPACE/shared/agent-stats"

SYSTEM="${1:?Usage: context-inject.sh <system> [agent] [task-description]}"
AGENT="${2:-}"
TASK_DESC="${3:-}"

MAX_WORDS=500
CTX=""

# ============================================================
# Section 1: Recent tasks to this system/agent
# ============================================================
gather_recent_tasks() {
  local section=""
  local count=0

  # Search recent dispatch logs (last 7 days)
  for i in $(seq 0 6); do
    local date_str
    date_str=$(date -v-${i}d +%Y-%m-%d 2>/dev/null || date -d "-${i} days" +%Y-%m-%d 2>/dev/null || continue)
    local log_file="$DISPATCH_LOG/${date_str}.jsonl"
    [[ -f "$log_file" ]] || continue

    while IFS= read -r line; do
      local target agent_val status
      target=$(echo "$line" | jq -r '.target // ""' 2>/dev/null)
      [[ "$target" == "$SYSTEM" ]] || continue

      if [[ -n "$AGENT" ]]; then
        agent_val=$(echo "$line" | jq -r '.agent // ""' 2>/dev/null)
        [[ "$agent_val" == "$AGENT" || "$agent_val" == "none" ]] || continue
      fi

      status=$(echo "$line" | jq -r '.status // .completed // ""' 2>/dev/null)
      local run_id started
      run_id=$(echo "$line" | jq -r '.run_id // "?"' 2>/dev/null)
      started=$(echo "$line" | jq -r '.started // .completed // "?"' 2>/dev/null)

      section="${section}- ${started}: ${run_id} (${status})\n"
      count=$((count + 1))
      [[ $count -ge 5 ]] && break 2
    done < "$log_file"
  done

  if [[ $count -gt 0 ]]; then
    echo "### Recent dispatches to ${SYSTEM}${AGENT:+ (agent: $AGENT)}:"
    echo -e "$section"
  fi
}

# ============================================================
# Section 2: Relevant corrections
# ============================================================
gather_corrections() {
  local target_file=""

  # Check system-level corrections
  if [[ -f "$CORRECTIONS_DIR/${SYSTEM}.jsonl" ]]; then
    target_file="$CORRECTIONS_DIR/${SYSTEM}.jsonl"
  fi

  # Check agent-level corrections (more specific)
  if [[ -n "$AGENT" && -f "$CORRECTIONS_DIR/${AGENT}.jsonl" ]]; then
    target_file="$CORRECTIONS_DIR/${AGENT}.jsonl"
  fi

  if [[ -z "$target_file" ]]; then
    return 0
  fi

  echo "### Known corrections (DO NOT REPEAT):"

  # If task description given, try to find relevant corrections
  if [[ -n "$TASK_DESC" ]]; then
    local task_lower
    task_lower=$(echo "$TASK_DESC" | tr '[:upper:]' '[:lower:]')
    local found=0

    while IFS= read -r line; do
      local what_lower
      what_lower=$(echo "$line" | jq -r '.what // ""' 2>/dev/null | tr '[:upper:]' '[:lower:]')
      # Check for any keyword overlap between task and correction
      for word in $(echo "$task_lower" | tr -cs '[:alpha:]' '\n' | awk 'length > 3'); do
        if echo "$what_lower" | grep -q "$word"; then
          local cat what fix
          cat=$(echo "$line" | jq -r '.category // "?"' 2>/dev/null)
          what=$(echo "$line" | jq -r '.what // "?"' 2>/dev/null)
          fix=$(echo "$line" | jq -r '.correction // "?"' 2>/dev/null)
          echo "- [$cat] $what → $fix"
          found=$((found + 1))
          break
        fi
      done
      [[ $found -ge 5 ]] && break
    done < "$target_file"

    # If no relevant corrections found, show most recent
    if [[ $found -eq 0 ]]; then
      tail -3 "$target_file" | while IFS= read -r line; do
        local cat what fix
        cat=$(echo "$line" | jq -r '.category // "?"' 2>/dev/null)
        what=$(echo "$line" | jq -r '.what // "?"' 2>/dev/null)
        fix=$(echo "$line" | jq -r '.correction // "?"' 2>/dev/null)
        echo "- [$cat] $what → $fix"
      done
    fi
  else
    # No task description — show last 5 corrections
    tail -5 "$target_file" | while IFS= read -r line; do
      local cat what fix
      cat=$(echo "$line" | jq -r '.category // "?"' 2>/dev/null)
      what=$(echo "$line" | jq -r '.what // "?"' 2>/dev/null)
      fix=$(echo "$line" | jq -r '.correction // "?"' 2>/dev/null)
      echo "- [$cat] $what → $fix"
    done
  fi

  echo ""
}

# ============================================================
# Section 3: Agent performance summary & known issues
# ============================================================
gather_agent_stats() {
  local target="$SYSTEM"
  [[ -n "$AGENT" ]] && target="$AGENT"

  local stats_file="$STATS_DIR/${target}.jsonl"
  [[ -f "$stats_file" ]] || return 0

  local total pass warn fail
  total=$(wc -l < "$stats_file" | tr -d ' ')
  pass=$(grep -c '"verdict":"PASS"' "$stats_file" || true)
  warn=$(grep -c '"verdict":"WARN"' "$stats_file" || true)
  fail=$(grep -c '"verdict":"FAIL"' "$stats_file" || true)
  pass=${pass:-0}; warn=${warn:-0}; fail=${fail:-0}

  echo "### Agent performance ($target):"
  echo "- Track record: ${total} tasks — ${pass} PASS, ${warn} WARN, ${fail} FAIL"

  if [[ $fail -gt 0 ]]; then
    echo "- Recent failures:"
    grep '"verdict":"FAIL"' "$stats_file" | tail -3 | while IFS= read -r line; do
      local task ts
      task=$(echo "$line" | jq -r '.task // "?"' 2>/dev/null | head -c 80)
      ts=$(echo "$line" | jq -r '.timestamp // "?"' 2>/dev/null)
      echo "  - $ts: $task"
    done
  fi

  echo ""
}

# ============================================================
# Assemble context block
# ============================================================
CTX_BLOCK=$(
  echo "PREVIOUS CONTEXT:"
  echo ""
  gather_recent_tasks || true
  gather_corrections || true
  gather_agent_stats || true
)

# Trim to max word count
WORD_COUNT=$(echo "$CTX_BLOCK" | wc -w | tr -d ' ')
if [[ $WORD_COUNT -gt $MAX_WORDS ]]; then
  CTX_BLOCK=$(echo "$CTX_BLOCK" | head -c 3000)
  CTX_BLOCK="${CTX_BLOCK}
...
(context truncated to stay within token budget)"
fi

# Only output if there's actual context beyond the header
LINE_COUNT=$(echo "$CTX_BLOCK" | wc -l | tr -d ' ')
if [[ $LINE_COUNT -le 2 ]]; then
  echo "# No prior context available for ${SYSTEM}${AGENT:+/$AGENT}"
else
  echo "$CTX_BLOCK"
fi
