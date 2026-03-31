# OpenClaw Superpack -- Setup Wizard

Welcome! This file guides you through personalizing your OpenClaw Superpack installation. OpenClaw reads this file after install and walks you through each step interactively.

Each section is optional. Skip anything you don't need right now -- you can always come back.

---

## Step 1: Personal Identity

Set your basic identity so agents know who they're working for.

| Placeholder | Description | Example |
|-------------|-------------|---------|
| `{{USER_NAME}}` | Your name | Jane Smith |
| `{{USER_EMAIL}}` | Primary email | jane@example.com |
| `{{USER_LOCATION}}` | City/region | Austin, TX |
| `{{TIMEZONE}}` | IANA timezone | America/Chicago |

**Where to set:** `config/openclaw-template.json` > `user` section

---

## Step 2: Mesh System -- Connect Your AI Providers

The mesh routes tasks to the best AI provider based on cost, capability, and availability.

### Required (at least one)

| Provider | Config File | API Key Env Var |
|----------|-------------|-----------------|
| Claude Code | `mesh/config/claude-code.yaml` | Authenticated via `claude` CLI |
| Anthropic API | `mesh/config/anthropic-api.yaml` | `ANTHROPIC_API_KEY` |

### Optional Providers

| Provider | Config File | API Key Env Var |
|----------|-------------|-----------------|
| OpenAI / Codex | `mesh/config/codex.yaml` | `OPENAI_API_KEY` |
| Google Gemini | `mesh/config/gemini.yaml` | `GOOGLE_API_KEY` |
| Perplexity | `mesh/config/perplexity.yaml` | `PERPLEXITY_API_KEY` |
| xAI / Grok | `mesh/config/xai.yaml` | `XAI_API_KEY` |
| OpenRouter | `mesh/config/openrouter.yaml` | `OPENROUTER_API_KEY` |
| Ollama (local) | `mesh/config/ollama.yaml` | None (runs locally) |

**Setup:**
1. Open the YAML config for each provider you want
2. Set `enabled: true`
3. Export the API key in your shell profile: `export ANTHROPIC_API_KEY="sk-..."`
4. Verify: `python3 mesh/health.py`

### Cost Routing Preferences

| Setting | Where | Default |
|---------|-------|---------|
| Daily budget | `config/openclaw-template.json` > `mesh.cost_routing.daily_budget` | $10.00 |
| Prefer local models | `config/openclaw-template.json` > `mesh.cost_routing.prefer_local` | true |
| Fallback chain | `config/openclaw-template.json` > `mesh.cost_routing.fallback_chain` | claude-code, codex, gemini |

---

## Step 3: Intelligence Pipeline

The intelligence pipeline automatically collects, classifies, and acts on information from configured sources.

### Configure Sources

Edit `intelligence/config.yaml`:

```yaml
sources:
  hackernews:
    enabled: true          # Hacker News front page + Algolia search
  github_trending:
    enabled: true          # GitHub trending repos
    language: python       # Change to your preferred language
  arxiv:
    enabled: true          # arXiv CS papers
    categories: [cs.AI, cs.MA]
  rss:
    enabled: true
    feeds:
      - https://example.com/feed.xml    # Add your RSS feeds
  bluesky:
    enabled: false         # Requires AT Protocol auth
  reddit:
    enabled: false         # Requires Reddit API credentials
```

### Keyword Weights

Customize what the pipeline considers relevant by editing keyword weights in `intelligence/config.yaml`:

```yaml
keywords:
  high_priority:    # weight: 3
    - "your-project-name"
    - "your-tech-stack"
  medium_priority:  # weight: 2
    - "related-topic"
  low_priority:     # weight: 1
    - "general-interest"
```

### First Run

```bash
cd intelligence
bash init.sh           # Install deps + set up launchd schedule
python3 collector.py   # Manual first collection
python3 filter.py      # Classify collected items
python3 digest.py      # Generate first digest
```

---

## Step 4: Agents -- Choose Your Team

The superpack includes 55 pre-built agent templates. You don't need all of them.

### Recommended Starter Set

| Agent | Why |
|-------|-----|
| code-architect | System design decisions |
| backend-architect | API and backend systems |
| frontend-developer | UI implementation |
| qa-engineer | Testing and quality |
| devops-engineer | CI/CD and infrastructure |
| security-auditor | Security reviews |
| researcher | Deep research tasks |
| executive-assistant | Scheduling, communications |

### Activate an Agent

Agents are already in `~/.openclaw/agents/<name>/`. To customize:

1. Edit `SOUL.md` -- adjust personality and values
2. Edit `IDENTITY.md` -- adjust capabilities and boundaries
3. The agent becomes active when OpenClaw routes tasks to it

