#!/bin/bash

# Ensures an agent's workspace exists and has minimum required files

set -e

if [ $# -ne 1 ]; then
    echo "Usage: $0 <agent-id>"
    echo "Example: $0 fitness-coach"
    exit 1
fi

AGENT_ID="$1"
WORKSPACE_DIR="$HOME/.openclaw/workspace-$AGENT_ID"
MAIN_WORKSPACE="$HOME/.openclaw/workspace"
CAPABILITIES_FILE="config/agent-router/capabilities.json"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

log_info() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

log_warn() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Check if agent exists in capabilities
if ! grep -q "\"id\": \"$AGENT_ID\"" "$CAPABILITIES_FILE" 2>/dev/null; then
    log_error "Agent '$AGENT_ID' not found in capabilities.json"
    exit 1
fi

log_info "Setting up workspace for agent: $AGENT_ID"

# Create workspace directory if it doesn't exist
if [ ! -d "$WORKSPACE_DIR" ]; then
    log_info "Creating workspace directory: $WORKSPACE_DIR"
    mkdir -p "$WORKSPACE_DIR"
    
    # Create .openclaw subdirectory
    mkdir -p "$WORKSPACE_DIR/.openclaw"
fi

# Create memory directory
if [ ! -d "$WORKSPACE_DIR/memory" ]; then
    mkdir -p "$WORKSPACE_DIR/memory"
fi

# Generate SOUL.md if it doesn't exist
if [ ! -f "$WORKSPACE_DIR/SOUL.md" ]; then
    log_info "Generating SOUL.md for $AGENT_ID"
    python3 scripts/agent-router/generate-soul.py "$AGENT_ID"
fi

# Create symlinks to shared resources if they don't exist
# Scripts symlink
if [ ! -L "$WORKSPACE_DIR/scripts" ] && [ ! -d "$WORKSPACE_DIR/scripts" ]; then
    log_info "Creating scripts symlink"
    ln -s "$MAIN_WORKSPACE/scripts" "$WORKSPACE_DIR/scripts"
fi

# Skills symlink  
if [ ! -L "$WORKSPACE_DIR/skills" ] && [ ! -d "$WORKSPACE_DIR/skills" ]; then
    log_info "Creating skills symlink"
    ln -s "$MAIN_WORKSPACE/skills" "$WORKSPACE_DIR/skills"
fi

# Config symlink
if [ ! -L "$WORKSPACE_DIR/config" ] && [ ! -d "$WORKSPACE_DIR/config" ]; then
    log_info "Creating config symlink"
    ln -s "$MAIN_WORKSPACE/config" "$WORKSPACE_DIR/config"
fi

# Memory blocks symlink (read-only context)
if [ ! -L "$WORKSPACE_DIR/memory/blocks" ] && [ ! -d "$WORKSPACE_DIR/memory/blocks" ]; then
    log_info "Creating memory/blocks symlink"
    if [ -d "$MAIN_WORKSPACE/memory/blocks" ]; then
        ln -s "$MAIN_WORKSPACE/memory/blocks" "$WORKSPACE_DIR/memory/blocks"
    fi
fi

# Copy standard workspace files if they don't exist
STANDARD_FILES=("AGENTS.md" "BOOTSTRAP.md" "HEARTBEAT.md" "TOOLS.md" "USER.md")

for file in "${STANDARD_FILES[@]}"; do
    if [ ! -f "$WORKSPACE_DIR/$file" ]; then
        if [ -f "$MAIN_WORKSPACE/$file" ]; then
            log_info "Copying $file"
            cp "$MAIN_WORKSPACE/$file" "$WORKSPACE_DIR/$file"
        else
            log_warn "$file not found in main workspace, skipping"
        fi
    fi
done

# Create basic IDENTITY.md if it doesn't exist
if [ ! -f "$WORKSPACE_DIR/IDENTITY.md" ]; then
    log_info "Creating IDENTITY.md for $AGENT_ID"
    
    # Extract agent info from capabilities.json
    AGENT_NAME=$(jq -r ".agents[] | select(.id == \"$AGENT_ID\") | .name" "$CAPABILITIES_FILE")
    AGENT_DESC=$(jq -r ".agents[] | select(.id == \"$AGENT_ID\") | .description" "$CAPABILITIES_FILE")
    
    # Try to infer emoji from name/role
    case "$AGENT_ID" in
        *fitness*|*coach*) EMOJI="🏋️" ;;
        *chef*|*cook*) EMOJI="👨‍🍳" ;;
        *finance*|*cfo*|*money*) EMOJI="💰" ;;
        *code*|*architect*|*developer*) EMOJI="👨‍💻" ;;
        *design*|*ux*) EMOJI="🎨" ;;
        *security*|*audit*) EMOJI="🔒" ;;
        *travel*) EMOJI="✈️" ;;
        *social*|*media*) EMOJI="📱" ;;
        *legal*) EMOJI="⚖️" ;;
        *health*|*wellness*) EMOJI="🌱" ;;
        *study*|*learn*) EMOJI="📚" ;;
        *innovation*) EMOJI="🚀" ;;
        *ops*|*operations*) EMOJI="⚙️" ;;
        *prediction*) EMOJI="🔮" ;;
        *executive*|*ceo*) EMOJI="🏢" ;;
        *research*) EMOJI="🔬" ;;
        *data*|*analyst*) EMOJI="📊" ;;
        *growth*) EMOJI="📈" ;;
        *product*|*manager*) EMOJI="📋" ;;
        *strategy*|*strategist*) EMOJI="🧠" ;;
        *team*|*lead*) EMOJI="👥" ;;
        *qa*|*test*) EMOJI="🧪" ;;
        *devops*|*infra*) EMOJI="🛠️" ;;
        *mobile*|*app*) EMOJI="📱" ;;
        *ai*|*expert*) EMOJI="🤖" ;;
        *writer*|*doc*) EMOJI="📝" ;;
        *personal*|*shopper*) EMOJI="🛍️" ;;
        *translate*) EMOJI="🌐" ;;
        *accountability*) EMOJI="🎯" ;;
        *performance*) EMOJI="⚡" ;;
        *rapid*|*prototype*) EMOJI="⚡" ;;
        *api*) EMOJI="🔌" ;;
        *prompt*|*engineer*) EMOJI="🔧" ;;
        *backend*) EMOJI="⚙️" ;;
        *frontend*) EMOJI="🌐" ;;
        *engineering*) EMOJI="👷" ;;
        *review*) EMOJI="🔍" ;;
        *assistant*) EMOJI="🗂️" ;;
        *) EMOJI="🤖" ;;
    esac
    
    cat > "$WORKSPACE_DIR/IDENTITY.md" << EOF
# IDENTITY

**Name:** $AGENT_NAME
**Username:** @${AGENT_ID//-/_}
**Emoji:** $EMOJI
**Role:** $AGENT_DESC
**Created:** $(date -u +"%Y-%m-%d %H:%M:%S UTC")
EOF
fi

# Create basic MEMORY.md if it doesn't exist
if [ ! -f "$WORKSPACE_DIR/MEMORY.md" ]; then
    log_info "Creating MEMORY.md for $AGENT_ID"
    cat > "$WORKSPACE_DIR/MEMORY.md" << EOF
# MEMORY — $AGENT_NAME

## Agent Memory Context

This file contains agent-specific memory and learning context.

## Task History
<!-- Agent task completions will be logged here -->

## Learnings
<!-- Key insights and patterns from task execution -->

## Notes
<!-- Any agent-specific notes or context -->

---
*Last updated: $(date)*
EOF
fi

log_info "Agent workspace ready: $WORKSPACE_DIR"
echo "✓ Workspace prepared for $AGENT_ID"