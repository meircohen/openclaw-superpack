#!/bin/bash
# Time Awareness System for OpenClaw Fleet
# Handles Shabbos detection, Jewish holidays, and time-sensitive scheduling
# Source this script before any cron job or agent operation

set -euo pipefail

# Configuration
WORKSPACE_ROOT="${OPENCLAW_WORKSPACE:-$HOME/.openclaw/workspace}"
TIME_STATE_FILE="$WORKSPACE_ROOT/config/time-awareness-state.json"
SHABBOS_THRESHOLD_MINUTES=18  # Minutes before/after candle lighting for buffer
LOG_FILE="$WORKSPACE_ROOT/logs/time-awareness.log"

# Ensure log directory exists
mkdir -p "$(dirname "$LOG_FILE")"

# Logging function
log_event() {
    echo "[$(date -Iseconds)] $1" >> "$LOG_FILE"
}

# Get current date/time info
get_current_time_info() {
    local current_epoch=$(date +%s)
    local current_date=$(date +%Y-%m-%d)
    local current_time=$(date +%H:%M)
    local day_of_week=$(date +%u)  # 1=Monday, 7=Sunday
    
    echo "{
        \"timestamp\": \"$(date -Iseconds)\",
        \"epoch\": $current_epoch,
        \"date\": \"$current_date\",
        \"time\": \"$current_time\",
        \"day_of_week\": $day_of_week,
        \"timezone\": \"$(date +%Z)\"
    }"
}

# Get precise Shabbos times from Hebcal API
get_shabbos_times_precise() {
    local HEBCAL_SCRIPT="$WORKSPACE_ROOT/scripts/apis/hebcal.sh"
    
    if [ ! -x "$HEBCAL_SCRIPT" ]; then
        return 1  # Hebcal not available
    fi
    
    local DATA
    DATA=$("$HEBCAL_SCRIPT" shabbat 2>/dev/null) || return 1
    
    # Extract candle lighting and havdalah times as ISO8601 strings
    local CANDLES HAVDALAH
    CANDLES=$(echo "$DATA" | grep -o '"date":"[^"]*","category":"candles"' | grep -o '[0-9][0-9][0-9][0-9]-[0-9][0-9]-[0-9][0-9]T[0-9][0-9]:[0-9][0-9]:[0-9][0-9]-[0-9][0-9]:[0-9][0-9]' | head -1)
    HAVDALAH=$(echo "$DATA" | grep -o '"date":"[^"]*","category":"havdalah"' | grep -o '[0-9][0-9][0-9][0-9]-[0-9][0-9]-[0-9][0-9]T[0-9][0-9]:[0-9][0-9]:[0-9][0-9]-[0-9][0-9]:[0-9][0-9]' | head -1)
    
    if [ -z "$CANDLES" ] || [ -z "$HAVDALAH" ]; then
        return 1
    fi
    
    # Convert to Unix timestamps (remove timezone for macOS date parsing)
    local CANDLES_CLEAN="${CANDLES%%-*}"
    local HAVDALAH_CLEAN="${HAVDALAH%%-*}"
    
    local CANDLES_TS HAVDALAH_TS
    CANDLES_TS=$(date -j -f "%Y-%m-%dT%H:%M:%S" "$CANDLES_CLEAN" +%s 2>/dev/null) || return 1
    HAVDALAH_TS=$(date -j -f "%Y-%m-%dT%H:%M:%S" "$HAVDALAH_CLEAN" +%s 2>/dev/null) || return 1
    
    echo "$CANDLES_TS $HAVDALAH_TS"
    return 0
}

# Check if current time is within Shabbos
# Shabbos starts Friday evening at candle lighting, ends Saturday at Havdalah
# Uses precise Hebcal API times with fallback to approximation
is_shabbos() {
    local current_epoch=$(date +%s)
    local day_of_week=$(date +%u)  # 1=Monday, 7=Sunday
    local current_hour=$(date +%H)
    
    # Try precise Hebcal times first
    local TIMES CANDLES_TS HAVDALAH_TS
    if TIMES=$(get_shabbos_times_precise); then
        CANDLES_TS=$(echo "$TIMES" | awk '{print $1}')
        HAVDALAH_TS=$(echo "$TIMES" | awk '{print $2}')
        
        if [ "$current_epoch" -ge "$CANDLES_TS" ] && [ "$current_epoch" -lt "$HAVDALAH_TS" ]; then
            return 0  # It's Shabbos (precise)
        fi
        return 1
    fi
    
    # Fallback to approximation if Hebcal unavailable
    # Friday evening - assume candle lighting around 18:00 (6 PM) with buffer
    if [ "$day_of_week" -eq 5 ] && [ "$current_hour" -ge 17 ]; then
        return 0  # It's Shabbos (approximate)
    fi
    
    # All day Saturday until evening
    if [ "$day_of_week" -eq 6 ]; then
        # Saturday before 21:00 (9 PM) - conservative estimate for Havdalah
        if [ "$current_hour" -lt 21 ]; then
            return 0  # It's Shabbos (approximate)
        fi
    fi
    
    return 1  # Not Shabbos
}

