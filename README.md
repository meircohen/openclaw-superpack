# OpenClaw Superpack

**One command to transform a fresh OpenClaw into a fully-powered AI agent system.** Multi-model mesh routing, intelligence pipeline, 55 specialized agents, task delegation, autonomous operations -- everything you need to run an AI-powered operation with zero employees.

## Install

```bash
git clone https://github.com/openclaw/openclaw-superpack.git
cd openclaw-superpack
./install.sh
```

The installer checks prerequisites, lets you pick which modules to install, copies everything into your OpenClaw workspace, and launches a setup wizard for personalization.

## What You Get

### Mesh System -- Multi-LLM Orchestration
Route tasks to the best AI provider automatically. Supports Claude, Codex, Gemini, Perplexity, Grok, OpenRouter, and local models via Ollama. Includes cost tracking, health monitoring, fallback chains, and a learning system that improves routing over time.

### Intelligence Pipeline -- Automated Signal Processing
Continuously collects from Hacker News, GitHub Trending, arXiv, RSS feeds, Reddit, Bluesky, npm, and PyPI. Two-pass LLM classification filters signal from noise. Autonomous action layer installs tools, pulls models, and generates threat briefs. Daily/weekly digests keep you informed.

### 55 AI Agents -- Your Digital Workforce
Pre-built agent templates spanning engineering (code-architect, backend, frontend, QA, DevOps, security), business (CEO, CFO, product-manager, strategist), creative (writer, content-creator, marketing), research (researcher, data-analyst, AI-expert), and personal (fitness-coach, chef, travel-planner). Each has a unique personality (SOUL.md) and clear role definition (IDENTITY.md).

### Delegation Layer -- Structured Task Handoff
Templates, voice guides, and verification checklists for delegating work to agents. Pre-built pipelines for morning briefings, bug-to-PR flows, email triage, meeting prep, and social content generation.

### Skills Library -- Reusable Capabilities
22 mesh skills (autonomous loops, deep research, security review, TDD workflow, prompt optimization, and more) plus research raid patterns for evaluating new tools and frameworks.

### Heartbeat System -- Always-On Operations
Automated runtime operations: memory refresh, provider health checks, briefing generation, digest delivery, and mesh monitoring.

### MCP Server Configs -- Extended Capabilities
Ready-to-use configurations for context-mode (semantic code search), context7 (documentation lookup), claude-peers (multi-instance coordination), mesh MCP (orchestration interface), and Perplexity (web search).

## Architecture

```
                      +--------------------------+
                      |     You (Operator)       |
                      +------------+-------------+
                                   |
                      +------------v-------------+
                      |    OpenClaw Gateway       |
                      |  (routing + dispatch)     |
                      +------------+-------------+
                                   |
            +----------------------+----------------------+
            |                      |                      |
   +--------v--------+   +--------v--------+   +---------v--------+
   |   Claude Code   |   |     Codex       |   |     Gemini       |
   |  (deep coding)  |   |  (fast tasks)   |   |  (research)      |
   +---------+-------+   +--------+--------+   +---------+--------+
            |                      |                      |
            +----------------------+----------------------+
                                   |
                      +------------v-------------+
                      |  Intelligence Pipeline    |
                      | collect>filter>act>digest  |
                      +------------+-------------+
                                   |
                      +------------v-------------+
                      |    55 Specialized Agents  |
                      |  (delegated task execution)|
                      +---------------------------+
```

## Module Breakdown

```
openclaw-superpack/
+-- install.sh                  # One-click installer
+-- setup-wizard.md             # Post-install personalization guide
+-- modules/
|   +-- mesh/                   # Multi-LLM routing engine
|   |   +-- router.py           #   Task classification + routing
|   |   +-- dispatch.py         #   Execution with fallback chains
|   |   +-- health.py           #   Provider health monitoring
|   |   +-- cost.py             #   Cost calculation + tracking
|   |   +-- learn.py            #   Routing weight optimization
|   |   +-- config/             #   Provider configs (YAML)
|   |   +-- hooks/              #   Event hooks (quality, cost, health)
|   |   +-- skills/             #   22 mesh skills
|   |   +-- ecc-patterns/       #   Engineering patterns library
|   |   +-- bootstrap/          #   Per-system bootstrap prompts
|   +-- intelligence/           # Signal processing pipeline
|   |   +-- collector.py        #   Multi-source collection
|   |   +-- filter.py           #   LLM classification
|   |   +-- act.py              #   Autonomous actions
|   |   +-- digest.py           #   Summary generation
|   |   +-- trends.py           #   Pattern tracking
|   +-- agents/                 # 55 agent templates
|   +-- delegation/             # Task delegation framework
|   |   +-- pipelines/          #   Automation workflows
|   |   +-- templates/          #   Task schemas
|   |   +-- voice/              #   Communication style guides
|   |   +-- verify/             #   Output verification
|   +-- heartbeat/              # Runtime operations
|   +-- skills/                 # Skills library + raid patterns
|   +-- mcp-servers/            # MCP server configurations
|   +-- scripts/                # Utility scripts + templates
|   +-- docs/                   # Architecture docs + guides
+-- config/                     # Template configuration files
+-- templates/                  # Document + memory block templates
```

## Prerequisites

- **OpenClaw** installed and running
- **Python 3.9+** (for mesh and intelligence pipeline)
- **Node.js 18+** (for MCP servers)
- **Git**

## After Install

1. **Restart** your OpenClaw gateway
2. OpenClaw reads `setup-wizard.md` and walks you through personalization
3. Connect at least one AI provider (Claude recommended)
4. Run `python3 mesh/health.py` to verify
5. Customize agents by editing their SOUL.md and IDENTITY.md files

## Customization

Everything is designed to be personalized:

- **Agents** -- Edit SOUL.md for personality, IDENTITY.md for capabilities
- **Intelligence** -- Configure sources and keywords in `config.yaml`
- **Mesh** -- Set cost budgets, provider priorities, fallback chains
- **Delegation** -- Write your own voice guide, customize pipeline triggers
- **Skills** -- Add custom skills following the SKILL.md template pattern

See `modules/docs/customization.md` for the full guide.

## Contributing

1. Fork the repo
2. Create a feature branch
3. Make your changes
4. Run the sanitization check: `grep -r "personal-data-pattern" .`
5. Submit a PR

**Important:** Never commit personal data, API keys, or credentials. Use `{{PLACEHOLDER}}` format for any user-specific values.

## License

MIT License. See [LICENSE](LICENSE) for details.

---

Built with OpenClaw. Run your entire operation with AI agents and zero employees.
