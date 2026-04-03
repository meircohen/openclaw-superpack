#!/bin/bash

# Proactive Agent Trigger Engine
# Evaluates all enabled triggers and returns those that should fire
# Usage: bash scripts/agent-router/proactive-check.sh

CONFIG_FILE="config/agent-router/proactive-triggers.json"
SCRIPT_DIR="$(dirname "$0")"

# Check if config exists
if [[ ! -f "$CONFIG_FILE" ]]; then
  echo "Error: Config file not found: $CONFIG_FILE" >&2
  exit 1
fi

# Parse JSON and check each trigger
FIRES=()

# Read triggers from JSON (using basic parsing since jq might not be available)
TRIGGERS=$(grep -A 20 '"triggers"' "$CONFIG_FILE" | grep -E '(id|agent|condition|check|action|enabled)')

# For now, implement manual trigger checking
# This is a simplified version - in production, proper JSON parsing would be better

CURRENT_HOUR=$(date +"%H" | sed 's/^0//')
CURRENT_DAY=$(date +"%A")

check_trigger() {
  local id="$1"
  local agent="$2"
  local condition="$3"
  local check="$4"
  local action="$5"
  local enabled="$6"
  
  # Skip if disabled
  [[ "$enabled" != "true" ]] && return
  
  local should_fire=false
  local reason=""
  
  case "$id" in
    "cfo-tax-deadline")
      if bash "$SCRIPT_DIR/conditions/check-pending.sh" "pending_items contains 'tax deadline'"; then
        should_fire=true
        reason="Tax deadline found in pending items"
      fi
      ;;
    "fitness-coach-low-recovery")
      if bash "$SCRIPT_DIR/conditions/check-whoop.sh" "whoop_recovery < 50 for 3 consecutive days"; then
        should_fire=true
        reason="WHOOP recovery below 50%"
      fi
      ;;
    "chef-shabbos-menu")
      if bash "$SCRIPT_DIR/conditions/check-time.sh" "day_of_week == Wednesday"; then
        should_fire=true
        reason="It's Wednesday, Shabbos is coming"
      fi
      ;;
    "travel-planner-pesach")
      if bash "$SCRIPT_DIR/conditions/check-pesach.sh" "days_until_pesach <= 30 AND has_unbooked_items"; then
        should_fire=true
        reason="Pesach approaching with unbooked items"
      fi
      ;;
    "wellness-guide-late-night")
      if bash "$SCRIPT_DIR/conditions/check-time.sh" "current_hour >= 1 AND current_hour <= 5 AND user_active"; then
        should_fire=true
        reason="User active during late night hours"
      fi
      ;;
    "ops-manager-cron-health")
      if bash "$SCRIPT_DIR/conditions/check-crons.sh" "cron_errors > 2"; then
        should_fire=true
        reason="Multiple cron failures detected"
      fi
      ;;
    "executive-assistant-morning-brief")
      if bash "$SCRIPT_DIR/conditions/check-time.sh" "day_of_week in Monday-Friday AND hour == 7"; then
        should_fire=true
        reason="Weekday 7 AM morning briefing time"
      fi
      ;;
    "money-coach-spending-alert")
      # This trigger is disabled by default
      should_fire=false
      ;;
  esac
  
  if [[ "$should_fire" == "true" ]]; then
    FIRES+=("{\"id\": \"$id\", \"agent\": \"$agent\", \"action\": \"$action\", \"reason\": \"$reason\"}")
  fi
}

# Check each trigger manually (simplified approach)
check_trigger "cfo-tax-deadline" "cfo" "days_until <= 3" "pending_items contains 'tax deadline'" "Remind Meir about upcoming tax deadline with priority actions" "true"

check_trigger "fitness-coach-low-recovery" "fitness-coach" "whoop_recovery < 50 for 3 consecutive days" "bash scripts/whoop.sh summary | grep Recovery" "Suggest rest protocol and recovery optimization" "true"

check_trigger "chef-shabbos-menu" "chef" "day_of_week == Wednesday" "" "Suggest Shabbos dinner menu based on agent memory (preferences, recent meals)" "true"

check_trigger "travel-planner-pesach" "travel-planner" "days_until_pesach <= 30 AND has_unbooked_items" "pending_items contains 'Pesach' OR 'Orlando'" "Check Pesach trip status and flag unbooked items" "true"

check_trigger "wellness-guide-late-night" "wellness-guide" "current_hour >= 1 AND current_hour <= 5 AND user_active" "" "Gently suggest Meir should sleep based on time and WHOOP data" "true"

check_trigger "ops-manager-cron-health" "ops-manager" "cron_errors > 2" "openclaw cron list | grep error | wc -l" "Report failing crons with recommended fixes" "true"

check_trigger "executive-assistant-morning-brief" "executive-assistant" "day_of_week in Monday-Friday AND hour == 7" "" "Compile morning briefing: calendar, pending items, overnight agent activity, WHOOP recovery" "true"

check_trigger "money-coach-spending-alert" "money-coach" "monthly_spending > budget_threshold" "" "Alert about unusual spending patterns" "false"

# Output JSON result
if [[ ${#FIRES[@]} -gt 0 ]]; then
  FIRES_JSON=$(printf '%s,' "${FIRES[@]}" | sed 's/,$//')
  echo "{\"fires\": [$FIRES_JSON]}"
else
  echo "{\"fires\": []}"
fi