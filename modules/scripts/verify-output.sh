#!/usr/bin/env bash
# verify-output.sh — Results verification layer for dispatch outputs
# Usage: bash scripts/verify-output.sh <result-file> "<task>" [--agent <slug>] [--re-dispatch]
# Outputs: PASS, WARN (with notes), or FAIL (with reason)

set -euo pipefail

WORKSPACE="/Users/meircohen/.openclaw/workspace"
CORRECTIONS_DIR="$WORKSPACE/shared/corrections"
DISPATCH_LOG="$WORKSPACE/shared/dispatch-log"
mkdir -p "$CORRECTIONS_DIR" "$DISPATCH_LOG"

MIN_LENGTH=50
KEYWORD_THRESHOLD=1

# Parse arguments
RESULT_FILE=""
TASK_DESC=""
AGENT=""
RE_DISPATCH=false

while [[ $# -gt 0 ]]; do
  case "$1" in
    --agent) AGENT="${2:-}"; shift 2 ;;
    --re-dispatch) RE_DISPATCH=true; shift ;;
    *)
      if [[ -z "$RESULT_FILE" ]]; then
        RESULT_FILE="$1"
      elif [[ -z "$TASK_DESC" ]]; then
        TASK_DESC="$1"
      fi
      shift
      ;;
  esac
done

if [[ -z "$RESULT_FILE" || -z "$TASK_DESC" ]]; then
  echo "Usage: verify-output.sh <result-file> \"<task-description>\" [--agent <slug>] [--re-dispatch]" >&2
  exit 1
fi

# --- Read result content ---
RESULT_CONTENT=""
if [[ ! -f "$RESULT_FILE" ]]; then
  echo "FAIL: Result file does not exist: $RESULT_FILE"
  exit 2
fi

# Handle JSON result files (Claude Code outputs JSON with result field)
if [[ "$RESULT_FILE" == *.json ]]; then
  RESULT_CONTENT=$(jq -r '.result // .output // .content // empty' "$RESULT_FILE" 2>/dev/null || cat "$RESULT_FILE")
else
  RESULT_CONTENT=$(cat "$RESULT_FILE")
fi

VERDICT="PASS"
NOTES=""

