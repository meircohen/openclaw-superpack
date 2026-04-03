#!/bin/bash

# Sets up workspace for ALL agents in capabilities.json

set -e

CAPABILITIES_FILE="config/agent-router/capabilities.json"
SETUP_SCRIPT="scripts/agent-router/ensure-agent-ready.sh"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
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

log_header() {
    echo -e "${BLUE}[SETUP]${NC} $1"
}

if [ ! -f "$CAPABILITIES_FILE" ]; then
    log_error "Capabilities file not found: $CAPABILITIES_FILE"
    exit 1
fi

if [ ! -f "$SETUP_SCRIPT" ]; then
    log_error "Setup script not found: $SETUP_SCRIPT"
    exit 1
fi

log_header "Setting up workspaces for all agents..."

# Extract all agent IDs from capabilities.json
AGENT_IDS=$(jq -r '.agents[].id' "$CAPABILITIES_FILE")

if [ -z "$AGENT_IDS" ]; then
    log_error "No agents found in capabilities.json"
    exit 1
fi

TOTAL_AGENTS=$(echo "$AGENT_IDS" | wc -l)
CURRENT=0
SUCCESSFUL=0
FAILED=0

log_info "Found $TOTAL_AGENTS agents to set up"

# Process each agent
while IFS= read -r agent_id; do
    ((CURRENT++))
    echo ""
    log_header "[$CURRENT/$TOTAL_AGENTS] Setting up: $agent_id"
    
    if bash "$SETUP_SCRIPT" "$agent_id"; then
        ((SUCCESSFUL++))
        log_info "✓ $agent_id setup completed"
    else
        ((FAILED++))
        log_error "✗ $agent_id setup failed"
    fi
done <<< "$AGENT_IDS"

echo ""
log_header "Setup Summary"
log_info "Total agents: $TOTAL_AGENTS"
log_info "Successful: $SUCCESSFUL"

if [ $FAILED -gt 0 ]; then
    log_error "Failed: $FAILED"
else
    log_info "Failed: $FAILED"
fi

# Count how many agents now have SOUL.md files
SOUL_COUNT=$(find "$HOME/.openclaw" -name "workspace-*" -type d -exec test -f {}/SOUL.md \; -print | wc -l)
log_info "Agents with SOUL.md: $SOUL_COUNT"

# Show workspace directories created
echo ""
log_header "Agent workspaces:"
find "$HOME/.openclaw" -name "workspace-*" -type d | sort | sed 's|.*workspace-|  - |'

echo ""
if [ $FAILED -eq 0 ]; then
    log_info "🎉 All agents set up successfully!"
else
    log_warn "⚠️  Some agents failed to set up. Check errors above."
fi