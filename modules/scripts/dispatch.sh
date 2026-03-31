#!/usr/bin/env bash
# dispatch.sh -- Auto-dispatch pending handoffs to Claude Code or Codex via CLI
#
# Usage:
#   bash scripts/dispatch.sh check       # Check for pending handoffs, dispatch if found
#   bash scripts/dispatch.sh run <target> "<prompt>" [--agent <slug>] [--timeout <secs>] [--no-fallback]
#   bash scripts/dispatch.sh status      # Show running dispatches
#
# Features:
#   - Context injection: every dispatch gets relevant prior context prepended
#   - Results verification: outputs are quality-checked before marking complete
#   - Fallback routing: if primary system fails/times out, retries on alternate
#   - Agent stats logging: verdicts and durations tracked per agent
#
# This is the bridge that makes the mesh truly autonomous.
# The orchestrator's heartbeat calls `dispatch.sh check` to auto-execute pending handoffs.

set -euo pipefail

WORKSPACE="${OPENCLAW_WORKSPACE:-$HOME/.openclaw/workspace}"
HANDOFFS_DIR="$WORKSPACE/shared/handoffs"
DISPATCH_LOG="$WORKSPACE/shared/dispatch-log"
DISPATCH_RUNS="$WORKSPACE/shared/dispatch-runs"
CORRECTIONS_DIR="$WORKSPACE/shared/corrections"
ESCALATIONS_DIR="$WORKSPACE/shared/escalations"

mkdir -p "$DISPATCH_LOG" "$DISPATCH_RUNS" "$ESCALATIONS_DIR"

# Global flags (can be overridden by CLI args)
DISPATCH_TIMEOUT="${DISPATCH_TIMEOUT:-120}"
FALLBACK_ENABLED=true

# Parse global flags before action
ARGS=()
while [[ $# -gt 0 ]]; do
  case "$1" in
    --timeout) DISPATCH_TIMEOUT="$2"; shift 2 ;;
    --no-fallback) FALLBACK_ENABLED=false; shift ;;
    *) ARGS+=("$1"); shift ;;
  esac
done
set -- "${ARGS[@]+"${ARGS[@]}"}"

ACTION="${1:-check}"

# ============================================================
# inject_context -- Prepend relevant context to a dispatch prompt
# ============================================================
inject_context() {
  local system="$1"
  local agent="${2:-}"
  local task_desc="${3:-}"
  local ctx
  ctx=$(bash "$WORKSPACE/scripts/context-inject.sh" "$system" "$agent" "$task_desc" 2>/dev/null || echo "")
  echo "$ctx"
}

notify_completion() {
  local task_id="$1"
  local system="$2"
  local agent="$3"
  local summary="$4"
  local status="$5"
  local quiet="${6:-false}"
  local cmd=(bash "$WORKSPACE/scripts/notify-complete.sh")

  if [[ "$quiet" == "true" ]]; then
    cmd+=(--quiet)
  fi

  cmd+=("$task_id" "$system" "$agent" "$summary" "$status")
  "${cmd[@]}" >/dev/null 2>&1 || true
}

build_summary() {
  local default_text="$1"
  shift || true
  local summary=""

  for candidate in "$@"; do
    [[ -f "$candidate" ]] || continue
    if [[ "$candidate" == *.json ]]; then
      summary=$(jq -r '.result // .output // .content // empty' "$candidate" 2>/dev/null || true)
    else
      summary=$(cat "$candidate" 2>/dev/null || true)
    fi
    summary=$(printf '%s' "$summary" | tr '\n' ' ' | sed 's/[[:space:]]\+/ /g' | cut -c1-240)
    [[ -n "$summary" ]] && break
  done

  if [[ -z "$summary" ]]; then
    summary="$default_text"
  fi

  echo "$summary"
}

is_quiet_priority() {
  local handoff_file="$1"
  local priority
  priority=$(jq -r '.priority // empty' "$handoff_file" 2>/dev/null || true)
  [[ "$priority" == "low" || "$priority" == "P3" ]]
}

