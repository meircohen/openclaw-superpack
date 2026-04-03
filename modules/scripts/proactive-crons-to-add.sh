#!/bin/bash

# OpenClaw Cron Commands for Proactive Agent Triggers
# DO NOT EXECUTE - Review and add manually

echo "=== OpenClaw Cron Commands for Proactive Triggers ==="
echo ""
echo "# 1. Morning briefing and checks (7 AM weekdays)"
echo 'openclaw cron add proactive-morning "0 7 * * 1-5" "bash scripts/agent-router/proactive-check.sh && echo \"Morning proactive triggers checked\""'
echo ""

echo "# 2. Chef Shabbos menu (Wednesday 10 AM)"  
echo 'openclaw cron add proactive-midweek "0 10 * * 3" "bash scripts/agent-router/proactive-check.sh | grep -q chef-shabbos-menu && echo \"🔔 Chef - Wednesday Shabbos planning\""'
echo ""

echo "# 3. Travel planner Pesach check (Monday and Thursday 9 AM)"
echo 'openclaw cron add proactive-pesach "0 9 * * 1,4" "bash scripts/agent-router/proactive-check.sh | grep -q travel-planner-pesach && echo \"🔔 Travel Planner - Pesach check\""'
echo ""

echo "# 4. Wellness guide late night check (1-5 AM, every 30 min)"
echo 'openclaw cron add proactive-night-owl "*/30 1-5 * * *" "bash scripts/agent-router/proactive-check.sh | grep -q wellness-guide-late-night && echo \"🔔 Wellness Guide - Late night activity detected\""'
echo ""

echo "# 5. Ops manager cron health (every 6 hours)"
echo 'openclaw cron add proactive-ops "0 */6 * * *" "bash scripts/agent-router/proactive-check.sh | grep -q ops-manager-cron-health && echo \"🔔 Ops Manager - Cron health check\""'
echo ""

echo "=== Alternative: Single proactive cron that handles all triggers ==="
echo ""
echo "# Master proactive cron (runs every 30 minutes, checks all conditions)"
echo 'openclaw cron add proactive-master "*/30 * * * *" "bash scripts/agent-router/proactive-master.sh"'
echo ""

echo "=== Usage Instructions ==="
echo "1. Review each cron command above"
echo "2. Copy and paste the ones you want to add"
echo "3. Run them in the OpenClaw environment"
echo "4. Use 'openclaw cron list' to verify they were added"
echo "5. Use 'openclaw cron remove <name>' to remove if needed"