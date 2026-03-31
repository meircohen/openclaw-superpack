#!/usr/bin/env bash
set -euo pipefail

# ============================================================
#  OpenClaw Superpack — Full Stack Installer
#  One command. Everything installed.
# ============================================================

SUPERPACK_DIR="$(cd "$(dirname "$0")" && pwd)"
OPENCLAW_HOME="${OPENCLAW_HOME:-$HOME/.openclaw}"
WORKSPACE="$OPENCLAW_HOME/workspace"

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
NC='\033[0m'

banner() {
  echo ""
  echo -e "${CYAN}╔══════════════════════════════════════════╗${NC}"
  echo -e "${CYAN}║   🦀  OpenClaw Superpack Installer  🦀   ║${NC}"
  echo -e "${CYAN}╚══════════════════════════════════════════╝${NC}"
  echo ""
}

step() { echo -e "${GREEN}[✓]${NC} $1"; }
warn() { echo -e "${YELLOW}[!]${NC} $1"; }
fail() { echo -e "${RED}[✗]${NC} $1"; exit 1; }

# ── Phase 1: Prerequisite checks ──────────────────────────
check_prereqs() {
  echo -e "${CYAN}── Checking prerequisites ──${NC}"

  command -v git    >/dev/null 2>&1 || fail "git is not installed"
  step "git found"

  command -v python3 >/dev/null 2>&1 || fail "python3 is not installed"
  step "python3 found ($(python3 --version 2>&1))"

  command -v node   >/dev/null 2>&1 || fail "node is not installed"
  step "node found ($(node --version))"

  command -v docker >/dev/null 2>&1 || warn "docker not found — some features need it"
  command -v docker >/dev/null 2>&1 && step "docker found"

  if [ ! -d "$OPENCLAW_HOME" ]; then
    fail "OpenClaw not found at $OPENCLAW_HOME — install OpenClaw first"
  fi
  step "OpenClaw installation found at $OPENCLAW_HOME"

  echo ""
}

# ── Phase 2: Copy modules ─────────────────────────────────
install_modules() {
  echo -e "${CYAN}── Installing modules ──${NC}"

  # Mesh system
  if [ -d "$SUPERPACK_DIR/mesh" ]; then
    cp -R "$SUPERPACK_DIR/mesh" "$WORKSPACE/mesh-superpack-staging"
    # Merge into existing mesh or create fresh
    if [ -d "$WORKSPACE/mesh" ]; then
      cp -Rn "$WORKSPACE/mesh-superpack-staging/"* "$WORKSPACE/mesh/" 2>/dev/null || true
      rm -rf "$WORKSPACE/mesh-superpack-staging"
      step "Mesh system merged into existing mesh/"
    else
      mv "$WORKSPACE/mesh-superpack-staging" "$WORKSPACE/mesh"
      step "Mesh system installed to mesh/"
    fi
  fi

  # Intelligence pipeline
  if [ -d "$SUPERPACK_DIR/intelligence" ]; then
    mkdir -p "$WORKSPACE/intelligence"
    cp -R "$SUPERPACK_DIR/intelligence/"* "$WORKSPACE/intelligence/"
    step "Intelligence pipeline installed"
  fi

  # Agents
  if [ -d "$SUPERPACK_DIR/agents" ] && [ "$(ls -A "$SUPERPACK_DIR/agents" 2>/dev/null)" ]; then
    mkdir -p "$WORKSPACE/agents"
    cp -R "$SUPERPACK_DIR/agents/"* "$WORKSPACE/agents/"
    step "Agent configs installed"
  fi

  # Skills
  if [ -d "$SUPERPACK_DIR/skills" ] && [ "$(ls -A "$SUPERPACK_DIR/skills" 2>/dev/null)" ]; then
    mkdir -p "$WORKSPACE/skills"
    cp -R "$SUPERPACK_DIR/skills/"* "$WORKSPACE/skills/"
    step "Skills installed"
  fi

  # Delegation
  if [ -d "$SUPERPACK_DIR/delegation" ] && [ "$(ls -A "$SUPERPACK_DIR/delegation" 2>/dev/null)" ]; then
    mkdir -p "$WORKSPACE/delegation"
    cp -R "$SUPERPACK_DIR/delegation/"* "$WORKSPACE/delegation/"
    step "Delegation framework installed"
  fi

  # Heartbeat
  if [ -d "$SUPERPACK_DIR/heartbeat" ] && [ "$(ls -A "$SUPERPACK_DIR/heartbeat" 2>/dev/null)" ]; then
    mkdir -p "$WORKSPACE/heartbeat"
    cp -R "$SUPERPACK_DIR/heartbeat/"* "$WORKSPACE/heartbeat/"
    step "Heartbeat system installed"
  fi

  # Templates
  if [ -d "$SUPERPACK_DIR/templates" ] && [ "$(ls -A "$SUPERPACK_DIR/templates" 2>/dev/null)" ]; then
    mkdir -p "$WORKSPACE/templates"
    cp -R "$SUPERPACK_DIR/templates/"* "$WORKSPACE/templates/"
    step "Templates installed"
  fi

  # Config
  if [ -d "$SUPERPACK_DIR/config" ] && [ "$(ls -A "$SUPERPACK_DIR/config" 2>/dev/null)" ]; then
    mkdir -p "$WORKSPACE/config"
    cp -Rn "$SUPERPACK_DIR/config/"* "$WORKSPACE/config/" 2>/dev/null || true
    step "Config templates installed (existing configs preserved)"
  fi

  echo ""
}