# ============================================================
# dispatch_claude_code -- Run a task via Claude Code CLI
# ============================================================
dispatch_claude_code() {
  local prompt="$1"
  local handoff_file="${2:-}"
  local agent="${3:-}"
  local run_id="cc-$(date +%s)"
  local log_file="$DISPATCH_RUNS/$run_id.log"
  local result_file="$DISPATCH_RUNS/$run_id.result.json"

  echo "[$run_id] Dispatching to Claude Code${agent:+ (agent: $agent)}..." >&2

  # Build persona preamble if agent specified
  local persona_preamble=""
  if [[ -n "$agent" ]]; then
    local soul_file="$HOME/.openclaw/workspace-${agent}/SOUL.md"
    if [[ -f "$soul_file" ]]; then
      persona_preamble="Read $soul_file and fully adopt that persona. Then: "
    else
      echo "WARN: Agent soul file not found at $soul_file, proceeding without persona" >&2
    fi
  fi

  # Inject cross-system context
  local context_block
  context_block=$(inject_context "claude-code" "$agent" "$prompt")

  # Build the full prompt with startup context
  local full_prompt="Read $HOME/.openclaw/workspace/shared/CLAUDE-CODE-STARTUP.md first, then read $HOME/.openclaw/workspace/shared/ROUTING.md for routing rules. Check $HOME/.openclaw/workspace/shared/corrections/claude-code.md for corrections to avoid.

${context_block:+$context_block

}${persona_preamble}Then execute this task:

$prompt

When done, write a summary of what you did to $HOME/.openclaw/workspace/shared/dispatch-runs/$run_id.done"

  # Run non-interactively
  claude -p "$full_prompt" \
    --dangerously-skip-permissions \
    --max-turns 25 \
    --output-format json \
    --add-dir "$WORKSPACE" \
    > "$result_file" 2>"$log_file" &

  local pid=$!
  echo "$pid" > "$DISPATCH_RUNS/$run_id.pid"

  # Log the dispatch
  echo "{\"run_id\":\"$run_id\",\"target\":\"claude-code\",\"agent\":\"${agent:-none}\",\"pid\":$pid,\"handoff\":\"$handoff_file\",\"started\":\"$(date -u +%Y-%m-%dT%H:%M:%SZ)\",\"status\":\"running\"}" \
    >> "$DISPATCH_LOG/$(date +%Y-%m-%d).jsonl"

  echo "[$run_id] Claude Code dispatched (PID: $pid)" >&2
  echo "$run_id"
}

# ============================================================
# dispatch_codex -- Run a task via Codex CLI
# ============================================================
dispatch_codex() {
  local prompt="$1"
  local handoff_file="${2:-}"
  local agent="${3:-}"
  local run_id="cx-$(date +%s)"
  local log_file="$DISPATCH_RUNS/$run_id.log"

  echo "[$run_id] Dispatching to Codex${agent:+ (agent: $agent)}..." >&2

  # Build persona preamble if agent specified
  local persona_preamble=""
  if [[ -n "$agent" ]]; then
    local catalog_file="$HOME/.codex/agent-catalog/${agent}.md"
    if [[ -f "$catalog_file" ]]; then
      persona_preamble="Read $catalog_file and fully adopt that persona. Then: "
    else
      echo "WARN: Agent catalog file not found at $catalog_file, proceeding without persona" >&2
    fi
  fi

  # Inject cross-system context
  local context_block
  context_block=$(inject_context "codex" "$agent" "$prompt")

  # Build the full prompt with startup context
  local full_prompt="Read $HOME/.openclaw/workspace/shared/CODEX-STARTUP.md first, then read $HOME/.openclaw/workspace/shared/ROUTING.md for routing rules. Check $HOME/.openclaw/workspace/shared/corrections/codex.md for corrections to avoid.

${context_block:+$context_block

}${persona_preamble}Then execute this task:

$prompt

When done, write a summary of what you did to $HOME/.openclaw/workspace/shared/dispatch-runs/$run_id.done"

  # Run non-interactively with workspace write access
  codex exec \
    --sandbox workspace-write \
    -C "$WORKSPACE" \
    "$full_prompt" \
    > "$DISPATCH_RUNS/$run_id.output" 2>"$log_file" &

  local pid=$!
  echo "$pid" > "$DISPATCH_RUNS/$run_id.pid"

  # Log the dispatch
  echo "{\"run_id\":\"$run_id\",\"target\":\"codex\",\"agent\":\"${agent:-none}\",\"pid\":$pid,\"handoff\":\"$handoff_file\",\"started\":\"$(date -u +%Y-%m-%dT%H:%M:%SZ)\",\"status\":\"running\"}" \
    >> "$DISPATCH_LOG/$(date +%Y-%m-%d).jsonl"

  echo "[$run_id] Codex dispatched (PID: $pid)" >&2
  echo "$run_id"
}

