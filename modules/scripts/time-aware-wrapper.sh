#!/bin/bash
# Time-Aware Wrapper for Cron Jobs and Agent Operations
# Usage: time-aware-wrapper.sh <operation_type> <urgency> <command> [args...]

set -euo pipefail

WORKSPACE_ROOT="${OPENCLAW_WORKSPACE:-$HOME/.openclaw/workspace}"
TIME_AWARENESS_SCRIPT="$WORKSPACE_ROOT/scripts/time-awareness.sh"

# Check if time-awareness script exists
if [ ! -f "$TIME_AWARENESS_SCRIPT" ]; then
    echo "ERROR: Time awareness script not found at $TIME_AWARENESS_SCRIPT"
    exit 1
fi

# Parse arguments
operation_type="${1:-general}"
urgency="${2:-normal}"
shift 2

command_to_run="$@"

# Check time awareness
if "$TIME_AWARENESS_SCRIPT" check "$operation_type" "$urgency"; then
    echo "Time check passed for $operation_type ($urgency) - executing: $command_to_run"
    exec $command_to_run
else
    echo "Time check failed for $operation_type ($urgency) - skipping: $command_to_run"
    exit 0
fi