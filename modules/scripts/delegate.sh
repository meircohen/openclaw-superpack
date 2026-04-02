#!/usr/bin/env bash
# delegate.sh — Route a task brief to the correct skill + voice + anti-patterns
# Usage: bash scripts/delegate.sh <type> <brief.json>
# Output: Formatted spawn prompt to stdout
#
# The main agent (Oz) calls this to assemble everything a sub-agent needs.
# The output is a complete prompt ready to pass to a sub-agent spawn call.

set -euo pipefail

WORKSPACE="/Users/meircohen/.openclaw/workspace"
DELEGATION_DIR="$WORKSPACE/skills/delegation"
ANTI_PATTERNS="$WORKSPACE/config/core/anti-patterns.md"

# --- Arg validation ---
if [[ $# -lt 2 ]]; then
  echo "ERROR: Usage: bash scripts/delegate.sh <type> <brief.json>" >&2
  echo "Types: tweet-engagement, tweet-original, code-task, research-brief, email-draft, ops-debug" >&2
  exit 1
fi

TYPE="$1"
BRIEF="$2"

VALID_TYPES="tweet-engagement tweet-original code-task research-brief email-draft ops-debug"
if ! echo "$VALID_TYPES" | grep -qw "$TYPE"; then
  echo "ERROR: Unknown task type '$TYPE'" >&2
  echo "Valid types: $VALID_TYPES" >&2
  exit 1
fi

# --- Resolve paths ---
TEMPLATE="$DELEGATION_DIR/templates/${TYPE}.json"
SKILL="$DELEGATION_DIR/skills/${TYPE}.md"
VERIFY="$DELEGATION_DIR/verify/${TYPE}.md"

# Check that core files exist
for f in "$TEMPLATE" "$SKILL" "$VERIFY"; do
  if [[ ! -f "$f" ]]; then
    echo "ERROR: Missing file: $f" >&2
    exit 1
  fi
done

# --- Parse brief ---
# Brief can be a file path or inline JSON
if [[ -f "$BRIEF" ]]; then
  BRIEF_JSON=$(cat "$BRIEF")
else
  BRIEF_JSON="$BRIEF"
fi

# Validate brief is valid JSON
if ! echo "$BRIEF_JSON" | jq . > /dev/null 2>&1; then
  echo "ERROR: Brief is not valid JSON" >&2
  exit 1
fi

# Validate brief type matches
BRIEF_TYPE=$(echo "$BRIEF_JSON" | jq -r '.type // empty')
if [[ -n "$BRIEF_TYPE" && "$BRIEF_TYPE" != "$TYPE" ]]; then
  echo "ERROR: Brief type '$BRIEF_TYPE' doesn't match task type '$TYPE'" >&2
  exit 1
fi

# --- Validate required fields ---
REQUIRED=$(jq -r '.required[]' "$TEMPLATE" 2>/dev/null || true)
for field in $REQUIRED; do
  val=$(echo "$BRIEF_JSON" | jq -r ".${field} // empty")
  if [[ -z "$val" ]]; then
    echo "ERROR: Required field '$field' missing from brief" >&2
    exit 1
  fi
done

# --- Resolve voice guide ---
VOICE=$(echo "$BRIEF_JSON" | jq -r '.voice // "default"')
VOICE_FILE="$DELEGATION_DIR/voice/${VOICE}.md"
VOICE_SECTION=""
if [[ -f "$VOICE_FILE" ]]; then
  VOICE_SECTION=$(cat "$VOICE_FILE")
fi

# --- Resolve task-specific anti-patterns ---
TASK_ANTI_PATTERNS=$(jq -r '._anti_patterns[]? // empty' "$TEMPLATE" 2>/dev/null || true)

# --- Select agent model ---
AGENT_HINT=$(jq -r '._agent // "sonnet-4"' "$TEMPLATE" 2>/dev/null)
BRIEF_AGENT=$(echo "$BRIEF_JSON" | jq -r '.agent // empty')

# Auto-select for code tasks
if [[ "$TYPE" == "code-task" && "$BRIEF_AGENT" == "auto" ]]; then
  SCOPE_LEN=$(echo "$BRIEF_JSON" | jq -r '.scope | length')
  if [[ $SCOPE_LEN -lt 100 ]]; then
    AGENT_HINT="codex"
  else
    AGENT_HINT="claude-code"
  fi
elif [[ -n "$BRIEF_AGENT" ]]; then
  AGENT_HINT="$BRIEF_AGENT"
fi

# If agent is claude-code or codex, dispatch via CLI instead of sub-agent spawn
if [[ "$AGENT_HINT" == "claude-code" || "$AGENT_HINT" == "codex" ]]; then
  DISPATCH_MODE="cli"
else
  DISPATCH_MODE="spawn"
fi

# --- Resolve timeout ---
TIMEOUT=$(echo "$BRIEF_JSON" | jq -r '.timeout // empty')
if [[ -z "$TIMEOUT" ]]; then
  TIMEOUT=$(jq -r '._timeout // 300' "$TEMPLATE" 2>/dev/null)
fi

# --- Budget check ---
if ! "$WORKSPACE/scripts/token-tracker.sh" check "$AGENT_HINT" 2>/dev/null; then
  echo "WARNING: Agent $AGENT_HINT is over daily token budget. Task will proceed but is flagged." >&2
  echo "BUDGET_WARNING=true"
fi

# --- Assemble the spawn prompt ---
cat <<PROMPT
# Task: ${TYPE}
# Agent: ${AGENT_HINT}
# Timeout: ${TIMEOUT}s

---

## Your Brief

\`\`\`json
${BRIEF_JSON}
\`\`\`

---

## Execution Skill

$(cat "$SKILL")

---

PROMPT

# Include voice guide only for output-producing tasks
if [[ "$TYPE" == "tweet-engagement" || "$TYPE" == "tweet-original" || "$TYPE" == "email-draft" ]]; then
  if [[ -n "$VOICE_SECTION" ]]; then
    cat <<VOICE

## Voice Guide

${VOICE_SECTION}

---

VOICE
  fi
fi

# Anti-patterns (global + task-specific)
cat <<ANTI

## Anti-Patterns (DO NOT REPEAT THESE MISTAKES)

### Global Anti-Patterns
$(cat "$ANTI_PATTERNS")

ANTI

if [[ -n "$TASK_ANTI_PATTERNS" ]]; then
  cat <<TASK_AP

### Task-Specific Anti-Patterns
$(echo "$TASK_ANTI_PATTERNS" | sed 's/^/- /')

TASK_AP
fi

# Agent-specific corrections (feedback loop from prior runs)
CORRECTIONS=$("$WORKSPACE/scripts/corrections.sh" inject "$AGENT_HINT" 2>/dev/null || true)
if [[ -n "$CORRECTIONS" && "$CORRECTIONS" != "# No prior corrections for this agent" ]]; then
  cat <<CORRECTIONS_SECTION

${CORRECTIONS}

CORRECTIONS_SECTION
fi

# Verification checklist
cat <<VERIFY_SECTION

---

## Verification (MANDATORY — run before reporting done)

$(cat "$VERIFY")

VERIFY_SECTION

# Output metadata for the calling agent
cat <<META

---

## Metadata (for orchestrator)
- **task_type:** ${TYPE}
- **agent:** ${AGENT_HINT}
- **timeout:** ${TIMEOUT}s
- **generated:** $(date -u +"%Y-%m-%dT%H:%M:%SZ")
META
