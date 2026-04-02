#!/bin/bash
# Time-Aware Heartbeat System
# Integrates time awareness into the main agent heartbeat cycle

set -euo pipefail

WORKSPACE_ROOT="${OPENCLAW_WORKSPACE:-$HOME/.openclaw/workspace}"
cd "$WORKSPACE_ROOT"

# Source time awareness
source scripts/time-awareness.sh

# Log heartbeat execution
log_event "Starting time-aware heartbeat"

# Get current time state
TIME_STATE=$(scripts/time-awareness.sh state)
IS_SHABBOS=$(echo "$TIME_STATE" | grep -o '"is_shabbos":[^,}]*' | cut -d':' -f2)
IS_HOLIDAY=$(echo "$TIME_STATE" | grep -o '"is_jewish_holiday":[^,}]*' | cut -d':' -f2)
MEIR_STATE=$(echo "$TIME_STATE" | grep -o '"state":"[^"]*"' | cut -d'"' -f4)

# Determine heartbeat mode
HEARTBEAT_MODE="normal"
if [ "$IS_SHABBOS" = "true" ]; then
    HEARTBEAT_MODE="shabbos"
elif [ "$IS_HOLIDAY" = "true" ]; then
    HEARTBEAT_MODE="holiday"
elif [ "$MEIR_STATE" = "sleeping" ]; then
    HEARTBEAT_MODE="quiet"
fi

log_event "Heartbeat mode: $HEARTBEAT_MODE"

# Execute heartbeat based on mode
case "$HEARTBEAT_MODE" in
    "shabbos")
        log_event "Shabbos mode - minimal operations only"
        # Only critical monitoring, no notifications unless urgent
        if check_time_awareness "maintenance" "critical"; then
            # Critical system monitoring only
            echo "🕯️ Shabbos mode - monitoring only"
        fi
        ;;
    "holiday")
        log_event "Holiday mode - limited operations"
        if check_time_awareness "maintenance" "urgent"; then
            echo "🏠 Holiday mode - essential monitoring only"
        fi
        ;;
    "quiet")
        log_event "Quiet mode - Meir is sleeping"
        # Background maintenance OK, but no notifications
        if check_time_awareness "maintenance" "normal"; then
            echo "😴 Quiet mode - background maintenance only"
        fi
        ;;
    "normal")
        log_event "Normal mode - full operations"
        echo "✅ Normal mode - full heartbeat operations enabled"
        
        # Run normal heartbeat operations
        if check_time_awareness "notification" "normal"; then
            # Normal heartbeat notifications are allowed
            echo "📡 Heartbeat notifications enabled"
            if [ -x "scripts/process-notifications.sh" ]; then
                bash scripts/process-notifications.sh
            fi
        fi
        ;;
esac

# Update agent room with heartbeat status if in normal mode
if [ "$HEARTBEAT_MODE" = "normal" ] && check_time_awareness "notification" "normal"; then
    if [ -f "scripts/agent-room-broadcast.js" ]; then
        node scripts/agent-room-broadcast.js pulse heartbeat "Heartbeat: $HEARTBEAT_MODE mode active"
    fi
fi

# Pause/resume agents based on time awareness
node scripts/time-aware-scheduler.js pause 2>/dev/null || true
node scripts/time-aware-scheduler.js resume 2>/dev/null || true

log_event "Completed time-aware heartbeat in $HEARTBEAT_MODE mode"