# ============================================================
# check -- Find pending handoffs and auto-dispatch
# ============================================================
check_and_dispatch() {
  local dispatched=0

  for handoff in "$HANDOFFS_DIR"/*.json; do
    [[ -f "$handoff" ]] || continue

    local status=$(jq -r '.status // "unknown"' "$handoff")
    [[ "$status" == "pending" ]] || continue

    local target=$(jq -r '.to // "unknown"' "$handoff")
    local title=$(jq -r '.title // "untitled"' "$handoff")
    local handoff_basename=$(basename "$handoff")

    # Only auto-dispatch to claude-code and codex
    case "$target" in
      claude-code)
        # Read the full handoff spec if a .md companion exists
        local md_file="${handoff%.json}"
        md_file="${md_file}.md"
        local task_prompt="Pick up handoff: $title"

        if [[ -f "$md_file" ]]; then
          task_prompt="Read the full handoff spec at $md_file and execute it. Title: $title"
        fi

        local run_id=$(dispatch_claude_code "$task_prompt" "$handoff_basename")

        # Mark handoff as dispatched (not complete -- we verify after)
        jq '.status = "dispatched" | .dispatched_at = "'"$(date -u +%Y-%m-%dT%H:%M:%SZ)"'" | .dispatch_run_id = "'"$run_id"'" | .dispatch_agent = (.agent // .dispatch_agent)' "$handoff" > "${handoff}.tmp" && mv "${handoff}.tmp" "$handoff"

        echo "Dispatched '$title' to Claude Code (run: $run_id)"
        dispatched=$((dispatched + 1))
        ;;

      codex)
        local md_file="${handoff%.json}"
        md_file="${md_file}.md"
        local task_prompt="Pick up handoff: $title"

        if [[ -f "$md_file" ]]; then
          task_prompt="Read the full handoff spec at $md_file and execute it. Title: $title"
        fi

        local run_id=$(dispatch_codex "$task_prompt" "$handoff_basename")

        jq '.status = "dispatched" | .dispatched_at = "'"$(date -u +%Y-%m-%dT%H:%M:%SZ)"'" | .dispatch_run_id = "'"$run_id"'" | .dispatch_agent = (.agent // .dispatch_agent)' "$handoff" > "${handoff}.tmp" && mv "${handoff}.tmp" "$handoff"

        echo "Dispatched '$title' to Codex (run: $run_id)"
        dispatched=$((dispatched + 1))
        ;;

      openclaw)
        # Orchestrator handles its own handoffs via heartbeat, skip
        ;;

      *)
        echo "WARN: Unknown target '$target' in handoff: $handoff_basename" >&2
        ;;
    esac
  done

  if [[ $dispatched -eq 0 ]]; then
    echo "No pending handoffs to dispatch"
  else
    echo "Dispatched $dispatched handoff(s)"
  fi
}

# ============================================================
# check_completed -- Verify dispatched runs finished
# ============================================================
check_completed() {
  local checked=0

  for handoff in "$HANDOFFS_DIR"/*.json; do
    [[ -f "$handoff" ]] || continue

    local status=$(jq -r '.status // "unknown"' "$handoff")
    [[ "$status" == "dispatched" ]] || continue

    local run_id=$(jq -r '.dispatch_run_id // ""' "$handoff")
    [[ -n "$run_id" ]] || continue

    local pid_file="$DISPATCH_RUNS/$run_id.pid"
    local done_file="$DISPATCH_RUNS/$run_id.done"

    # Check if process is still running
    if [[ -f "$pid_file" ]]; then
      local pid=$(cat "$pid_file")
      if kill -0 "$pid" 2>/dev/null; then
        echo "[$run_id] Still running (PID: $pid)"
        continue
      fi
    fi

    # Process finished -- check if it wrote a .done file
    local title=$(jq -r '.title // "untitled"' "$handoff")
    local target=$(jq -r '.to // "unknown"' "$handoff")
    local dispatched_at=$(jq -r '.dispatched_at // ""' "$handoff")
    local now_epoch=$(date +%s)
    local duration=0
    if [[ -n "$dispatched_at" ]]; then
      local start_epoch=$(date -j -f "%Y-%m-%dT%H:%M:%SZ" "$dispatched_at" +%s 2>/dev/null || echo "$now_epoch")
      duration=$((now_epoch - start_epoch))
    fi

    if [[ -f "$done_file" ]]; then
      # Run verification on the result
      local result_file="$DISPATCH_RUNS/$run_id.result.json"
      [[ -f "$result_file" ]] || result_file="$DISPATCH_RUNS/$run_id.output"
      [[ -f "$result_file" ]] || result_file="$done_file"

      local verdict="PASS"
      if [[ -f "$result_file" ]]; then
        verdict=$(bash "$WORKSPACE/scripts/verify-output.sh" "$result_file" "$title" ${target:+--agent "$target"} 2>/dev/null | head -1 || echo "PASS")
      fi

      # Log to agent stats
      local agent_name=$(jq -r '.dispatch_agent // .agent // .to // "unknown"' "$handoff" 2>/dev/null)
      bash "$WORKSPACE/scripts/agent-stats.sh" log "$agent_name" "$target" "$title" "$verdict" "$duration" 2>/dev/null || true

      if [[ "$verdict" == "FAIL" && "$FALLBACK_ENABLED" == true ]]; then
        # Attempt fallback to alternate system
        local alt_system=""
        if [[ "$target" == "claude-code" ]]; then alt_system="codex"; fi
        if [[ "$target" == "codex" ]]; then alt_system="claude-code"; fi

        if [[ -n "$alt_system" ]]; then
          echo "[$run_id] VERIFICATION FAILED -- falling back to $alt_system"
          local fb_prompt="Pick up handoff: $title"
          local fb_run_id
          case "$alt_system" in
            claude-code) fb_run_id=$(dispatch_claude_code "$fb_prompt" "$(basename "$handoff")") ;;
            codex) fb_run_id=$(dispatch_codex "$fb_prompt" "$(basename "$handoff")") ;;
          esac
          jq '.status = "dispatched" | .dispatched_at = "'"$(date -u +%Y-%m-%dT%H:%M:%SZ)"'" | .dispatch_run_id = "'"$fb_run_id"'" | .to = "'"$alt_system"'" | .fallback = true' "$handoff" > "${handoff}.tmp" && mv "${handoff}.tmp" "$handoff"
          echo "{\"run_id\":\"$run_id\",\"completed\":\"$(date -u +%Y-%m-%dT%H:%M:%SZ)\",\"status\":\"fallback\",\"fallback_run\":\"$fb_run_id\",\"reason\":\"verification_failed\"}" \
            >> "$DISPATCH_LOG/$(date +%Y-%m-%d).jsonl"
          checked=$((checked + 1))
          continue
        fi
      fi

      jq '.status = "complete" | .completed_at = "'"$(date -u +%Y-%m-%dT%H:%M:%SZ)"'" | .verdict = "'"$verdict"'"' "$handoff" > "${handoff}.tmp" && mv "${handoff}.tmp" "$handoff"
      echo "[$run_id] COMPLETED ($verdict): $title"

      local quiet_notification=false
      if is_quiet_priority "$handoff"; then
        quiet_notification=true
      fi
      local notify_summary
      notify_summary=$(build_summary "$title" "$done_file" "$result_file")
      notify_completion "$run_id" "$target" "$agent_name" "$notify_summary" "$(echo "$verdict" | tr '[:upper:]' '[:lower:]')" "$quiet_notification"

      # Log completion
      echo "{\"run_id\":\"$run_id\",\"completed\":\"$(date -u +%Y-%m-%dT%H:%M:%SZ)\",\"status\":\"complete\",\"verdict\":\"$verdict\",\"duration\":$duration}" \
        >> "$DISPATCH_LOG/$(date +%Y-%m-%d).jsonl"
    else
      # Process exited but no .done file -- possible failure
      echo "[$run_id] FINISHED (no .done marker): $title -- needs manual review"

      local is_error=false
      if [[ -f "$DISPATCH_RUNS/$run_id.result.json" ]]; then
        is_error=$(jq -r '.is_error // false' "$DISPATCH_RUNS/$run_id.result.json" 2>/dev/null)
      fi

      if [[ "$is_error" == "true" ]]; then
        echo "[$run_id] ERROR detected in result JSON"

        # Log failure to agent stats
        local agent_name=$(jq -r '.dispatch_agent // .agent // .to // "unknown"' "$handoff" 2>/dev/null)
        bash "$WORKSPACE/scripts/agent-stats.sh" log "$agent_name" "$target" "$title" "FAIL" "$duration" 2>/dev/null || true

        # Attempt fallback
        if [[ "$FALLBACK_ENABLED" == true ]]; then
          local alt_system=""
          if [[ "$target" == "claude-code" ]]; then alt_system="codex"; fi
          if [[ "$target" == "codex" ]]; then alt_system="claude-code"; fi

          if [[ -n "$alt_system" ]]; then
            echo "[$run_id] Falling back to $alt_system..."
            local fb_prompt="Pick up handoff: $title"
            local fb_run_id
            case "$alt_system" in
              claude-code) fb_run_id=$(dispatch_claude_code "$fb_prompt" "$(basename "$handoff")") ;;
              codex) fb_run_id=$(dispatch_codex "$fb_prompt" "$(basename "$handoff")") ;;
            esac
            jq '.status = "dispatched" | .dispatched_at = "'"$(date -u +%Y-%m-%dT%H:%M:%SZ)"'" | .dispatch_run_id = "'"$fb_run_id"'" | .to = "'"$alt_system"'" | .fallback = true' "$handoff" > "${handoff}.tmp" && mv "${handoff}.tmp" "$handoff"
            echo "{\"run_id\":\"$run_id\",\"completed\":\"$(date -u +%Y-%m-%dT%H:%M:%SZ)\",\"status\":\"fallback\",\"fallback_run\":\"$fb_run_id\",\"reason\":\"error\"}" \
              >> "$DISPATCH_LOG/$(date +%Y-%m-%d).jsonl"
            checked=$((checked + 1))
            continue
          fi
        fi

        # Both systems failed -- escalate
        jq '.status = "failed" | .failed_at = "'"$(date -u +%Y-%m-%dT%H:%M:%SZ)"'"' "$handoff" > "${handoff}.tmp" && mv "${handoff}.tmp" "$handoff"

        # Write escalation
        local esc_file="$ESCALATIONS_DIR/$(date +%Y-%m-%d)-$run_id.json"
        jq -n \
          --arg run_id "$run_id" \
          --arg title "$title" \
          --arg priority "P2" \
          --arg reason "Both systems failed" \
          --arg ts "$(date -u +%Y-%m-%dT%H:%M:%SZ)" \
          '{timestamp: $ts, run_id: $run_id, title: $title, priority: $priority, reason: $reason, status: "open"}' \
          > "$esc_file"
        echo "[$run_id] ESCALATED to orchestrator as P2"

        notify_completion "$run_id" "$target" "$agent_name" "Task failed after dispatch fallback attempts: $title" "fail" "false"
      fi
    fi

    checked=$((checked + 1))
  done

  [[ $checked -eq 0 ]] && echo "No dispatched runs to check"
}

# ============================================================
# run -- Directly dispatch a task
# ============================================================
run_direct() {
  local target="${1:-}"
  local prompt="${2:-}"
  local agent="${3:-}"

  if [[ -z "$target" || -z "$prompt" ]]; then
    echo "ERROR: Usage: dispatch.sh run <claude-code|codex> \"<prompt>\" [--agent <slug>]" >&2
    exit 1
  fi

  case "$target" in
    claude-code) dispatch_claude_code "$prompt" "" "$agent" ;;
    codex) dispatch_codex "$prompt" "" "$agent" ;;
    *) echo "ERROR: Unknown target '$target'. Use: claude-code, codex" >&2; exit 1 ;;
  esac
}

# ============================================================
# status -- Show all running/recent dispatches
# ============================================================
show_status() {
  echo "=== Active Dispatches ==="
  local found=0
  for pid_file in "$DISPATCH_RUNS"/*.pid; do
    [[ -f "$pid_file" ]] || continue
    local run_id=$(basename "$pid_file" .pid)
    local pid=$(cat "$pid_file")
    if kill -0 "$pid" 2>/dev/null; then
      echo "  [$run_id] Running (PID: $pid)"
      found=$((found + 1))
    fi
  done
  [[ $found -eq 0 ]] && echo "  (none)"

  echo ""
  echo "=== Recent Dispatch Log ==="
  local today_log="$DISPATCH_LOG/$(date +%Y-%m-%d).jsonl"
  if [[ -f "$today_log" ]]; then
    while IFS= read -r line; do
      local rid=$(echo "$line" | jq -r '.run_id // "?"')
      local tgt=$(echo "$line" | jq -r '.target // "?"')
      local st=$(echo "$line" | jq -r '.status // .completed // "?"')
      echo "  $rid -> $tgt ($st)"
    done < "$today_log"
  else
    echo "  (no dispatches today)"
  fi
}

# ============================================================
# Main
# ============================================================
case "$ACTION" in
  check)
    check_and_dispatch
    check_completed
    ;;
  verify)
    check_completed
    ;;
  run)
    shift
    # Parse --agent flag from remaining args
    run_target=""
    run_prompt=""
    run_agent=""
    while [[ $# -gt 0 ]]; do
      case "$1" in
        --agent) run_agent="${2:-}"; shift 2 ;;
        --timeout) DISPATCH_TIMEOUT="${2:-120}"; shift 2 ;;
        --no-fallback) FALLBACK_ENABLED=false; shift ;;
        *)
          if [[ -z "$run_target" ]]; then
            run_target="$1"
          elif [[ -z "$run_prompt" ]]; then
            run_prompt="$1"
          fi
          shift
          ;;
      esac
    done
    run_direct "$run_target" "$run_prompt" "$run_agent"
    ;;
  status)
    show_status
    ;;
  *)
    echo "Usage: dispatch.sh <check|verify|run|status> [--timeout <secs>] [--no-fallback]" >&2
    echo "  check  -- Auto-dispatch pending handoffs + verify completed" >&2
    echo "  verify -- Only check completed dispatches" >&2
    echo "  run    -- Direct dispatch: run <claude-code|codex> \"prompt\" [--agent <slug>]" >&2
    echo "  status -- Show active + recent dispatches" >&2
    echo "" >&2
    echo "Flags:" >&2
    echo "  --timeout <secs>  Timeout before fallback (default: 120)" >&2
    echo "  --no-fallback     Disable automatic retry on alternate system" >&2
    exit 1
    ;;
esac
