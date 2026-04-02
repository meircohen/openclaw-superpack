#!/bin/bash
# validate-telegram-topics-config.sh
# Ensures critical Telegram Topics configuration remains intact

set -euo pipefail

CONFIG_FILE="$HOME/.openclaw/openclaw.json"
GROUP_ID="-1003846443358"
ERROR_LOG="$HOME/.openclaw/workspace/logs/config-validation-errors.log"

# Check if config file exists
if [[ ! -f "$CONFIG_FILE" ]]; then
    echo "❌ ERROR: openclaw.json not found at $CONFIG_FILE"
    exit 1
fi

# Validate group is in config
if ! jq -e ".channels.telegram.accounts.default.groups[\"$GROUP_ID\"]" "$CONFIG_FILE" > /dev/null 2>&1; then
    echo "❌ CRITICAL: Oz Topics group ($GROUP_ID) missing from config!"
    echo "$(date): Oz Topics group missing from config" >> "$ERROR_LOG"
    
    # Auto-fix
    echo "🔧 Auto-fixing: Adding group back to config..."
    jq ".channels.telegram.accounts.default.groups[\"$GROUP_ID\"] = {\"requireMention\": false}" "$CONFIG_FILE" > /tmp/openclaw-fixed.json
    mv /tmp/openclaw-fixed.json "$CONFIG_FILE"
    echo "✅ Fixed: Group re-added to config"
    echo "⚠️  Gateway restart required: openclaw gateway restart"
    exit 2
fi

# Validate requireMention is false
REQUIRE_MENTION=$(jq -r ".channels.telegram.accounts.default.groups[\"$GROUP_ID\"].requireMention" "$CONFIG_FILE")
if [[ "$REQUIRE_MENTION" != "false" ]]; then
    echo "❌ CRITICAL: requireMention is $REQUIRE_MENTION (should be false)!"
    echo "$(date): requireMention incorrectly set to $REQUIRE_MENTION" >> "$ERROR_LOG"
    
    # Auto-fix
    echo "🔧 Auto-fixing: Setting requireMention to false..."
    jq ".channels.telegram.accounts.default.groups[\"$GROUP_ID\"].requireMention = false" "$CONFIG_FILE" > /tmp/openclaw-fixed.json
    mv /tmp/openclaw-fixed.json "$CONFIG_FILE"
    echo "✅ Fixed: requireMention set to false"
    echo "⚠️  Gateway restart required: openclaw gateway restart"
    exit 2
fi

# Validate groupPolicy is open
GROUP_POLICY=$(jq -r ".channels.telegram.accounts.default.groupPolicy" "$CONFIG_FILE")
if [[ "$GROUP_POLICY" != "open" ]]; then
    echo "❌ CRITICAL: groupPolicy is $GROUP_POLICY (should be open)!"
    echo "$(date): groupPolicy incorrectly set to $GROUP_POLICY" >> "$ERROR_LOG"
    
    # Auto-fix
    echo "🔧 Auto-fixing: Setting groupPolicy to open..."
    jq ".channels.telegram.accounts.default.groupPolicy = \"open\"" "$CONFIG_FILE" > /tmp/openclaw-fixed.json
    mv /tmp/openclaw-fixed.json "$CONFIG_FILE"
    echo "✅ Fixed: groupPolicy set to open"
    echo "⚠️  Gateway restart required: openclaw gateway restart"
    exit 2
fi

echo "✅ Telegram Topics config valid"
exit 0
