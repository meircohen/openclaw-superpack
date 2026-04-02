#!/bin/bash
# vault-cron-ingest.sh — Automated vault discovery & ingestion
#
# Schedule: 0 */6 * * * (every 6 hours)
# Timeout: 10 minutes max
# Output: state/vault/vault-cron-log.md
#
# Usage:
#   ./scripts/vault-cron-ingest.sh          # Full run
#   ./scripts/vault-cron-ingest.sh --test   # Quick test (1 query each)

set -o pipefail

WORKSPACE="$HOME/.openclaw/workspace"
STATE_DIR="$WORKSPACE/state"
SCRIPTS_DIR="$WORKSPACE/scripts"
CRON_LOG="$STATE_DIR/vault-cron-log.md"
LAST_RUN_FILE="$STATE_DIR/last-discovery-run.json"
DB="$STATE_DIR/document-vault-index.db"
TIMEOUT_SECS=120  # 2 minutes per source (cron timeout is 600s total)
MAX_PER_QUERY=20

# Parse args
TEST_MODE=false
if [ "$1" = "--test" ]; then
    TEST_MODE=true
    MAX_PER_QUERY=3
fi

# Ensure state dir exists
mkdir -p "$STATE_DIR"

# Track timing
START_TIME=$(date +%s)
START_TS=$(date "+%Y-%m-%d %H:%M %Z")

# Get vault size before
VAULT_BEFORE=$(sqlite3 "$DB" "SELECT COUNT(*) FROM documents" 2>/dev/null || echo "0")

# Initialize counters
GMAIL_NEW=0
GMAIL_DUP=0
GMAIL_ERR=0
DRIVE_NEW=0
DRIVE_DUP=0
LOCAL_NEW=0
LOCAL_DUP=0
ERRORS=""

# macOS-compatible timeout function
# Usage: run_with_timeout <seconds> <output_file> <command...>
# Writes stdout+stderr to output_file, returns 124 on timeout
run_with_timeout() {
    local timeout_secs=$1
    local outfile=$2
    shift 2
    # Run command with output redirected inside the backgrounded process
    "$@" > "$outfile" 2>&1 &
    local pid=$!
    ( sleep "$timeout_secs" && kill -9 "$pid" 2>/dev/null ) &
    local watcher=$!
    wait "$pid" 2>/dev/null
    local exit_code=$?
    kill "$watcher" 2>/dev/null
    wait "$watcher" 2>/dev/null
    # Check if killed by timeout (signal 9 = exit code 137)
    if [ $exit_code -eq 137 ]; then
        return 124  # Timeout exit code
    fi
    return $exit_code
}

# macOS-compatible stat parsing (no grep -P)
extract_stat() {
    local output="$1"
    local key="$2"
    echo "$output" | sed -n "s/.*${key}: \([0-9]*\).*/\1/p" | tail -1
}

log_section() {
    echo "" >> "$CRON_LOG"
    echo "## [$START_TS] Auto-Ingest Run" >> "$CRON_LOG"
}

# ── Gmail Discovery ──
run_gmail() {
    echo "Starting Gmail discovery..."

    local output
    local tmpfile=$(mktemp)
    run_with_timeout $TIMEOUT_SECS "$tmpfile" python3 "$SCRIPTS_DIR/execute-discovery.py" \
        --source gmail --expanded --max "$MAX_PER_QUERY"
    local exit_code=$?
    output=$(cat "$tmpfile")
    rm -f "$tmpfile"

    if [ $exit_code -eq 124 ]; then
        ERRORS="${ERRORS}Gmail: TIMEOUT after ${TIMEOUT_SECS}s; "
        return 1
    elif [ $exit_code -ne 0 ]; then
        ERRORS="${ERRORS}Gmail: exit code $exit_code; "
        return 1
    fi

    # Parse stats from output
    GMAIL_NEW=$(extract_stat "$output" "uploaded")
    GMAIL_DUP=$(extract_stat "$output" "duplicate")
    GMAIL_ERR=$(extract_stat "$output" "errors")

    echo "Gmail: ${GMAIL_NEW:-0} new, ${GMAIL_DUP:-0} duplicates"
    return 0
}

