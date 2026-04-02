#!/usr/bin/env bash
# process-notifications.sh — Deliver pending mesh notifications during heartbeat.
#
# Usage:
#   bash scripts/process-notifications.sh

set -euo pipefail

WORKSPACE="/Users/meircohen/.openclaw/workspace"
NOTIFICATIONS_DIR="$WORKSPACE/shared/notifications"
ARCHIVE_DIR="$NOTIFICATIONS_DIR/archive"
LOG_FILE="$WORKSPACE/logs/notifications.log"
CONFIG_FILE="$WORKSPACE/config/integrations/telegram-groups.json"

mkdir -p "$NOTIFICATIONS_DIR" "$ARCHIVE_DIR" "$(dirname "$LOG_FILE")"

log_line() {
  printf '[%s] %s\n' "$(date '+%Y-%m-%d %H:%M:%S')" "$1" >> "$LOG_FILE"
}

resolve_target() {
  if [[ -n "${OPENCLAW_TELEGRAM_TARGET:-}" ]]; then
    echo "$OPENCLAW_TELEGRAM_TARGET"
    return
  fi

  jq -r '.command_center.id // empty' "$CONFIG_FILE" 2>/dev/null || true
}

archive_notification() {
  local source_file="$1"
  local archive_file="$ARCHIVE_DIR/$(basename "$source_file")"
  mv "$source_file" "$archive_file"
}

build_message() {
  local file="$1"
  jq -r '
    "Task " + .taskId + " [" + (.status | ascii_upcase) + "] via " + .system +
    (if .agent == "" or .agent == "none" then "" else "/" + .agent end) +
    ": " + .summary
  ' "$file" | cut -c1-3500
}

TARGET="$(resolve_target)"

delivered=0
suppressed=0
failed=0

shopt -s nullglob
for file in "$NOTIFICATIONS_DIR"/*.json; do
  [[ -f "$file" ]] || continue

  quiet=$(jq -r '.quiet // false' "$file")
  task_id=$(jq -r '.taskId // "unknown"' "$file")

  if [[ "$quiet" == "true" ]]; then
    archive_notification "$file"
    suppressed=$((suppressed + 1))
    log_line "SUPPRESSED taskId=$task_id"
    continue
  fi

  if [[ -z "$TARGET" ]]; then
    failed=$((failed + 1))
    log_line "FAILED taskId=$task_id reason=no telegram target configured"
    continue
  fi

  message=$(build_message "$file")
  if openclaw message send --channel telegram --target "$TARGET" --message "$message" >/dev/null 2>&1; then
    archive_notification "$file"
    delivered=$((delivered + 1))
    log_line "DELIVERED taskId=$task_id target=$TARGET"
  else
    failed=$((failed + 1))
    log_line "FAILED taskId=$task_id reason=delivery command failed"
  fi
done
shopt -u nullglob

if [[ $delivered -eq 0 && $suppressed -eq 0 && $failed -eq 0 ]]; then
  echo "No pending notifications"
else
  echo "Delivered $delivered notification(s), suppressed $suppressed, failed $failed"
fi
