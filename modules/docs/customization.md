# Customization Guide

How to tailor the OpenClaw system to your specific workflow, preferences, and requirements.

## Personalizing Agents

### Adjusting Agent Personality

Edit an agent's `SOUL.md` to change its communication style:

```bash
vim ~/.openclaw/workspace/agents/<agent-name>/SOUL.md
```

Common personality adjustments:
- **Verbosity** -- Add "Be concise; prefer bullet points over paragraphs" or "Provide detailed explanations with examples"
- **Tone** -- Add "Use a direct, technical tone" or "Be encouraging and explain concepts step by step"
- **Focus areas** -- Add or remove expertise bullet points to shift the agent's emphasis

### Adjusting Agent Scope

Edit `IDENTITY.md` to change delegation and escalation:

```bash
vim ~/.openclaw/workspace/agents/<agent-name>/IDENTITY.md
```

You can:
- Change which agents it delegates to
- Modify the escalation path
- Move it to a different category

### Disabling Agents

To temporarily disable an agent without deleting it, rename its directory:

```bash
mv ~/.openclaw/workspace/agents/my-agent ~/.openclaw/workspace/agents/_disabled_my-agent
```

The system ignores directories prefixed with `_disabled_`.

## Adding Integrations

### Adding a New MCP Server

1. Create a configuration file in the MCP servers module:

```bash
vim ~/.openclaw/workspace/openclaw-superpack/modules/mcp-servers/my-server.json
```

2. Follow the standard format:

```json
{
  "mcpServers": {
    "my-server": {
      "command": "npx",
      "args": ["-y", "my-server-package"],
      "env": {
        "API_KEY": "{{MY_SERVER_API_KEY}}"
      }
    }
  }
}
```

3. Merge into your Claude Code settings:

```bash
vim ~/.claude/settings.json
```

### Connecting External Services

The intelligence pipeline can collect data from external sources. To add a new source:

1. Create a collector script in the intelligence module
2. Configure it to output in the standard digest format
3. Add it to the collection schedule in the heartbeat cron

### Adding Webhook Endpoints

For services that push data (rather than pull), you can set up webhook receivers that feed into the intelligence pipeline. This typically requires a lightweight HTTP server -- see the heartbeat module for examples.

## Custom Skills

Skills are reusable workflows that Claude Code can invoke. They live in the superpowers directory.

### Skill Structure

Each skill has a `SKILL.md` file that defines:
- When to trigger the skill
- Step-by-step instructions
- Expected inputs and outputs
- Verification criteria

### Creating a New Skill

1. Create the skill directory:

```bash
mkdir -p ~/.openclaw/workspace/superpowers/skills/my-skill
```

2. Write `SKILL.md`:

```markdown
# My Custom Skill

## Trigger
Use this skill when [describe the trigger condition].

## Steps
1. [First step]
2. [Second step]
3. [Third step]

## Verification
- [ ] [Check that the output meets criterion A]
- [ ] [Check that the output meets criterion B]
```

3. Reference it in your `CLAUDE.md` instructions so Claude Code knows to use it.

### Skill Examples

Common custom skills people create:
- **Pre-commit review** -- Automatically review staged changes before committing
- **Dependency audit** -- Check for outdated or vulnerable dependencies
- **Performance check** -- Run benchmarks and compare against baselines
- **Release notes** -- Generate release notes from commit history

## Cost Preferences

### Setting Budget Limits

Edit the mesh configuration to control spending:

```json
{
  "budget": {
    "daily_limit_usd": 10.00,
    "per_provider_limits": {
      "claude": 8.00,
      "gpt": 3.00,
      "gemini": 2.00
    },
    "per_request_ceiling_tokens": 16000
  }
}
```

### Cost Tier Strategy

Adjust how aggressively the mesh optimizes for cost vs. quality:

```json
{
  "routing": {
    "cost_weight": 0.25,
    "quality_weight": 0.40,
    "latency_weight": 0.15,
    "health_weight": 0.10,
    "history_weight": 0.10
  }
}
```

To favor cheaper providers, increase `cost_weight` and decrease `quality_weight`. To favor quality regardless of cost, do the reverse.

### Preferred Providers

Force specific providers for certain task types:

```json
{
  "routing": {
    "overrides": {
      "coding": "claude",
      "creative": "gpt",
      "factual": "gemini"
    }
  }
}
```

These overrides bypass the scoring system and always route the specified task type to the named provider (if healthy).

## Configuration Files Reference

| File | Location | Purpose |
|------|----------|---------|
| Claude Code settings | `~/.claude/settings.json` | MCP servers, permissions, hooks |
| Mesh config | `~/.openclaw/workspace/mesh/config.json` | Provider settings, routing weights, budgets |
| Agent definitions | `~/.openclaw/workspace/agents/*/` | SOUL.md and IDENTITY.md per agent |
| Skills | `~/.openclaw/workspace/superpowers/skills/*/` | SKILL.md per skill |
| Shared context | `~/.openclaw/workspace/shared/` | CONTEXT.md, DECISIONS.md, QUEUE.md |
| Heartbeat config | `~/.openclaw/workspace/heartbeat/` | Cron schedules, health check scripts |

## Tips

- **Start minimal** -- Enable only the MCP servers and agents you actually use. You can always add more later.
- **Version your customizations** -- Keep your agent and skill modifications in git so you can track changes and roll back if needed.
- **Review cost reports weekly** -- Check the mesh cost tracker to understand your spending patterns and adjust budgets accordingly.
- **Iterate on agent personalities** -- If an agent's output does not match your expectations, tweak its SOUL.md incrementally rather than rewriting it.
