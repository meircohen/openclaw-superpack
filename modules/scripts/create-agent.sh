#!/usr/bin/env bash
set -euo pipefail

# create-agent.sh — Agent Factory
# Creates a new OpenClaw agent from base template with standard structure.
# Usage: ./create-agent.sh <name> [--model <model>] [--host <mac|gcp>] [--channel <telegram|slack|none>]

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
NC='\033[0m'

info()    { echo -e "${CYAN}ℹ${NC} $*"; }
success() { echo -e "${GREEN}✓${NC} $*"; }
warn()    { echo -e "${YELLOW}⚠${NC} $*"; }
error()   { echo -e "${RED}✗${NC} $*" >&2; }

usage() {
  cat <<EOF
Usage: $(basename "$0") <name> [OPTIONS]

Create a new OpenClaw agent with standard directory structure and configs.

Options:
  --model <model>      LLM model (default: anthropic/claude-sonnet-4-5)
  --host <mac|gcp>     Target host (default: mac)
  --channel <channel>  Primary channel: telegram, slack, none (default: none)
  -h, --help           Show this help

Examples:
  $(basename "$0") research-bot
  $(basename "$0") nechie-assistant --model anthropic/claude-opus-4-6 --channel telegram
  $(basename "$0") reb-monitor --host gcp --model anthropic/claude-haiku-4-5
EOF
  exit 0
}

# Defaults
MODEL="anthropic/claude-sonnet-4-5"
HOST="mac"
CHANNEL="none"
AGENT_NAME=""

# Parse args
while [[ $# -gt 0 ]]; do
  case "$1" in
    -h|--help) usage ;;
    --model) MODEL="$2"; shift 2 ;;
    --host) HOST="$2"; shift 2 ;;
    --channel) CHANNEL="$2"; shift 2 ;;
    -*) error "Unknown option: $1"; usage ;;
    *) AGENT_NAME="$1"; shift ;;
  esac
done

if [[ -z "$AGENT_NAME" ]]; then
  error "Agent name is required."
  usage
fi

# Validate name (lowercase, hyphens, no spaces)
if [[ ! "$AGENT_NAME" =~ ^[a-z0-9][a-z0-9-]*$ ]]; then
  error "Agent name must be lowercase alphanumeric with hyphens (e.g., 'research-bot')."
  exit 1
fi

OPENCLAW_DIR="$HOME/.openclaw"
AGENT_DIR="$OPENCLAW_DIR/agents/$AGENT_NAME"

# Check for conflicts
if [[ -d "$AGENT_DIR" ]]; then
  error "Agent '$AGENT_NAME' already exists at $AGENT_DIR"
  exit 1
fi

info "Creating agent: $AGENT_NAME"
info "Model: $MODEL"
info "Host: $HOST"
info "Channel: $CHANNEL"

# Create directory structure
mkdir -p "$AGENT_DIR/agent"
mkdir -p "$AGENT_DIR/workspace/memory"
mkdir -p "$AGENT_DIR/workspace/config"

# --- Agent Config ---
cat > "$AGENT_DIR/agent/openclaw.json" <<CONF
{
  "name": "$AGENT_NAME",
  "model": "$MODEL",
  "channel": "$CHANNEL",
  "host": "$HOST",
  "created": "$(date -u +%Y-%m-%dT%H:%M:%SZ)"
}
CONF

# --- Models Config ---
cat > "$AGENT_DIR/agent/models.json" <<MODELS
{
  "default": "$MODEL",
  "fallback": "anthropic/claude-haiku-4-5",
  "coding": "$MODEL",
  "fast": "anthropic/claude-haiku-4-5"
}
MODELS

# --- Workspace Files ---
cat > "$AGENT_DIR/workspace/AGENTS.md" <<'AGENTS'
# AGENTS.md

## Every Session
1. Read `memory/active-tasks.md` — resume any in-progress work
2. Read `SOUL.md` — this is who you are
3. Read `USER.md` — this is who you're helping
4. Read `memory/` daily notes for recent context

## Memory
- Daily notes: `memory/YYYY-MM-DD.md`
- Long-term: `MEMORY.md`
- Active tasks: `memory/active-tasks.md`

## Safety
- Don't exfiltrate private data
- `trash` > `rm`
- No credentials in memory files
- When in doubt, ask
AGENTS

cat > "$AGENT_DIR/workspace/SOUL.md" <<'SOUL'
# SOUL — How I show up

## Name
[AGENT_NAME]

## Core personality
[Define personality traits, communication style, and operating modes]

## Default voice
[Describe tone, formality level, humor style]
SOUL
# Replace placeholder
sed -i '' "s/\[AGENT_NAME\]/$AGENT_NAME/" "$AGENT_DIR/workspace/SOUL.md" 2>/dev/null || true

cat > "$AGENT_DIR/workspace/IDENTITY.md" <<IDENTITY
# IDENTITY
**Name:** $AGENT_NAME
**Created:** $(date +%Y-%m-%d)
IDENTITY

cat > "$AGENT_DIR/workspace/USER.md" <<'USER'
# USER.md
[Define the primary user this agent serves]
USER

cat > "$AGENT_DIR/workspace/HEARTBEAT.md" <<'HEARTBEAT'
# HEARTBEAT.md

Objective: run reliable maintenance with minimal token usage.

Rules:
- Report only actionable items.
- Return `HEARTBEAT_OK` when no action is needed.
HEARTBEAT

cat > "$AGENT_DIR/workspace/TOOLS.md" <<'TOOLS'
# TOOLS.md - Local Notes
[Document installed CLIs, auth status, and key file locations]
TOOLS

cat > "$AGENT_DIR/workspace/MEMORY.md" <<MEMORY
# MEMORY — Curated Long-Term Memory
*Created: $(date +%Y-%m-%d)*

## Identity & Context
- Agent: $AGENT_NAME
- Model: $MODEL
- Host: $HOST
MEMORY

cat > "$AGENT_DIR/workspace/memory/active-tasks.md" <<'TASKS'
# Active Tasks

## In Progress
(none yet)

## Blocked
(none yet)

## Recently Completed
(none yet)
TASKS

cat > "$AGENT_DIR/workspace/memory/session-state.md" <<'STATE'
# Session State
Last session: (none)
STATE

# Make scripts executable if they exist
chmod +x "$AGENT_DIR/workspace/scripts/"*.sh 2>/dev/null || true

echo ""
success "Agent '$AGENT_NAME' created at $AGENT_DIR"
echo ""
info "Next steps:"
echo "  1. Edit SOUL.md   — define personality and voice"
echo "  2. Edit USER.md   — define who this agent serves"
echo "  3. Restart gateway — openclaw gateway restart"
echo ""
if [[ "$CHANNEL" == "telegram" ]]; then
  warn "Telegram channel selected — you'll need to configure a bot token."
fi
