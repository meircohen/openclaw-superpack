#!/bin/bash
# URGENT: Reb - Fix cron delivery to Agent Room
# Run this immediately: bash scripts/REB-URGENT-FIX-CRONS.sh

echo "🛡️ Fixing Reb cron delivery..."

# Backup
crontab -l > /tmp/crontab-backup-$(date +%Y%m%d-%H%M%S).txt

# Fix: Change all DM deliveries to Agent Room group
crontab -l | sed 's/telegram:950148415/telegram:-5208406508/g' | crontab -

echo "✅ Crons updated to post to Agent Room group"
echo ""
echo "Verify:"
crontab -l | grep "telegram:-5208406508" | head -5

# Confirm in Agent Room
if [ -f "$HOME/.openclaw/workspace/scripts/agent-room-broadcast.js" ]; then
  cd "$HOME/.openclaw/workspace" && node scripts/agent-room-broadcast.js reb success "Cron delivery fixed - now posting to Agent Room"
fi