# --- Check 1: Non-empty and minimum length ---
CONTENT_LEN=${#RESULT_CONTENT}
if [[ $CONTENT_LEN -eq 0 ]]; then
  VERDICT="FAIL"
  NOTES="Output is empty"
elif [[ $CONTENT_LEN -lt $MIN_LENGTH ]]; then
  if [[ "$VERDICT" != "FAIL" ]]; then
    VERDICT="WARN"
    NOTES="Output suspiciously short (${CONTENT_LEN} chars, min ${MIN_LENGTH})"
  fi
fi

# --- Check 2: Keyword relevance ---
if [[ "$VERDICT" != "FAIL" ]]; then
  # Extract significant words from task (>3 chars, lowercase)
  TASK_WORDS=$(echo "$TASK_DESC" | tr '[:upper:]' '[:lower:]' | tr -cs '[:alpha:]' '\n' | awk 'length > 3' | sort -u)
  RESULT_LOWER=$(echo "$RESULT_CONTENT" | tr '[:upper:]' '[:lower:]')

  MATCHES=0
  TOTAL_KEYWORDS=0
  for word in $TASK_WORDS; do
    TOTAL_KEYWORDS=$((TOTAL_KEYWORDS + 1))
    if echo "$RESULT_LOWER" | grep -q "$word"; then
      MATCHES=$((MATCHES + 1))
    fi
  done

  if [[ $TOTAL_KEYWORDS -gt 0 && $MATCHES -lt $KEYWORD_THRESHOLD ]]; then
    VERDICT="FAIL"
    NOTES="Output has zero keyword overlap with task — likely off-topic"
  elif [[ $TOTAL_KEYWORDS -gt 3 && $MATCHES -lt 2 ]]; then
    if [[ "$VERDICT" == "PASS" ]]; then
      VERDICT="WARN"
      NOTES="Low keyword overlap (${MATCHES}/${TOTAL_KEYWORDS}) — may be off-topic"
    fi
  fi
fi

# ============================================================
# Check 3: PII leak scan
# ============================================================
if [[ "$VERDICT" != "FAIL" ]]; then
  # Check for SSN patterns
  if echo "$RESULT_CONTENT" | grep -qE '\b[0-9]{3}-[0-9]{2}-[0-9]{4}\b'; then
    VERDICT="FAIL"
    NOTES="PII detected: possible SSN pattern"
  fi
  # Check for credit card patterns
  if echo "$RESULT_CONTENT" | grep -qE '\b[0-9]{4}[- ]?[0-9]{4}[- ]?[0-9]{4}[- ]?[0-9]{4}\b'; then
    if [[ "$VERDICT" != "FAIL" ]]; then
      VERDICT="FAIL"
      NOTES="PII detected: possible credit card number"
    fi
  fi
  # Check for leaked credentials
  if echo "$RESULT_CONTENT" | grep -qiE '(password|secret|api.key|token)\s*[:=]\s*["\x27]?[A-Za-z0-9+/=_-]{8,}'; then
    if [[ "$VERDICT" != "FAIL" ]]; then
      VERDICT="WARN"
      NOTES="${NOTES:+$NOTES; }Possible credential leak detected"
    fi
  fi
fi

# ============================================================
# Check 4: Agent persona adherence
# ============================================================
if [[ -n "$AGENT" && "$VERDICT" != "FAIL" ]]; then
  # Check if agent broke character by referencing itself as a different agent
  KNOWN_AGENTS=("claude-code" "codex" "cowork" "openclaw" "oz")
  for other in "${KNOWN_AGENTS[@]}"; do
    if [[ "$other" != "$AGENT" ]]; then
      if echo "$RESULT_CONTENT" | grep -qiE "I am ${other}|as ${other},|my name is ${other}"; then
        if [[ "$VERDICT" == "PASS" ]]; then
          VERDICT="WARN"
          NOTES="${NOTES:+$NOTES; }Agent may have broken persona (referenced itself as '${other}')"
        fi
      fi
    fi
  done
fi

# ============================================================
# Output verdict
# ============================================================
NOW=$(date -u +%Y-%m-%dT%H:%M:%SZ)
RUN_ID=$(basename "$RESULT_FILE" | sed 's/\.\(result\.json\|output\|done\)$//')

echo "$VERDICT"
[[ -n "$NOTES" ]] && echo "NOTES: $NOTES"

# ============================================================
# Handle verdict outcomes
# ============================================================
case "$VERDICT" in
  PASS)
    echo "{\"timestamp\":\"$NOW\",\"run_id\":\"$RUN_ID\",\"verdict\":\"PASS\",\"notes\":\"\"}" \
      >> "$DISPATCH_LOG/verify-$(date +%Y-%m-%d).jsonl"
    ;;

  WARN)
    echo "{\"timestamp\":\"$NOW\",\"run_id\":\"$RUN_ID\",\"verdict\":\"WARN\",\"notes\":$(echo "$NOTES" | jq -Rs .)}" \
      >> "$DISPATCH_LOG/verify-$(date +%Y-%m-%d).jsonl"
    # Deliver result despite warning
    ;;

  FAIL)
    echo "{\"timestamp\":\"$NOW\",\"run_id\":\"$RUN_ID\",\"verdict\":\"FAIL\",\"notes\":$(echo "$NOTES" | jq -Rs .)}" \
      >> "$DISPATCH_LOG/verify-$(date +%Y-%m-%d).jsonl"

    # Log correction
    SYSTEM="unknown"
    if [[ "$RUN_ID" == cc-* ]]; then SYSTEM="claude-code"; fi
    if [[ "$RUN_ID" == cx-* ]]; then SYSTEM="codex"; fi

    bash "$WORKSPACE/scripts/corrections.sh" log \
      "$SYSTEM" "accuracy" \
      "Verification failed for task: $(echo "$TASK_DESC" | head -c 100)" \
      "Reason: $NOTES" 2>/dev/null || true

    # Optionally re-dispatch to alternate system
    if [[ "$RE_DISPATCH" == true ]]; then
      ALT_SYSTEM=""
      if [[ "$SYSTEM" == "claude-code" ]]; then ALT_SYSTEM="codex"; fi
      if [[ "$SYSTEM" == "codex" ]]; then ALT_SYSTEM="claude-code"; fi

      if [[ -n "$ALT_SYSTEM" ]]; then
        echo "Re-dispatching to $ALT_SYSTEM..."
        bash "$WORKSPACE/scripts/dispatch.sh" run "$ALT_SYSTEM" "$TASK_DESC" ${AGENT:+--agent "$AGENT"} 2>&1 || true
      fi
    fi
    ;;
esac

exit 0
