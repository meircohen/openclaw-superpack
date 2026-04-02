#!/bin/bash
# Nechie Onboarding Initialization
# Run once to set up HomeBot for Nechie's first use

set -e

WORKSPACE_ROOT="$HOME/.openclaw/workspace"
ONBOARDING_CONFIG="$WORKSPACE_ROOT/config/integrations/nechie-onboarding.json"
STATE_FILE="$WORKSPACE_ROOT/data/nechie-onboarding-state.json"

echo "🏠 HomeBot Onboarding Initialization"
echo "===================================="
echo ""

# Check if already initialized
if [[ -f "$STATE_FILE" ]]; then
  STARTED=$(jq -r '.started_at' "$STATE_FILE")
  echo "⚠️ Onboarding already initialized on $STARTED"
  echo ""
  read -p "Re-initialize? (y/n) " -n 1 -r
  echo
  if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    exit 0
  fi
fi

# Load onboarding config
if [[ ! -f "$ONBOARDING_CONFIG" ]]; then
  echo "❌ Onboarding config not found: $ONBOARDING_CONFIG"
  exit 1
fi

echo "📝 Loaded onboarding config"
echo ""

# Create data directory
mkdir -p "$WORKSPACE_ROOT/data/nechie"

# Initialize shopping list
cat > "$WORKSPACE_ROOT/data/nechie/shopping-list.json" << 'EOF'
{
  "items": [],
  "created_at": null,
  "last_updated": null
}
EOF
echo "✅ Created shopping list"

# Initialize reminders
cat > "$WORKSPACE_ROOT/data/nechie/reminders.json" << 'EOF'
{
  "reminders": [],
  "created_at": null,
  "last_updated": null
}
EOF
echo "✅ Created reminders tracker"

# Initialize state file
cat > "$STATE_FILE" << EOF
{
  "started_at": "$(date -Iseconds)",
  "onboarding_day": 0,
  "last_tip_sent": null,
  "welcome_sent": false,
  "tips_completed": 0,
  "total_interactions": 0,
  "features_used": {
    "calendar": false,
    "reminders": false,
    "email": false,
    "shopping": false,
    "family_coordination": false
  }
}
EOF
echo "✅ Created onboarding state"

# Create daily tips cron
echo ""
echo "📅 Setting up daily tips cron..."

DAILY_TIP_MESSAGE=$(cat << 'CRONMSG'
Check Nechie onboarding state (data/nechie-onboarding-state.json).
If onboarding_day < 14 and last_tip_sent != today:
1. Load tip for current day from config/integrations/nechie-onboarding.json
2. Send tip to Nechie via Telegram
3. Update last_tip_sent to today
4. Increment onboarding_day

If onboarding complete (day 14), reply HEARTBEAT_OK.
CRONMSG
)

# Create cron (will need to be run manually since we're in a script)
echo ""
echo "Run this command to create the daily tips cron:"
echo ""
echo "openclaw cron add \\"
echo "  --name 'nechie-daily-tips' \\"
echo "  --cron '0 8 * * 1-5' \\"
echo "  --message '$DAILY_TIP_MESSAGE' \\"
echo "  --model 'anthropic/claude-haiku-4-5' \\"
echo "  --announce \\"
echo "  --to 'telegram:NECHIE_TELEGRAM_ID'"
echo ""

# Summary
echo ""
echo "✅ HomeBot Onboarding Initialized!"
echo ""
echo "Next steps:"
echo "1. Get Nechie's Telegram ID (send her a test message)"
echo "2. Update NECHIE_TELEGRAM_ID in config/integrations/nechie-onboarding.json"
echo "3. Create the daily tips cron (command above)"
echo "4. Send welcome message to Nechie"
echo ""
echo "Welcome message:"
jq -r '.welcome_message.content' "$ONBOARDING_CONFIG"
echo ""
