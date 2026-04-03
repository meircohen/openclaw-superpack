#!/bin/bash

# Auto-Learning Hook
# Extracts learnings from agent task results and updates memory

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

if [ $# -lt 3 ]; then
    echo "Usage: $0 <agent-id> <task-description> <task-result>"
    echo "Example: $0 chef 'Plan Shabbos menu' 'Suggested dairy-free menu for 6 people...'"
    exit 1
fi

AGENT_ID="$1"
TASK_DESC="$2"
TASK_RESULT="$3"

# Extract learnings using pattern matching (fast, no LLM calls)
extract_learnings() {
    local agent_id="$1"
    local task_desc="$2"
    local result="$3"
    
    # Combine task description and result for analysis
    local full_text="$task_desc $result"
    local learnings=()
    
    # User preference patterns
    if echo "$full_text" | grep -qi "dairy.free\|no.dairy\|lactose.intolerant"; then
        learnings+=("User prefers dairy-free options")
    fi
    
    if echo "$full_text" | grep -qi "kosher"; then
        learnings+=("User keeps kosher")
    fi
    
    if echo "$full_text" | grep -qi "vegetarian\|vegan\|no.meat"; then
        learnings+=("User has vegetarian/vegan preferences")
    fi
    
    if echo "$full_text" | grep -qi "gluten.free\|celiac\|no.gluten"; then
        learnings+=("User requires gluten-free options")
    fi
    
    # Family/personal info patterns
    if echo "$full_text" | grep -qiE "(family.of|people|kids|children).*[0-9]"; then
        local family_info=$(echo "$full_text" | grep -ioE "(family.of|people|kids|children).{0,20}" | head -1)
        if [ -n "$family_info" ]; then
            learnings+=("Family size: $family_info")
        fi
    fi
    
    # Name patterns
    if echo "$full_text" | grep -qiE "(meir|nechie|suzy|raizy|leib|gavi)" && [ "$agent_id" != "user" ]; then
        local names=$(echo "$full_text" | grep -ioE "(meir|nechie|suzy|raizy|leib|gavi)" | sort -u | tr '\n' ' ')
        if [ -n "$names" ]; then
            learnings+=("Family members mentioned: $names")
        fi
    fi
    
    # Location patterns
    if echo "$full_text" | grep -qiE "(orlando|fort.lauderdale|florida|fl)"; then
        local location=$(echo "$full_text" | grep -ioE "(orlando|fort.lauderdale|florida|fl)" | head -1)
        learnings+=("Location context: $location")
    fi
    
    # Time/event patterns
    if echo "$full_text" | grep -qiE "(pesach|passover|shabbos|sabbath)"; then
        local event=$(echo "$full_text" | grep -ioE "(pesach|passover|shabbos|sabbath).{0,30}" | head -1)
        learnings+=("Event context: $event")
    fi
    
    # Task completion patterns
    if echo "$full_text" | grep -qiE "(completed|finished|done|approved|successful)"; then
        learnings+=("Completed task: $task_desc")
    fi
    
    if echo "$full_text" | grep -qiE "(rejected|failed|blocked|needs.revision)"; then
        learnings+=("Task needs work: $task_desc")
    fi
    
    # Agent-specific patterns
    case "$agent_id" in
        "chef")
            if echo "$full_text" | grep -qiE "(recipe|menu|ingredients|cooking|meal)"; then
                # Extract recipe/menu preferences
                if echo "$full_text" | grep -qiE "(liked|enjoyed|approved|delicious)"; then
                    learnings+=("User approved recipe/menu from task: $task_desc")
                fi
            fi
            ;;
        "fitness-coach")
            if echo "$full_text" | grep -qiE "(workout|exercise|training|recovery|hrv|heart.rate)"; then
                # Extract fitness metrics
                local metrics=$(echo "$full_text" | grep -ioE "(recovery.*[0-9]+%|hrv.*[0-9]+ms|heart.rate.*[0-9]+)" | head -3)
                if [ -n "$metrics" ]; then
                    learnings+=("Fitness metrics: $metrics")
                fi
            fi
            ;;
        "travel-planner")
            if echo "$full_text" | grep -qiE "(flight|hotel|restaurant|destination)"; then
                # Extract travel preferences
                if echo "$full_text" | grep -qiE "(preferred|liked|booked|confirmed)"; then
                    learnings+=("Travel preference from task: $task_desc")
                fi
            fi
            ;;
        "social-media-manager")
            if echo "$full_text" | grep -qiE "(tweet|post|engagement|followers)"; then
                # Extract social media insights
                local engagement=$(echo "$full_text" | grep -ioE "(engagement.*[0-9]+|followers.*[0-9]+)" | head -2)
                if [ -n "$engagement" ]; then
                    learnings+=("Social metrics: $engagement")
                fi
            fi
            ;;
    esac
    
    # Return learnings
    printf '%s\n' "${learnings[@]}"
}

# Extract and save learnings
log_info "Analyzing task result for learnings..."

learnings=$(extract_learnings "$AGENT_ID" "$TASK_DESC" "$TASK_RESULT")

if [ -z "$learnings" ]; then
    log_info "No specific learnings extracted from task result"
    exit 0
fi

# Save each learning
echo "$learnings" | while IFS= read -r learning; do
    if [ -n "$learning" ]; then
        log_info "Recording learning: $learning"
        bash "$SCRIPT_DIR/agent-memory.sh" write "$AGENT_ID" "$learning"
    fi
done

log_info "Auto-learning complete for agent: $AGENT_ID"