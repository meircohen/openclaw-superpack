#!/usr/bin/env bash
# notify-complete.sh — Queue a task completion notification for heartbeat delivery.
#
# Usage:
#   bash scripts/notify-complete.sh [--quiet] <task-id> <system> <agent> "<summary>" <pass|warn|fail>

set -euo pipefail

WORKSPACE="/Users/meircohen/.openclaw/workspace"
NOTIFICATIONS_DIR="$WORKSPACE/shared/notifications"

QUIET=false
ARGS=()

while [[ $# -gt 0 ]]; do
  case "$1" in
    --quiet) QUIET=true; shift ;;
    *) ARGS+=("$1"); shift ;;
  esac
done

if [[ ${#ARGS[@]} -ne 5 ]]; then
  echo "Usage: notify-complete.sh [--quiet] <task-id> <system> <agent> \"<summary>\" <pass|warn|fail>" >&2
  exit 1
fi

TASK_ID="${ARGS[0]}"
SYSTEM="${ARGS[1]}"
AGENT="${ARGS[2]}"
SUMMARY="${ARGS[3]}"
STATUS=$(printf '%s' "${ARGS[4]}" | tr '[:upper:]' '[:lower:]')

case "$STATUS" in
  pass|warn|fail) ;;
  *)
    echo "ERROR: status must be one of: pass, warn, fail" >&2
    exit 1
    ;;
esac

mkdir -p "$NOTIFICATIONS_DIR"

TIMESTAMP="$(date -u +%Y-%m-%dT%H:%M:%SZ)"
SAFE_TASK_ID=$(echo "$TASK_ID" | tr -cs '[:alnum:]._-:' '-')
FILE_PATH="$NOTIFICATIONS_DIR/$(date +%Y%m%d-%H%M%S)-${SAFE_TASK_ID}.json"
SANITIZED_SUMMARY=$(printf '%s' "$SUMMARY" | tr '\n' ' ' | sed 's/[[:space:]]\+/ /g' | cut -c1-500)

jq -n \
  --arg taskId "$TASK_ID" \
  --arg system "$SYSTEM" \
  --arg agent "$AGENT" \
  --arg summary "$SANITIZED_SUMMARY" \
  --arg status "$STATUS" \
  --arg timestamp "$TIMESTAMP" \
  --argjson quiet "$(if $QUIET; then echo true; else echo false; fi)" \
  '{taskId: $taskId, system: $system, agent: $agent, summary: $summary, status: $status, timestamp: $timestamp, quiet: $quiet}' \
  > "$FILE_PATH"

echo "$FILE_PATH"
