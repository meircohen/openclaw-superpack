#!/usr/bin/env bash
# mesh-health.sh — Self-healing health checks for the OpenClaw mesh.
# Usage: bash scripts/mesh-health.sh {check|fix|status}
set -euo pipefail
WORKSPACE="/Users/meircohen/.openclaw/workspace"
SCRIPTS_DIR="$WORKSPACE/scripts"
LOGS_DIR="$WORKSPACE/logs"
LOCKS_DIR="$WORKSPACE/shared/locks"
MESH_HEALTH_DIR="$WORKSPACE/shared/mesh-health"
PID_FILE="$LOGS_DIR/handoff-daemon.pid"
LOG_FILE="$MESH_HEALTH_DIR/health-$(date +%Y-%m-%d).log"
REQUIRED_SCRIPTS=(dispatch.sh route.sh smart-dispatch.sh verify-output.sh agent-stats.sh context-inject.sh)
REQUIRED_DIRS=("$WORKSPACE/shared/dispatch-log" "$WORKSPACE/shared/agent-stats" "$WORKSPACE/shared/corrections" "$WORKSPACE/shared/mesh-health" "$WORKSPACE/shared/notifications")
ISSUE_COUNT=0
CRITICAL_REASON=""
CHECK_LINES=()
mkdir -p "$MESH_HEALTH_DIR"
log_line() { printf '[%s] %s\n' "$(date '+%Y-%m-%d %H:%M:%S')" "$1" >> "$LOG_FILE"; }
record_ok() { CHECK_LINES+=("OK $1"); log_line "OK $1"; }
record_issue() {
  local severity="$1" message="$2"
  ISSUE_COUNT=$((ISSUE_COUNT + 1))
  CHECK_LINES+=("${severity} ${message}")
  log_line "${severity} ${message}"
  [[ "$severity" == "CRITICAL" && -z "$CRITICAL_REASON" ]] && CRITICAL_REASON="$message"
}
summary_text() {
  if [[ -n "$CRITICAL_REASON" ]]; then echo "DOWN ($CRITICAL_REASON)"
  elif [[ $ISSUE_COUNT -gt 0 ]]; then echo "DEGRADED ($ISSUE_COUNT issues)"
  else echo "HEALTHY"; fi
}
is_recent_file() {
  local file="$1" now_epoch file_epoch
  now_epoch=$(date +%s)
  file_epoch=$(stat -f '%m' "$file" 2>/dev/null || stat -c '%Y' "$file" 2>/dev/null || echo 0)
  [[ $file_epoch -ge $((now_epoch - 3600)) ]]
}
run_checks() {
  ISSUE_COUNT=0
  CRITICAL_REASON=""
  CHECK_LINES=()
  for script in "${REQUIRED_SCRIPTS[@]}"; do
    local path="$SCRIPTS_DIR/$script"
    if [[ ! -f "$path" ]]; then record_issue "CRITICAL" "missing script $script"
    elif [[ ! -x "$path" ]]; then record_issue "WARN" "script not executable $script"
    else record_ok "script ready $script"; fi
  done
  if [[ -f "$PID_FILE" ]]; then
    local daemon_pid
    daemon_pid=$(cat "$PID_FILE" 2>/dev/null || true)
    if [[ -n "$daemon_pid" ]] && kill -0 "$daemon_pid" 2>/dev/null; then
      record_ok "handoff-daemon running pid=$daemon_pid"
    else
      record_issue "CRITICAL" "handoff-daemon pid file is stale"
    fi
  else
    record_issue "CRITICAL" "handoff-daemon pid file missing"
  fi
  for dir in "${REQUIRED_DIRS[@]}"; do
    if [[ ! -d "$dir" ]]; then record_issue "CRITICAL" "missing directory ${dir#$WORKSPACE/}"
    elif [[ ! -w "$dir" ]]; then record_issue "CRITICAL" "directory not writable ${dir#$WORKSPACE/}"
    else record_ok "directory writable ${dir#$WORKSPACE/}"; fi
  done
  local claude_ok=false codex_ok=false
  if claude --version >/dev/null 2>&1; then claude_ok=true; record_ok "claude cli reachable"; else record_issue "WARN" "claude cli unreachable"; fi
  if codex --version >/dev/null 2>&1; then codex_ok=true; record_ok "codex cli reachable"; else record_issue "WARN" "codex cli unreachable"; fi
  [[ "$claude_ok" == false && "$codex_ok" == false ]] && CRITICAL_REASON="claude and codex cli unreachable"
  local error_files=()
  if [[ -d "$LOGS_DIR" ]]; then
    for file in "$LOGS_DIR"/*; do
      [[ -f "$file" ]] || continue
      if is_recent_file "$file" && grep -qiE 'error|fail|fatal' "$file"; then error_files+=("$(basename "$file")"); fi
    done
  fi
  if [[ ${#error_files[@]} -gt 0 ]]; then record_issue "WARN" "recent log errors in ${error_files[*]}"; else record_ok "no recent log errors"; fi
  log_line "SUMMARY $(summary_text)"
}
apply_fixes() {
  log_line "ACTION fix start"
  for script in "${REQUIRED_SCRIPTS[@]}"; do
    local path="$SCRIPTS_DIR/$script"
    if [[ -f "$path" && ! -x "$path" ]]; then
      chmod +x "$path"
      echo "fixed executable $script"
      log_line "ACTION chmod +x $script"
    fi
  done
  for dir in "${REQUIRED_DIRS[@]}" "$WORKSPACE/shared/notifications/archive"; do
    if [[ ! -d "$dir" ]]; then
      mkdir -p "$dir"
      echo "created ${dir#$WORKSPACE/}"
      log_line "ACTION mkdir -p ${dir#$WORKSPACE/}"
    fi
  done
  if [[ -f "$PID_FILE" ]]; then
    local daemon_pid
    daemon_pid=$(cat "$PID_FILE" 2>/dev/null || true)
    if [[ -z "$daemon_pid" ]] || ! kill -0 "$daemon_pid" 2>/dev/null; then
      rm -f "$PID_FILE"
      if bash "$SCRIPTS_DIR/handoff-daemon.sh" start >/dev/null 2>&1; then
        echo "restarted handoff-daemon"
        log_line "ACTION restarted handoff-daemon"
      else
        echo "failed to restart handoff-daemon"
        log_line "ACTION failed to restart handoff-daemon"
      fi
    fi
  fi
  if [[ -d "$LOCKS_DIR" ]]; then
    for lock_file in "$LOCKS_DIR"/*; do
      [[ -f "$lock_file" ]] || continue
      if ! is_recent_file "$lock_file"; then
        if command -v trash >/dev/null 2>&1; then trash "$lock_file"; else rm -f "$lock_file"; fi
        echo "removed stale lock $(basename "$lock_file")"
        log_line "ACTION removed stale lock $(basename "$lock_file")"
      fi
    done
  fi
  log_line "ACTION fix end"
}
ACTION="${1:-check}"
case "$ACTION" in
  check) run_checks; printf '%s\n' "${CHECK_LINES[@]}"; echo "$(summary_text)" ;;
  fix) apply_fixes; run_checks; printf '%s\n' "${CHECK_LINES[@]}"; echo "$(summary_text)" ;;
  status) run_checks; echo "$(summary_text)" ;;
  *) echo "Usage: mesh-health.sh {check|fix|status}" >&2; exit 1 ;;
esac
