#!/bin/bash
# setup-telegram-topics.sh
# Create Telegram supergroup with topics/forums for organized conversations

set -euo pipefail

echo "🚀 Telegram Topics Setup"
echo ""
echo "This will create a supergroup with organized topics."
echo ""
echo "Manual steps required (Telegram doesn't support creating supergroups via Bot API):"
echo ""
echo "1. Open Telegram on your phone or desktop"
echo "2. Create a new group: 'Oz Topics' or 'Meir + Oz'"
echo "3. Add @Ozy1234bot to the group"
echo "4. Go to group settings → Convert to Supergroup"
echo "5. Enable Topics/Forums:"
echo "   - Group Info → Edit → Topics (toggle on)"
echo ""
echo "6. Create these topics:"
echo "   📊 Financial"
echo "   🏗️ Infrastructure" 
echo "   💼 Business"
echo "   🕊️ Torah/Personal"
echo "   🤖 OpenClaw Meta"
echo "   📝 Inbox"
echo ""
echo "7. Get the group chat ID:"
echo "   - Forward a message from the group to @userinfobot"
echo "   - It will show the chat_id (negative number)"
echo ""
echo "8. Get each topic's message_thread_id:"
echo "   - Send a message in each topic"
echo "   - Forward to @userinfobot"
echo "   - Note the message_thread_id for each"
echo ""
echo "9. Update the config file:"
echo "   nano ~/.openclaw/workspace/config/integrations/telegram-topics.json"
echo ""
cat > ~/.openclaw/workspace/config/integrations/telegram-topics.json << 'JSON_EOF'
{
  "group_chat_id": null,
  "topics": {
    "financial": {
      "thread_id": null,
      "name": "📊 Financial",
      "description": "Portfolio, BTC, taxes, investments"
    },
    "infrastructure": {
      "thread_id": null,
      "name": "🏗️ Infrastructure",
      "description": "Servers, DNS, deployments, errors"
    },
    "business": {
      "thread_id": null,
      "name": "💼 Business",
      "description": "Disrupt Ventures, ZettaPOW, deals"
    },
    "torah": {
      "thread_id": null,
      "name": "🕊️ Torah/Personal",
      "description": "Jewish topics, family, spiritual"
    },
    "meta": {
      "thread_id": null,
      "name": "🤖 OpenClaw Meta",
      "description": "Discussing Oz, features, improvements"
    },
    "inbox": {
      "thread_id": null,
      "name": "📝 Inbox",
      "description": "Unsorted, default catch-all"
    }
  }
}
JSON_EOF

echo "✅ Created config template at: config/integrations/telegram-topics.json"
echo ""
echo "After completing the manual steps above, run:"
echo "  node scripts/telegram-topic-router.js 'test message'"
echo ""
echo "To test topic routing."
