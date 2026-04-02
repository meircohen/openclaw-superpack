#!/usr/bin/env bash
set -euo pipefail

# prompt-lint.sh — lightweight guardrails checker for cron/system prompts
# Usage:
#   bash scripts/prompt-lint.sh <file>
# Returns non-zero if high-risk patterns are detected.

FILE="${1:-}"
if [[ -z "${FILE}" || ! -f "${FILE}" ]]; then
  echo "Usage: $0 <file>" >&2
  exit 2
fi

fail() {
  echo "PROMPT_LINT_FAIL: $1" >&2
  exit 1
}

# Hard fails: patterns that correlate with unsafe behavior or low-quality outputs.
if rg -n "(?i)ignore (all|any) previous instructions" "$FILE" >/dev/null; then
  fail "prompt-injection phrase: ignore previous instructions"
fi

if rg -n "(?i)run (rm -rf|sudo|curl\s+\|\s+sh)" "$FILE" >/dev/null; then
  fail "dangerous shell pattern present"
fi

# Soft warnings (exit 0 but prints warnings)
WARN=0
warn() { echo "PROMPT_LINT_WARN: $1" >&2; WARN=1; }

if ! rg -n -i "Validate before output|validate" "$FILE" >/dev/null; then
  warn "missing explicit validate-before-output instruction"
fi

if ! rg -n -i "Evidence|Citations|cite" "$FILE" >/dev/null; then
  warn "missing evidence/citations requirement"
fi

if [[ $WARN -eq 1 ]]; then
  echo "PROMPT_LINT_OK_WITH_WARNINGS"
else
  echo "PROMPT_LINT_OK"
fi