# Check if current date is a major Jewish holiday
# This is a simplified check - in production would integrate with Hebrew calendar API
is_jewish_holiday() {
    local current_date=$(date +%Y-%m-%d)
    
    # Major holidays (approximate dates - should be updated with proper Hebrew calendar)
    # Rosh Hashanah, Yom Kippur, Sukkot, Shemini Atzeret, Simchat Torah
    # Chanukah, Tu BiShvat, Purim, Passover, Lag BaOmer, Shavuot
    
    # For now, return false - will be enhanced with proper Hebrew calendar integration
    return 1
}

# Get Meir's current state/availability
# Based on time of day, location, calendar, etc.
get_meir_state() {
    local current_hour=$(date +%H)
    local day_of_week=$(date +%u)
    
    local state="active"
    local availability="available"
    
    # Sleep hours (typically 2 AM - 8 AM)
    if [ "$current_hour" -ge 2 ] && [ "$current_hour" -lt 8 ]; then
        state="sleeping"
        availability="unavailable"
    fi
    
    # Shabbos state
    if is_shabbos; then
        state="shabbos"
        availability="limited"
    fi
    
    # Jewish holiday state
    if is_jewish_holiday; then
        state="holiday"
        availability="limited"
    fi
    
    echo "{
        \"state\": \"$state\",
        \"availability\": \"$availability\",
        \"can_receive_notifications\": $([ "$availability" = "unavailable" ] && echo "false" || echo "true"),
        \"can_receive_urgent_only\": $([ "$availability" = "limited" ] && echo "true" || echo "false")
    }"
}

# Determine if an operation should proceed
should_proceed() {
    local operation_type="$1"
    local urgency="${2:-normal}"  # normal, urgent, critical
    
    local meir_state=$(get_meir_state)
    local availability=$(echo "$meir_state" | grep -o '"availability":"[^"]*"' | cut -d'"' -f4)
    
    case "$operation_type" in
        "notification")
            case "$urgency" in
                "critical")
                    return 0  # Always proceed for critical notifications
                    ;;
                "urgent")
                    [ "$availability" != "unavailable" ]
                    return $?
                    ;;
                "normal")
                    [ "$availability" = "available" ]
                    return $?
                    ;;
            esac
            ;;
        "email_send"|"message_send")
            [ "$availability" = "available" ]
            return $?
            ;;
        "financial_operation")
            if is_shabbos || is_jewish_holiday; then
                return 1  # Never proceed with financial operations on Shabbos/holidays
            fi
            return 0
            ;;
        "maintenance"|"backup")
            # Maintenance can proceed during Shabbos but quietly
            return 0
            ;;
        "research"|"analysis")
            return 0  # Always proceed - these don't disturb
            ;;
        *)
            return 0  # Default: proceed
            ;;
    esac
}

# Update time awareness state file
update_state() {
    local time_info=$(get_current_time_info)
    local meir_state=$(get_meir_state)
    local is_shabbos_now=$(is_shabbos && echo "true" || echo "false")
    local is_holiday_now=$(is_jewish_holiday && echo "true" || echo "false")
    
    cat > "$TIME_STATE_FILE" << EOF
{
    "last_updated": $(echo "$time_info" | grep '"timestamp"' | cut -d'"' -f4 | sed 's/^/"/; s/$/"/'),
    "current_time": $time_info,
    "meir_state": $meir_state,
    "is_shabbos": $is_shabbos_now,
    "is_jewish_holiday": $is_holiday_now,
    "system_status": "active"
}
EOF
    
    log_event "State updated - Shabbos: $is_shabbos_now, Holiday: $is_holiday_now, Meir: $(echo "$meir_state" | grep -o '"state":"[^"]*"' | cut -d'"' -f4)"
}

# Main function to check time awareness before any operation
check_time_awareness() {
    local operation_type="${1:-general}"
    local urgency="${2:-normal}"
    
    update_state
    
    if should_proceed "$operation_type" "$urgency"; then
        log_event "PROCEED: $operation_type ($urgency)"
        return 0
    else
        log_event "SKIP: $operation_type ($urgency) - time restrictions apply"
        return 1
    fi
}

# Command line interface
case "${1:-}" in
    "check")
        check_time_awareness "${2:-general}" "${3:-normal}"
        ;;
    "state")
        update_state
        cat "$TIME_STATE_FILE"
        ;;
    "is-shabbos")
        is_shabbos && echo "true" || echo "false"
        ;;
    "meir-state")
        get_meir_state
        ;;
    "should-proceed")
        should_proceed "${2:-general}" "${3:-normal}" && echo "proceed" || echo "skip"
        ;;
    *)
        echo "Usage: $0 {check|state|is-shabbos|meir-state|should-proceed} [operation_type] [urgency]"
        echo "Operations: notification, email_send, message_send, financial_operation, maintenance, backup, research, analysis"
        echo "Urgency: normal, urgent, critical"
        exit 1
        ;;
esac