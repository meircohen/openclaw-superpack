#!/bin/bash

# Agent Router Execution Bridge
# Routes a task to the appropriate agent and executes it through that agent's persona

set -e

if [ $# -lt 2 ]; then
    echo "Usage: $0 <agent-id> <task-description>"
    echo "Example: $0 fitness-coach 'Design a 3-day workout plan for a beginner'"
    exit 1
fi

AGENT_ID="$1"
TASK="$2"
WORKSPACE_DIR="$HOME/.openclaw/workspace-$AGENT_ID"
SOUL_FILE="$WORKSPACE_DIR/SOUL.md"
CAPABILITIES_FILE="config/agent-router/capabilities.json"
TOOLS_CONFIG_FILE="config/agent-router/agent-tools.json"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

log_info() {
    echo -e "${GREEN}[INFO]${NC} $1" >&2
}

log_warn() {
    echo -e "${YELLOW}[WARN]${NC} $1" >&2
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1" >&2
}

# Check if agent exists in capabilities
if ! grep -q "\"id\": \"$AGENT_ID\"" "$CAPABILITIES_FILE" 2>/dev/null; then
    log_error "Agent '$AGENT_ID' not found in capabilities.json"
    exit 1
fi

# Ensure agent workspace is ready
log_info "Ensuring agent workspace is ready..."
if ! bash scripts/agent-router/ensure-agent-ready.sh "$AGENT_ID"; then
    log_error "Failed to prepare agent workspace"
    exit 1
fi

# Read agent's SOUL.md
if [ ! -f "$SOUL_FILE" ]; then
    log_error "SOUL.md not found for agent $AGENT_ID at $SOUL_FILE"
    exit 1
fi

AGENT_SOUL=$(cat "$SOUL_FILE")

# Read agent's memory
log_info "Loading agent memory..."
AGENT_MEMORY=""
if bash scripts/agent-router/agent-memory.sh read "$AGENT_ID" >/dev/null 2>&1; then
    AGENT_MEMORY=$(bash scripts/agent-router/agent-memory.sh read "$AGENT_ID")
    log_info "Loaded memory for $AGENT_ID ($(echo "$AGENT_MEMORY" | wc -l) lines)"
else
    log_warn "No existing memory found for $AGENT_ID"
fi

# Get agent capabilities
AGENT_CAPABILITIES=$(jq -r ".agents[] | select(.id == \"$AGENT_ID\") | {name, description, task_types, keywords}" "$CAPABILITIES_FILE")

# Get available tools for this agent type
AGENT_TOOLS="all standard tools"
if [ -f "$TOOLS_CONFIG_FILE" ]; then
    AGENT_TOOLS=$(jq -r ".\"$AGENT_ID\" // []" "$TOOLS_CONFIG_FILE" 2>/dev/null || echo "all standard tools")
fi

# Build composite prompt
COMPOSITE_PROMPT="$AGENT_SOUL

## Current Task Assignment
You have been assigned the following task by the main coordinator:

**Task:** $TASK

## Your Capabilities 
$AGENT_CAPABILITIES

## Available Tools
You have access to: $AGENT_TOOLS

## Agent Memory
$(if [ -n "$AGENT_MEMORY" ]; then echo "Your accumulated knowledge from past interactions:"; echo "$AGENT_MEMORY"; else echo "No prior memory recorded yet."; fi)

## Context
- Working directory: $WORKSPACE_DIR
- You can access all workspace scripts via scripts/ symlink
- You can use skills/ directory for specialized capabilities
- Memory context available in memory/blocks/
- Shared configuration in config/

## Instructions
1. Execute the assigned task completely
2. Use your expertise and available tools
3. Provide a clear summary of what you accomplished
4. If you encounter blockers, state them clearly
5. Stay in character as defined in your SOUL.md

Execute the task now."

log_info "Executing task through agent: $AGENT_ID"
log_info "Task: $TASK"

# Create a temporary file for the prompt
TEMP_PROMPT_FILE=$(mktemp)
echo "$COMPOSITE_PROMPT" > "$TEMP_PROMPT_FILE"

# For now, we'll simulate agent execution by running the task through
# a simple process that uses the agent's SOUL.md as context
log_info "Executing task through agent workspace..."

# Create execution context
EXECUTION_CONTEXT="
Working as: $AGENT_ID
Task: $TASK
Workspace: $WORKSPACE_DIR

Agent Context:
$AGENT_SOUL

Execute this task using the agent's expertise and available tools.
Provide a clear result summary.
"

# Execute the task in the agent's context
# This is a placeholder for actual sessions_spawn integration
RESULT=$(cat << EOF
Agent: $AGENT_ID
Task Completed: $TASK

This is a simulated response from the $AGENT_ID agent.
The agent would execute the task using its SOUL.md personality and available tools.

To implement full execution:
1. Integrate with OpenClaw gateway sessions_spawn API
2. Create isolated agent sessions with the composite prompt
3. Return actual execution results

For now, this confirms the routing and workspace setup works.
Agent workspace ready at: $WORKSPACE_DIR
EOF
)

# Clean up
rm -f "$TEMP_PROMPT_FILE"

if [ $? -eq 0 ]; then
    log_info "Task completed successfully"
    
    # Extract learnings from the task result
    log_info "Extracting learnings from task execution..."
    if bash scripts/agent-router/auto-learn.sh "$AGENT_ID" "$TASK" "$RESULT"; then
        log_info "Learnings captured successfully"
    else
        log_warn "Failed to capture learnings, but task completed"
    fi
    
    echo "$RESULT"
else
    log_error "Task execution failed"
    exit 1
fi