# ── Phase 3: Register MCP servers ─────────────────────────
register_mcp_servers() {
  echo -e "${CYAN}── Registering MCP servers ──${NC}"

  CLAUDE_SETTINGS="$HOME/.claude/settings.json"

  if [ ! -f "$CLAUDE_SETTINGS" ]; then
    warn "Claude settings not found at $CLAUDE_SETTINGS"
    warn "You'll need to manually register MCP servers"
    echo ""
    return
  fi

  # List the MCP servers the user should have
  step "MCP servers to register:"
  echo "       - context-mode (semantic code search)"
  echo "       - context7 (library docs)"
  echo "       - claude-peers (multi-instance coordination)"
  echo "       - mesh-mcp (mesh orchestration)"
  echo ""
  warn "Auto-registration skipped to avoid overwriting your config."
  warn "Add these to your claude settings.json or run:"
  echo "       claude mcp add context-mode"
  echo "       claude mcp add context7"
  echo "       claude mcp add claude-peers"
  echo ""
}

# ── Phase 4: Install dependencies ─────────────────────────
install_deps() {
  echo -e "${CYAN}── Installing dependencies ──${NC}"

  # Python deps
  if command -v pip3 >/dev/null 2>&1; then
    pip3 install --quiet --upgrade fastmcp pyyaml requests 2>/dev/null && \
      step "Python dependencies installed (fastmcp, pyyaml, requests)" || \
      warn "Some Python deps failed — install manually: pip3 install fastmcp pyyaml requests"
  else
    warn "pip3 not found — install Python deps manually: pip3 install fastmcp pyyaml requests"
  fi

  # Node deps (if package.json exists in superpack)
  if [ -f "$SUPERPACK_DIR/package.json" ]; then
    (cd "$SUPERPACK_DIR" && npm install --silent 2>/dev/null) && \
      step "Node dependencies installed" || \
      warn "npm install failed — run manually in $SUPERPACK_DIR"
  fi

  echo ""
}

# ── Phase 5: Install Coasts CLI ───────────────────────────
install_coasts() {
  echo -e "${CYAN}── Installing Coasts CLI ──${NC}"

  if command -v coast >/dev/null 2>&1; then
    step "coast CLI already installed"
  else
    if command -v npm >/dev/null 2>&1; then
      npm install -g @openclaw/coast 2>/dev/null && \
        step "coast CLI installed globally" || \
        warn "coast CLI install failed — install manually: npm i -g @openclaw/coast"
    else
      warn "npm not found — install coast CLI manually"
    fi
  fi

  echo ""
}

# ── Phase 6: Write template configs ───────────────────────
write_configs() {
  echo -e "${CYAN}── Writing template configs ──${NC}"

  # Create shared directory structure if missing
  mkdir -p "$WORKSPACE/shared/handoffs"
  mkdir -p "$WORKSPACE/shared/escalations"

  # Mesh config template
  if [ ! -f "$WORKSPACE/mesh/config/openclaw.yaml" ]; then
    mkdir -p "$WORKSPACE/mesh/config"
    cat > "$WORKSPACE/mesh/config/openclaw.yaml" << 'YAML'
# OpenClaw Mesh — Gateway Configuration
# Edit this file to match your setup

gateway:
  host: localhost
  port: 8420
  log_level: info

providers:
  # Uncomment and configure providers you use
  # anthropic:
  #   api_key: ${ANTHROPIC_API_KEY}
  # openai:
  #   api_key: ${OPENAI_API_KEY}
  # perplexity:
  #   api_key: ${PERPLEXITY_API_KEY}

routing:
  default_provider: anthropic
  fallback_chain: [anthropic, openai]
YAML
    step "Mesh gateway config template written"
  else
    step "Mesh gateway config already exists (preserved)"
  fi

  echo ""
}

# ── Phase 7: Final instructions ───────────────────────────
finish() {
  echo -e "${CYAN}══════════════════════════════════════════════${NC}"
  echo -e "${GREEN}  ✅  OpenClaw Superpack installed!${NC}"
  echo -e "${CYAN}══════════════════════════════════════════════${NC}"
  echo ""
  echo "  What's installed:"
  echo "    • Mesh system (multi-AI orchestration)"
  echo "    • Intelligence pipeline (collect → filter → act → digest)"
  echo "    • Agent configs & delegation framework"
  echo "    • Skills library"
  echo "    • Heartbeat monitoring"
  echo "    • MCP server configs"
  echo ""
  echo -e "  ${YELLOW}Next steps:${NC}"
  echo "    1. Restart your OpenClaw gateway"
  echo "    2. Read docs/setup-wizard.md to connect your integrations"
  echo "    3. Run: coast status  — to verify everything"
  echo ""
  echo "  Setup wizard:  $SUPERPACK_DIR/docs/setup-wizard.md"
  echo "  Full docs:     $SUPERPACK_DIR/docs/"
  echo ""
}

# ── Main ──────────────────────────────────────────────────
banner
check_prereqs
install_modules
register_mcp_servers
install_deps
install_coasts
write_configs
finish
