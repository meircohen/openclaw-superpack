# OpenClaw Superpack — Setup Wizard

Welcome! The superpack is installed. Now let's connect your integrations.
Each one is optional — skip what you don't need, come back later for the rest.

---

## 1. API Keys (Required for mesh routing)

Set these in your environment (e.g., `~/.zshrc` or `~/.bashrc`):

```bash
# At minimum, set one provider
export ANTHROPIC_API_KEY="sk-ant-..."

# Optional — enables multi-provider routing
export OPENAI_API_KEY="sk-..."
export PERPLEXITY_API_KEY="pplx-..."
export XAI_API_KEY="xai-..."
export GOOGLE_AI_API_KEY="..."
```

Then reload: `source ~/.zshrc`

---

## 2. Telegram Bot (Notifications & Commands)

1. Message [@BotFather](https://t.me/BotFather) on Telegram
2. Create a new bot: `/newbot`
3. Copy the token and set it:
   ```bash
   export TELEGRAM_BOT_TOKEN="123456:ABC-..."
   ```
4. Start a chat with your bot and send `/start`
5. Configure access: run `/telegram:configure` in Claude Code

---

## 3. WHOOP Integration (Health Data)

1. Go to [developer.whoop.com](https://developer.whoop.com)
2. Create an app, get your client ID and secret
3. Set environment variables:
   ```bash
   export WHOOP_CLIENT_ID="..."
   export WHOOP_CLIENT_SECRET="..."
   ```
4. The intelligence pipeline will auto-collect sleep/recovery data

---

## 4. Twitter/X Integration (Content & Intelligence)

1. Apply for a Twitter Developer account at [developer.twitter.com](https://developer.twitter.com)
2. Create an app and generate keys:
   ```bash
   export TWITTER_API_KEY="..."
   export TWITTER_API_SECRET="..."
   export TWITTER_ACCESS_TOKEN="..."
   export TWITTER_ACCESS_SECRET="..."
   ```
3. The intelligence collector will monitor your configured feeds

---

## 5. Perplexity (Research & Web Search)

1. Get an API key from [perplexity.ai](https://perplexity.ai)
2. Set it:
   ```bash
   export PERPLEXITY_API_KEY="pplx-..."
   ```
3. The mesh router will use Perplexity for research-class queries

---

## 6. Google Calendar (Scheduling)

1. Enable the Google Calendar API in your GCP console
2. Download `credentials.json` to `~/.openclaw/config/google-credentials.json`
3. Run the auth flow: `python3 ~/.openclaw/workspace/scripts/gcal-auth.py`
4. Calendar events will feed into the intelligence pipeline

---

## 7. Notion (Knowledge Base)

1. Create an internal integration at [notion.so/my-integrations](https://www.notion.so/my-integrations)
2. Set the token:
   ```bash
   export NOTION_API_KEY="ntn_..."
   ```
3. Share relevant databases with your integration
4. The intelligence pipeline can read/write to Notion

---

## 8. Gmail (Email Intelligence)

1. Enable the Gmail API in your GCP console
2. Use the same `credentials.json` from the Calendar setup
3. Run: `python3 ~/.openclaw/workspace/scripts/gmail-auth.py`
4. The collector can surface important emails

---

## 9. Slack (Team Communication)

1. Create a Slack app at [api.slack.com/apps](https://api.slack.com/apps)
2. Install to your workspace, get the bot token:
   ```bash
   export SLACK_BOT_TOKEN="xoxb-..."
   ```
3. The mesh can send notifications and receive commands via Slack

---

## 10. MCP Servers (Claude Code Extensions)

The installer listed MCP servers to register. If you haven't yet:

```bash
claude mcp add context-mode
claude mcp add context7
claude mcp add claude-peers
```

Verify: `claude mcp list`

---

## 11. Mesh Config

Edit `~/.openclaw/workspace/mesh/config/openclaw.yaml` to:
- Set your default provider
- Configure fallback chains
- Adjust routing rules

---

## Verification

After connecting integrations, verify everything:

```bash
# Check mesh health
python3 ~/.openclaw/workspace/mesh/health.py

# Test intelligence pipeline
python3 ~/.openclaw/workspace/intelligence/collector.py --dry-run

# Check coast status
coast status
```

---

You're set! The infrastructure adapts to what you connect.
Skip anything, come back later — the system degrades gracefully.