### Full Roster

See `AGENTS.md` in your workspace for the complete list with descriptions.

---

## Step 5: Integrations (Optional)

### Telegram Bot

| Placeholder | Description |
|-------------|-------------|
| `{{TELEGRAM_BOT_TOKEN}}` | From @BotFather on Telegram |

**Setup:**
1. Message @BotFather on Telegram, create a bot
2. Copy the token
3. Set in your config: `"telegram.bot_token": "your-token"`

### Twitter/X API

| Placeholder | Description |
|-------------|-------------|
| `{{TWITTER_API_KEY}}` | Twitter Developer API key |
| `{{TWITTER_API_SECRET}}` | Twitter Developer API secret |
| `{{TWITTER_ACCESS_TOKEN}}` | OAuth access token |
| `{{TWITTER_ACCESS_SECRET}}` | OAuth access secret |

**Setup:**
1. Apply at developer.twitter.com
2. Create an app, generate tokens
3. Set in config or use the template script at `scripts/templates/x-post-template.py`

### WHOOP Health Data

| Placeholder | Description |
|-------------|-------------|
| `{{WHOOP_CLIENT_ID}}` | WHOOP Developer client ID |
| `{{WHOOP_CLIENT_SECRET}}` | WHOOP Developer client secret |

**Setup:**
1. Register at developer.whoop.com
2. Create an app
3. Use the template at `scripts/templates/whoop-template.sh`

---

## Step 6: MCP Servers

MCP (Model Context Protocol) servers extend Claude Code with additional capabilities.

### Recommended Setup

Add to your Claude Code settings (`~/.claude/settings.json` or project `.claude/settings.json`):

```json
{
  "mcpServers": {
    "context-mode": {
      "command": "npx",
      "args": ["-y", "@context-mode/mcp-server"]
    },
    "context7": {
      "command": "npx",
      "args": ["-y", "@context7/mcp-server"]
    },
    "claude-peers": {
      "command": "npx",
      "args": ["-y", "claude-peers"]
    }
  }
}
```

See `mcp-servers/README.md` for details on each server.

---

## Step 7: Delegation Layer

The delegation system lets you hand off structured tasks to agents.

### Voice Guide

Edit `skills/delegation/voice/default.md` to match your communication style. This guide is used when agents write content on your behalf.

### Pipelines

Pre-built automation pipelines in `skills/delegation/pipelines/`:
- `morning-briefing.json` -- Daily digest of email, calendar, news
- `bug-to-pr.json` -- Bug report to pull request pipeline
- `email-to-todoist.json` -- Email triage to task management
- `meeting-prep-full.json` -- Meeting preparation workflow
- `trending-to-tweets.json` -- Trend monitoring to social content

Each pipeline can be enabled/disabled and customized.

---

## Step 8: Heartbeat System

The heartbeat runs periodic maintenance and health checks.

Edit `HEARTBEAT.md` in your workspace root to configure:
- Which memory blocks to refresh
- Provider health check intervals
- Digest generation schedule
- Notification preferences

---

## Placeholder Reference

All placeholders used across config files:

| Placeholder | Where Used | Description |
|-------------|-----------|-------------|
| `{{USER_NAME}}` | Config, agents, delegation | Your name |
| `{{USER_EMAIL}}` | Config, delegation templates | Your email |
| `{{USER_LOCATION}}` | Config, heartbeat | Your city/region |
| `{{TIMEZONE}}` | Config, heartbeat, intelligence | IANA timezone |
| `{{TELEGRAM_BOT_TOKEN}}` | Config | Telegram bot token |
| `{{TWITTER_API_KEY}}` | Config, scripts | Twitter API key |
| `{{TWITTER_API_SECRET}}` | Config, scripts | Twitter API secret |
| `{{TWITTER_ACCESS_TOKEN}}` | Config, scripts | Twitter OAuth token |
| `{{TWITTER_ACCESS_SECRET}}` | Config, scripts | Twitter OAuth secret |
| `{{WHOOP_CLIENT_ID}}` | Config, scripts | WHOOP client ID |
| `{{WHOOP_CLIENT_SECRET}}` | Config, scripts | WHOOP client secret |
| `{{PERPLEXITY_API_KEY}}` | MCP servers | Perplexity API key |
| `{{SHABBAT_ZIP}}` | Scripts | ZIP code for Shabbat times |

---

## Done!

You don't need to complete everything at once. The system works with whatever you've configured -- start with the mesh and a few agents, then expand as needed.

Run `python3 mesh/health.py` to verify your setup at any time.
