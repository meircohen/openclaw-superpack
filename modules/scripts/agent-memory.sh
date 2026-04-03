#!/bin/bash

# Agent Memory Manager
# Manages persistent memory for specialist agents

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Colors
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

log_info() {
    echo -e "${GREEN}[INFO]${NC} $1" >&2
}

log_warn() {
    echo -e "${YELLOW}[WARN]${NC} $1" >&2
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1" >&2
}

usage() {
    echo "Agent Memory Manager"
    echo "Usage: $0 <command> <agent-id> [content]"
    echo ""
    echo "Commands:"
    echo "  write <agent-id> <learning>  - Record something the agent learned"
    echo "  read <agent-id>              - Read agent's complete memory"
    echo "  search <query>               - Search across all agent memories"
    echo "  list                         - List all agents with memory"
    echo ""
    echo "Examples:"
    echo "  $0 write chef \"Nechie is dairy-free kosher. No cheese in Shabbos menus.\""
    echo "  $0 read chef"
    echo "  $0 search \"dairy\""
    exit 1
}

get_memory_file() {
    local agent_id="$1"
    echo "$HOME/.openclaw/workspace-$agent_id/memory/agent-learnings.md"
}

ensure_memory_file() {
    local agent_id="$1"
    local memory_file=$(get_memory_file "$agent_id")
    local memory_dir="$(dirname "$memory_file")"
    
    # Create memory directory if it doesn't exist
    if [ ! -d "$memory_dir" ]; then
        mkdir -p "$memory_dir"
        log_info "Created memory directory: $memory_dir"
    fi
    
    # Create memory file with header if it doesn't exist
    if [ ! -f "$memory_file" ]; then
        cat > "$memory_file" << EOF
# Agent Learnings — $(echo "$agent_id" | sed 's/-/ /g' | sed 's/\b\w/\U&/g')
*Auto-updated from task interactions*

## User Preferences

## Past Tasks

## Key Context

EOF
        log_info "Created memory file: $memory_file"
    fi
    
    echo "$memory_file"
}

write_learning() {
    local agent_id="$1"
    local learning="$2"
    local timestamp="[$(date '+%Y-%m-%d %H:%M')]"
    
    if [ -z "$learning" ]; then
        log_error "Learning content cannot be empty"
        exit 1
    fi
    
    local memory_file=$(ensure_memory_file "$agent_id")
    
    # Determine which section to add to based on content
    local section="Key Context"
    if [[ "$learning" =~ (prefer|like|dislike|allergic|kosher|vegetarian|vegan) ]]; then
        section="User Preferences"
    elif [[ "$learning" =~ (completed|suggested|designed|built|approved|rejected) ]]; then
        section="Past Tasks"
    fi
    
    # Check if this learning already exists to avoid duplicates
    if grep -F "$learning" "$memory_file" >/dev/null 2>&1; then
        log_warn "Learning already exists, skipping: $learning"
        return 0
    fi
    
    # Add learning to appropriate section
    # Use awk to insert after the section header
    awk -v section="## $section" -v entry="- $timestamp $learning" '
        $0 ~ section {print; in_section=1; next}
        in_section && /^## / && !/^## '"$section"'/ {print entry; print ""; in_section=0}
        in_section && /^$/ && !added {print entry; print ""; added=1}
        {print}
        END {if (in_section && !added) print entry}
    ' "$memory_file" > "$memory_file.tmp" && mv "$memory_file.tmp" "$memory_file"
    
    log_info "Added learning to $agent_id: $learning"
}

read_memory() {
    local agent_id="$1"
    local memory_file=$(get_memory_file "$agent_id")
    
    if [ ! -f "$memory_file" ]; then
        log_warn "No memory file found for agent: $agent_id"
        return 1
    fi
    
    cat "$memory_file"
}

search_memories() {
    local query="$1"
    local found=0
    
    log_info "Searching all agent memories for: $query"
    echo ""
    
    for workspace_dir in "$HOME"/.openclaw/workspace-*/; do
        if [ ! -d "$workspace_dir" ]; then
            continue
        fi
        
        local agent_id=$(basename "$workspace_dir" | sed 's/workspace-//')
        local memory_file="$workspace_dir/memory/agent-learnings.md"
        
        if [ -f "$memory_file" ] && grep -qi "$query" "$memory_file"; then
            echo -e "${GREEN}=== $agent_id ===${NC}"
            grep -i --color=always "$query" "$memory_file" || true
            echo ""
            found=1
        fi
    done
    
    if [ $found -eq 0 ]; then
        log_warn "No matches found for: $query"
    fi
}

list_agents() {
    log_info "Agents with memory:"
    echo ""
    
    for workspace_dir in "$HOME"/.openclaw/workspace-*/; do
        if [ ! -d "$workspace_dir" ]; then
            continue
        fi
        
        local agent_id=$(basename "$workspace_dir" | sed 's/workspace-//')
        local memory_file="$workspace_dir/memory/agent-learnings.md"
        
        if [ -f "$memory_file" ]; then
            local line_count=$(wc -l < "$memory_file")
            local learning_count=$(grep -c "^- \[" "$memory_file" 2>/dev/null || echo "0")
            echo -e "${GREEN}$agent_id${NC} - $learning_count learnings ($line_count lines)"
        fi
    done
}

# Main logic
if [ $# -lt 1 ]; then
    usage
fi

case "$1" in
    "write")
        if [ $# -lt 3 ]; then
            log_error "Write command requires agent-id and learning content"
            usage
        fi
        write_learning "$2" "$3"
        ;;
    "read")
        if [ $# -lt 2 ]; then
            log_error "Read command requires agent-id"
            usage
        fi
        read_memory "$2"
        ;;
    "search")
        if [ $# -lt 2 ]; then
            log_error "Search command requires query"
            usage
        fi
        search_memories "$2"
        ;;
    "list")
        list_agents
        ;;
    *)
        log_error "Unknown command: $1"
        usage
        ;;
esac