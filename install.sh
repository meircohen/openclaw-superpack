#!/usr/bin/env bash
set -euo pipefail

# ============================================================================
# OpenClaw Superpack Installer
# One command to transform a fresh OpenClaw into a fully-powered AI agent system
# ============================================================================

VERSION="1.0.0"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
MODULES_DIR="$SCRIPT_DIR/modules"
OPENCLAW_HOME="${OPENCLAW_HOME:-$HOME/.openclaw}"
WORKSPACE="$OPENCLAW_HOME/workspace"
AGENTS_DIR="$OPENCLAW_HOME/agents"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
BOLD='\033[1m'
NC='\033[0m'

info()    { echo -e "${BLUE}[INFO]${NC} $*"; }
success() { echo -e "${GREEN}[OK]${NC} $*"; }
warn()    { echo -e "${YELLOW}[WARN]${NC} $*"; }
fail()    { echo -e "${RED}[ERROR]${NC} $*"; exit 1; }

header() {
  echo ""
  echo -e "${BOLD}${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
  echo -e "${BOLD}${CYAN}  $*${NC}"
  echo -e "${BOLD}${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
  echo ""
}

prompt_yn() {
  local prompt="$1"
  local default="${2:-y}"
  local yn
  if [[ "$default" == "y" ]]; then
    read -rp "$(echo -e "${BOLD}$prompt [Y/n]:${NC} ")" yn
    yn="${yn:-y}"
  else
    read -rp "$(echo -e "${BOLD}$prompt [y/N]:${NC} ")" yn
    yn="${yn:-n}"
  fi
  [[ "$yn" =~ ^[Yy] ]]
}

