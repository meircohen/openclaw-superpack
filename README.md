# OpenClaw Superpack

A full-stack AI orchestration system. Multi-model mesh, intelligence pipeline, agent delegation, and autonomous operations — installed with one command.

## Install

```bash
git clone https://github.com/openclaw/openclaw-superpack.git
cd openclaw-superpack
./install.sh
```

That's it. Everything gets installed into your OpenClaw workspace.

## What You Get

| Module | What It Does |
|--------|-------------|
| **Mesh** | Multi-AI orchestration — routes tasks across Claude, Codex, Gemini, Perplexity, and more |
| **Intelligence** | Collect → Filter → Act → Digest pipeline for automated information processing |
| **Agents** | Pre-configured agent roles and delegation framework |
| **Skills** | Reusable skill definitions for common operations |
| **Heartbeat** | Health monitoring across all connected systems |
| **MCP Servers** | Claude Code extensions for semantic search, docs, and peer coordination |
| **Config** | Template configs for all supported providers |

## Architecture

```
                    ┌─────────────────────────┐
                    │      You / Operator      │
                    └────────────┬────────────┘
                                 │
                    ┌────────────▼────────────┐
                    │    OpenClaw Gateway      │
                    │   (routing + dispatch)   │
                    └────────────┬────────────┘
                                 │
            ┌────────────────────┼────────────────────┐
            │                    │                     │
   ┌────────▼────────┐ ┌────────▼────────┐ ┌─────────▼────────┐
   │   Claude Code   │ │     Codex       │ │     Gemini       │
   │  (deep coding)  │ │  (fast tasks)   │ │  (research)      │
   └────────┬────────┘ └────────┬────────┘ └─────────┬────────┘
            │                    │                     │
            └────────────────────┼────────────────────┘
                                 │
                    ┌────────────▼────────────┐
                    │   Intelligence Pipeline  │
                    │  collect→filter→act→digest│
                    └────────────┬────────────┘
                                 │
            ┌────────────────────┼────────────────────┐
            │                    │                     │
   ┌────────▼────────┐ ┌────────▼────────┐ ┌─────────▼────────┐
   │    Telegram     │ │     Notion      │ │   Slack / Email   │
   │  (notifications)│ │  (knowledge)    │ │  (team comms)     │
   └─────────────────┘ └─────────────────┘ └──────────────────┘
```

## After Install

1. Restart your OpenClaw gateway
2. Run through `docs/setup-wizard.md` to connect integrations
3. `coast status` to verify

## Prerequisites

- [OpenClaw](https://github.com/openclaw/openclaw) installed
- Python 3.9+
- Node.js 18+
- Git
- Docker (optional, for some features)

## Structure

```
openclaw-superpack/
├── mesh/              # Multi-AI orchestration engine
│   ├── bootstrap/     # Per-system bootstrap prompts
│   ├── config/        # Provider configs (yaml)
│   ├── ecc-patterns/  # Engineering patterns library
│   ├── hooks/         # Event hooks (cost, quality, health)
│   └── tools/         # CLI tools
├── intelligence/      # Information pipeline
├── agents/            # Agent role definitions
├── delegation/        # Task delegation framework
├── skills/            # Reusable skill library
├── mcp-servers/       # MCP server configs
├── heartbeat/         # Health monitoring
├── config/            # Template configurations
├── templates/         # Document templates
├── scripts/           # Utility scripts
└── docs/              # Documentation + setup wizard
```

## License

MIT