# ── Drive Discovery ──
run_drive() {
    echo "Starting Drive discovery..."

    local output
    local tmpfile=$(mktemp)
    run_with_timeout $TIMEOUT_SECS "$tmpfile" python3 "$SCRIPTS_DIR/execute-discovery.py" \
        --source drive --expanded
    local exit_code=$?
    output=$(cat "$tmpfile")
    rm -f "$tmpfile"

    if [ $exit_code -eq 124 ]; then
        ERRORS="${ERRORS}Drive: TIMEOUT after ${TIMEOUT_SECS}s; "
        return 1
    elif [ $exit_code -ne 0 ]; then
        ERRORS="${ERRORS}Drive: exit code $exit_code; "
        return 1
    fi

    DRIVE_NEW=$(extract_stat "$output" "indexed")
    DRIVE_DUP=$(extract_stat "$output" "duplicate")

    echo "Drive: ${DRIVE_NEW:-0} new, ${DRIVE_DUP:-0} duplicates"
    return 0
}

# ── Local Discovery ──
run_local() {
    echo "Starting Local discovery..."

    local output
    local tmpfile=$(mktemp)
    run_with_timeout $TIMEOUT_SECS "$tmpfile" python3 "$SCRIPTS_DIR/execute-discovery.py" \
        --source local
    local exit_code=$?
    output=$(cat "$tmpfile")
    rm -f "$tmpfile"

    if [ $exit_code -eq 124 ]; then
        ERRORS="${ERRORS}Local: TIMEOUT after ${TIMEOUT_SECS}s; "
        return 1
    elif [ $exit_code -ne 0 ]; then
        ERRORS="${ERRORS}Local: exit code $exit_code; "
        return 1
    fi

    LOCAL_NEW=$(extract_stat "$output" "uploaded")
    LOCAL_DUP=$(extract_stat "$output" "duplicate")

    echo "Local: ${LOCAL_NEW:-0} new, ${LOCAL_DUP:-0} duplicates"
    return 0
}

# ── Process vault-staging/ ──
process_staging() {
    local staging="$WORKSPACE/vault-staging"
    if [ -d "$staging" ] && [ "$(ls -A "$staging" 2>/dev/null)" ]; then
        echo "Processing staging directory..."
        python3 "$SCRIPTS_DIR/vault-auto-ingest.py" 2>&1 || true
    fi
}

# ── Main Execution ──

echo "=== Vault Auto-Ingest: $START_TS ==="
echo "Mode: $([ "$TEST_MODE" = true ] && echo 'TEST' || echo 'LIVE')"
echo ""

# Run each source, continue on failure
run_gmail || true
run_drive || true
run_local || true
process_staging || true

# Get vault size after
VAULT_AFTER=$(sqlite3 "$DB" "SELECT COUNT(*) FROM documents" 2>/dev/null || echo "0")
MISSING=$(sqlite3 "$DB" "SELECT COUNT(*) FROM expected_documents WHERE status = 'missing'" 2>/dev/null || echo "?")

# Calculate elapsed time
END_TIME=$(date +%s)
ELAPSED=$(( END_TIME - START_TIME ))

# Update last run timestamp
python3 -c "
import json
from datetime import datetime
data = {'last_run': datetime.now().isoformat(), 'vault_size': $VAULT_AFTER}
with open('$LAST_RUN_FILE', 'w') as f:
    json.dump(data, f)
" 2>/dev/null

# Write report to cron log
log_section
{
    echo "- Gmail: ${GMAIL_NEW:-0} new attachments (${GMAIL_DUP:-0} duplicates)"
    echo "- Drive: ${DRIVE_NEW:-0} new files (${DRIVE_DUP:-0} duplicates)"
    echo "- Local: ${LOCAL_NEW:-0} new files (${LOCAL_DUP:-0} duplicates)"
    echo "- Total vault size: $VAULT_AFTER documents"
    echo "- Missing expected: $MISSING"
    echo "- Duration: ${ELAPSED}s"
    if [ -n "$ERRORS" ]; then
        echo "- Errors: $ERRORS"
    fi
} >> "$CRON_LOG"

echo ""
echo "=== Summary ==="
echo "Gmail:  ${GMAIL_NEW:-0} new, ${GMAIL_DUP:-0} dup"
echo "Drive:  ${DRIVE_NEW:-0} new, ${DRIVE_DUP:-0} dup"
echo "Local:  ${LOCAL_NEW:-0} new, ${LOCAL_DUP:-0} dup"
echo "Vault:  $VAULT_BEFORE → $VAULT_AFTER (+$(( VAULT_AFTER - VAULT_BEFORE )))"
echo "Time:   ${ELAPSED}s"
echo ""

# Always exit 0 — cron should never crash
exit 0