copy_module() {
  local module="$1"
  local dst="$2"
  local src="$MODULES_DIR/$module"

  if [[ ! -d "$src" ]]; then
    warn "Module source not found: $src"
    return 1
  fi

  mkdir -p "$dst"
  cp -R "$src"/* "$dst"/ 2>/dev/null || cp -R "$src"/. "$dst"/ 2>/dev/null || true
  success "Installed: $module"
}

# ============================================================================
# Banner
# ============================================================================

echo ""
echo -e "${BOLD}${CYAN}"
cat << 'BANNER'
   ___                    ____ _
  / _ \ _ __   ___ _ __  / ___| | __ ___      __
 | | | | '_ \ / _ \ '_ \| |   | |/ _` \ \ /\ / /
 | |_| | |_) |  __/ | | | |___| | (_| |\ V  V /
  \___/| .__/ \___|_| |_|\____|_|\__,_| \_/\_/
       |_|
  ____                                         _
 / ___| _   _ _ __   ___ _ __ _ __   __ _  ___| | __
 \___ \| | | | '_ \ / _ \ '__| '_ \ / _` |/ __| |/ /
  ___) | |_| | |_) |  __/ |  | |_) | (_| | (__|   <
 |____/ \__,_| .__/ \___|_|  | .__/ \__,_|\___|_|\_\
             |_|             |_|
BANNER
echo -e "${NC}"
echo -e "  ${BOLD}v${VERSION}${NC} -- Transform OpenClaw into a fully-powered AI agent system"
echo ""

# ============================================================================
# Step 1: Prerequisites
# ============================================================================

header "Step 1: Checking Prerequisites"

PREREQS_OK=true

if [[ -d "$OPENCLAW_HOME" ]]; then
  success "OpenClaw found at $OPENCLAW_HOME"
else
  warn "OpenClaw directory not found at $OPENCLAW_HOME"
  if prompt_yn "Create OpenClaw directory structure?"; then
    mkdir -p "$WORKSPACE" "$AGENTS_DIR"
    success "Created OpenClaw directory structure"
  else
    fail "OpenClaw is required. Install it first."
  fi
fi

command -v python3 &>/dev/null && success "python3 found: $(python3 --version 2>&1)" || { fail "Python 3 is required"; PREREQS_OK=false; }
command -v node    &>/dev/null && success "node found: $(node --version)"             || warn "Node.js not found (needed for MCP servers)"
command -v git     &>/dev/null && success "git found"                                 || { fail "git is required"; PREREQS_OK=false; }

[[ "$PREREQS_OK" == "true" ]] || fail "Missing prerequisites. Install them and retry."

# ============================================================================
# Step 2: Module Selection
# ============================================================================

header "Step 2: Select Modules"

echo "Available modules:"
echo ""
echo -e "  ${BOLD}1. mesh${NC}           -- Multi-LLM routing, cost optimization, health monitoring"
echo -e "  ${BOLD}2. intelligence${NC}   -- Signal collection, LLM classification, autonomous actions"
echo -e "  ${BOLD}3. heartbeat${NC}      -- Runtime operations and maintenance automation"
echo -e "  ${BOLD}4. agents${NC}         -- 55 specialized AI agent templates"
echo -e "  ${BOLD}5. delegation${NC}     -- Task delegation pipelines, voice guides, verification"
echo -e "  ${BOLD}6. skills${NC}         -- Skills library and research raid patterns"
echo -e "  ${BOLD}7. mcp-servers${NC}    -- MCP server configurations"
echo -e "  ${BOLD}8. scripts${NC}        -- Utility scripts and integration templates"
echo -e "  ${BOLD}9. docs${NC}           -- Architecture docs, guides, and reference"
echo ""

declare -A MODULES
ALL_MODULES=(mesh intelligence heartbeat agents delegation skills mcp-servers scripts docs)

if prompt_yn "Install all modules?"; then
  for m in "${ALL_MODULES[@]}"; do MODULES[$m]=true; done
else
  for m in "${ALL_MODULES[@]}"; do
    prompt_yn "  Install $m?" && MODULES[$m]=true || MODULES[$m]=false
  done
fi

# ============================================================================
# Step 3: Install Selected Modules
# ============================================================================

header "Step 3: Installing Modules"

INSTALLED=()

if [[ "${MODULES[mesh]:-}" == "true" ]]; then
  copy_module "mesh" "$WORKSPACE/mesh"
  INSTALLED+=("mesh")
fi

if [[ "${MODULES[intelligence]:-}" == "true" ]]; then
  copy_module "intelligence" "$WORKSPACE/intelligence"
  INSTALLED+=("intelligence")
fi

if [[ "${MODULES[heartbeat]:-}" == "true" ]]; then
  copy_module "heartbeat" "$WORKSPACE/heartbeat"
  cp "$MODULES_DIR/heartbeat/HEARTBEAT-TEMPLATE.md" "$WORKSPACE/HEARTBEAT.md" 2>/dev/null || true
  INSTALLED+=("heartbeat")
fi

if [[ "${MODULES[agents]:-}" == "true" ]]; then
  for agent_dir in "$MODULES_DIR/agents"/*/; do
    agent_name=$(basename "$agent_dir")
    mkdir -p "$AGENTS_DIR/$agent_name"
    cp -R "$agent_dir"* "$AGENTS_DIR/$agent_name/" 2>/dev/null || true
  done
  cp "$MODULES_DIR/agents/ROSTER.md" "$WORKSPACE/AGENTS.md" 2>/dev/null || true
  success "Installed: agents (55 agent templates)"
  INSTALLED+=("agents")
fi

if [[ "${MODULES[delegation]:-}" == "true" ]]; then
  copy_module "delegation" "$WORKSPACE/skills/delegation"
  INSTALLED+=("delegation")
fi

if [[ "${MODULES[skills]:-}" == "true" ]]; then
  copy_module "skills" "$WORKSPACE/skills/mesh-skills"
  INSTALLED+=("skills")
fi

if [[ "${MODULES[mcp-servers]:-}" == "true" ]]; then
  copy_module "mcp-servers" "$WORKSPACE/mcp-servers"
  INSTALLED+=("mcp-servers")
fi

if [[ "${MODULES[scripts]:-}" == "true" ]]; then
  copy_module "scripts" "$WORKSPACE/scripts"
  find "$WORKSPACE/scripts" -name "*.sh" -exec chmod +x {} \; 2>/dev/null || true
  INSTALLED+=("scripts")
fi

if [[ "${MODULES[docs]:-}" == "true" ]]; then
  copy_module "docs" "$WORKSPACE/docs"
  INSTALLED+=("docs")
fi

# ============================================================================
# Step 4: Configuration Templates
# ============================================================================

header "Step 4: Setting Up Configuration"

mkdir -p "$WORKSPACE/config"
mkdir -p "$WORKSPACE/shared/handoffs"
mkdir -p "$WORKSPACE/shared/escalations"
mkdir -p "$WORKSPACE/templates"
mkdir -p "$WORKSPACE/memory/blocks"

# Copy configs (don't overwrite existing)
for f in "$SCRIPT_DIR/config"/*; do
  fname=$(basename "$f")
  if [[ ! -f "$WORKSPACE/config/$fname" ]]; then
    cp "$f" "$WORKSPACE/config/$fname"
    info "Created: config/$fname"
  else
    info "Preserved existing: config/$fname"
  fi
done

# Copy templates
cp -Rn "$SCRIPT_DIR/templates"/* "$WORKSPACE/templates/" 2>/dev/null || true
info "Templates installed"

# Copy setup wizard
cp "$SCRIPT_DIR/setup-wizard.md" "$WORKSPACE/setup-wizard.md" 2>/dev/null || true
info "Setup wizard installed"

# Install Python dependencies
if command -v pip3 &>/dev/null; then
  pip3 install --quiet --upgrade pyyaml requests 2>/dev/null && \
    success "Python dependencies installed" || \
    warn "Some Python deps failed -- run: pip3 install pyyaml requests"
fi

# ============================================================================
# Step 5: Summary
# ============================================================================

header "Installation Complete!"

echo -e "${BOLD}Installed modules:${NC}"
for mod in "${INSTALLED[@]}"; do
  echo -e "  ${GREEN}+${NC} $mod"
done

echo ""
echo -e "${BOLD}Next steps:${NC}"
echo ""
echo "  1. Restart your OpenClaw gateway"
echo "  2. OpenClaw will find setup-wizard.md and walk you through personalization"
echo "  3. Or manually configure: $WORKSPACE/config/"
echo ""
echo -e "  ${BOLD}Quick reference:${NC}"
echo "    Architecture docs:    $WORKSPACE/docs/architecture.md"
echo "    Getting started:      $WORKSPACE/docs/getting-started.md"
echo "    Agent roster:         $WORKSPACE/AGENTS.md"
echo "    Bootstrap checklist:  $WORKSPACE/templates/BOOTSTRAP.md"
echo ""

if [[ "${MODULES[mesh]:-}" == "true" ]]; then
  echo -e "  ${BOLD}Mesh:${NC} python3 $WORKSPACE/mesh/health.py"
fi
if [[ "${MODULES[intelligence]:-}" == "true" ]]; then
  echo -e "  ${BOLD}Intelligence:${NC} cd $WORKSPACE/intelligence && bash init.sh"
fi
echo ""
echo -e "${BOLD}${CYAN}Your AI army is ready. Welcome to the Superpack.${NC}"
echo ""

# --- Claude Peers MCP (inter-session messaging) ---
echo ""
echo "=== Installing Claude Peers MCP ==="
if command -v bun >/dev/null 2>&1 && command -v claude >/dev/null 2>&1; then
  if [ ! -d "$HOME/claude-peers-mcp" ]; then
    git clone https://github.com/louislva/claude-peers-mcp.git "$HOME/claude-peers-mcp" 2>/dev/null
    cd "$HOME/claude-peers-mcp" && bun install 2>/dev/null
    claude mcp add --scope user --transport stdio claude-peers -- bun "$HOME/claude-peers-mcp/server.ts" 2>/dev/null
    echo "  ✓ Claude Peers installed"
  else
    echo "  ✓ Claude Peers already installed"
  fi
else
  echo "  ⚠ Skipping Claude Peers (needs bun + claude)"
fi

# --- Coasts (container isolation) ---
echo ""
echo "=== Installing Coasts ==="
if command -v docker >/dev/null 2>&1; then
  if ! command -v coast >/dev/null 2>&1; then
    eval "$(curl -fsSL https://coasts.dev/install)" 2>/dev/null
    echo "  ✓ Coasts installed"
    echo "  → Run 'coast daemon install' to start at login"
  else
    echo "  ✓ Coasts already installed ($(coast --version 2>/dev/null))"
  fi
  # Copy Coastfile template
  if [ -f "templates/Coastfile" ] && [ ! -f "$WORKSPACE/Coastfile" ]; then
    cp templates/Coastfile "$WORKSPACE/Coastfile"
    echo "  ✓ Coastfile template copied to workspace"
  fi
else
  echo "  ⚠ Skipping Coasts (Docker not installed)"
fi

echo ""
echo "============================================"
echo "  Installation complete!"
echo "  Restart your OpenClaw gateway, then say:"
echo "  'What can you do?' to see all features"
echo "============================================"
