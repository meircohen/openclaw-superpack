#!/usr/bin/env bash
# smart-dispatch.sh — Intelligent dispatch: auto-routes tasks to the right system + agent
#
# Usage:
#   bash scripts/smart-dispatch.sh "Review the iCare codebase for SQL injection vulnerabilities"
#   bash scripts/smart-dispatch.sh --dry-run "Deploy the new worker to Cloudflare"
#   bash scripts/smart-dispatch.sh --system codex "Override system selection for this task"
#   bash scripts/smart-dispatch.sh --agent security-auditor "Force a specific agent persona"
#
# Combines route.sh (intelligent routing) + dispatch.sh (execution)

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
WORKSPACE="/Users/meircohen/.openclaw/workspace"
DISPATCH_LOG="$WORKSPACE/shared/dispatch-log"

mkdir -p "$DISPATCH_LOG"

# Parse flags
DRY_RUN=false
OVERRIDE_SYSTEM=""
OVERRIDE_AGENT=""
TASK=""

while [[ $# -gt 0 ]]; do
  case "$1" in
    --dry-run) DRY_RUN=true; shift ;;
    --system) OVERRIDE_SYSTEM="$2"; shift 2 ;;
    --agent) OVERRIDE_AGENT="$2"; shift 2 ;;
    --) shift; TASK="$*"; break ;;
    -*) echo "ERROR: Unknown flag '$1'" >&2; exit 1 ;;
    *) TASK="$*"; break ;;
  esac
done

if [[ -z "$TASK" ]]; then
  echo "Usage: smart-dispatch.sh [--dry-run] [--system <system>] [--agent <agent>] \"<task>\"" >&2
  echo "" >&2
  echo "Flags:" >&2
  echo "  --dry-run   Show routing decision without executing" >&2
  echo "  --system    Override auto-detected system (codex|claude-code|openclaw)" >&2
  echo "  --agent     Override auto-detected agent persona" >&2
  exit 1
fi

# Step 1: Route the task
echo "Routing task..." >&2
ROUTE_JSON=$("$SCRIPT_DIR/route.sh" --json "$TASK")

routed_system=$(echo "$ROUTE_JSON" | jq -r '.system')
routed_agent=$(echo "$ROUTE_JSON" | jq -r '.agent // empty')
routed_reason=$(echo "$ROUTE_JSON" | jq -r '.reason')
routed_domain=$(echo "$ROUTE_JSON" | jq -r '.domain')
routed_confidence=$(echo "$ROUTE_JSON" | jq -r '.confidence')

# Apply overrides
final_system="${OVERRIDE_SYSTEM:-$routed_system}"
final_agent="${OVERRIDE_AGENT:-$routed_agent}"

# Step 2: Log the routing decision
TASK_SUMMARY=$(echo "$TASK" | head -c 200)
LOG_ENTRY=$(jq -n \
  --arg ts "$(date -u +%Y-%m-%dT%H:%M:%SZ)" \
  --arg task "$TASK_SUMMARY" \
  --arg routed_system "$routed_system" \
  --arg routed_agent "${routed_agent:-none}" \
  --arg final_system "$final_system" \
  --arg final_agent "${final_agent:-none}" \
  --arg domain "$routed_domain" \
  --arg confidence "$routed_confidence" \
  --arg reason "$routed_reason" \
  --argjson overridden "$(if [[ -n "$OVERRIDE_SYSTEM" || -n "$OVERRIDE_AGENT" ]]; then echo true; else echo false; fi)" \
  --argjson dry_run "$DRY_RUN" \
  '{timestamp: $ts, task: $task, routed: {system: $routed_system, agent: $routed_agent, domain: $domain, confidence: $confidence}, final: {system: $final_system, agent: $final_agent}, reason: $reason, overridden: $overridden, dry_run: $dry_run}')

echo "$LOG_ENTRY" >> "$DISPATCH_LOG/routing-$(date +%Y-%m-%d).jsonl"

# Step 3: Show decision
echo "" >&2
echo "=== Routing Decision ===" >&2
echo "  Domain:     $routed_domain" >&2
echo "  System:     $final_system" >&2
echo "  Agent:      ${final_agent:-none}" >&2
echo "  Confidence: $routed_confidence" >&2
echo "  Reason:     $routed_reason" >&2
if [[ -n "$OVERRIDE_SYSTEM" || -n "$OVERRIDE_AGENT" ]]; then
  echo "  (overrides applied)" >&2
fi
echo "" >&2

# Step 4: Execute or show dry-run
if $DRY_RUN; then
  echo "=== DRY RUN — Would execute: ===" >&2
  echo "  bash scripts/dispatch.sh run $final_system '$TASK'${final_agent:+ --agent $final_agent}" >&2
  echo "" >&2
  echo "$ROUTE_JSON"
  exit 0
fi

# Handle openclaw — can't dispatch via CLI, create a handoff instead
if [[ "$final_system" == "openclaw" ]]; then
  echo "Task requires OpenClaw (gateway-exclusive tools). Creating handoff..." >&2
  handoff_file="$WORKSPACE/shared/handoffs/$(date +%Y-%m-%d)-smart-dispatch-$(date +%s).json"
  jq -n \
    --arg title "Smart-dispatch: $TASK_SUMMARY" \
    --arg task "$TASK" \
    --arg agent "${final_agent:-}" \
    '{to: "openclaw", status: "pending", title: $title, task: $task, agent: $agent, created: now | strftime("%Y-%m-%dT%H:%M:%SZ")}' \
    > "$handoff_file"
  echo "Handoff created: $(basename "$handoff_file")" >&2
  exit 0
fi

# Dispatch to the target system
echo "Dispatching..." >&2
AGENT_FLAG=""
if [[ -n "$final_agent" ]]; then
  AGENT_FLAG="--agent $final_agent"
fi

bash "$SCRIPT_DIR/dispatch.sh" run "$final_system" "$TASK" $AGENT_FLAG
