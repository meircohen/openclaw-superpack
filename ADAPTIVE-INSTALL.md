# Adaptive Install Specification

The superpack install.sh MUST detect the user's environment and adapt accordingly.
This file instructs the install script and setup wizard on how to handle different setups.

## Phase 1: Environment Detection

install.sh runs these checks BEFORE installing anything:

```bash
# OS Detection
OS=$(uname -s)  # Darwin (macOS), Linux, or Windows (WSL)
ARCH=$(uname -m)  # arm64, x86_64

# AI Provider Detection — check what's installed
HAS_CLAUDE=$(command -v claude >/dev/null 2>&1 && echo "yes" || echo "no")
HAS_CODEX=$(command -v codex >/dev/null 2>&1 && echo "yes" || echo "no")
HAS_GEMINI=$(command -v gemini >/dev/null 2>&1 && echo "yes" || echo "no")
HAS_OLLAMA=$(command -v ollama >/dev/null 2>&1 && echo "yes" || echo "no")
HAS_DOCKER=$(command -v docker >/dev/null 2>&1 && echo "yes" || echo "no")

# OpenClaw Detection
OPENCLAW_DIR=$(openclaw info --dir 2>/dev/null || echo "$HOME/.openclaw")
OPENCLAW_WORKSPACE=$(openclaw info --workspace 2>/dev/null || echo "$OPENCLAW_DIR/workspace")

# Package Manager Detection
HAS_BREW=$(command -v brew >/dev/null 2>&1 && echo "yes" || echo "no")
HAS_APT=$(command -v apt >/dev/null 2>&1 && echo "yes" || echo "no")
HAS_NPM=$(command -v npm >/dev/null 2>&1 && echo "yes" || echo "no")
HAS_BUN=$(command -v bun >/dev/null 2>&1 && echo "yes" || echo "no")
HAS_PIP=$(command -v pip3 >/dev/null 2>&1 && echo "yes" || echo "no")
```

## Phase 2: Adaptive Configuration

### Mesh System — Adapts to Available AI Providers

The mesh configs (mesh/config/*.yaml) are generated based on what's detected:

| User Has | Mesh Behavior |
|----------|---------------|
| Claude Code + Codex + Gemini | Full 5-system mesh (our setup) |
| Claude Code only | 2-system mesh (OpenClaw + Claude Code) |
| Codex only | 2-system mesh (OpenClaw + Codex) |
| Gemini only | 2-system mesh (OpenClaw + Gemini) |
| Only OpenClaw (no CLI agents) | Solo mode — OpenClaw does everything |
| Ollama available | Add as local inference option to any mesh config |

The routing decision tree adapts:
- If no Codex → reasoning tasks go to Claude Code or Gemini
- If no Claude Code → coding tasks go to Codex or Gemini
- If no Gemini → long context tasks go to whatever has the most context
- If only Ollama → everything routes locally (no API costs)

### Coasts — Adapts to Docker Availability

| Docker Status | Coasts Behavior |
|---------------|-----------------|
| Docker installed + running | Full Coasts install with Coastfile |
| Docker installed, not running | Install Coasts CLI, skip build, note in setup wizard |
| No Docker | Skip Coasts entirely, note it's optional |

### MCP Servers — Install What Works

| MCP Server | Requires | If Missing |
|------------|----------|------------|
| context-mode | Claude Code | Skip, note in wizard |
| context7 | Claude Code | Skip, note in wizard |
| claude-peers | Claude Code + bun | Skip, note in wizard |
| mesh-mcp | Python 3 + fastmcp | Always install (core functionality) |
| perplexity | API key | Install server, wizard asks for key |

### Platform-Specific Adjustments

| Platform | Adjustments |
|----------|-------------|
| macOS (arm64) | Default path. Homebrew for deps. launchd for daemons. |
| macOS (x86) | Same but different Homebrew path (/usr/local vs /opt/homebrew) |
| Linux (Ubuntu/Debian) | apt for deps. systemd for daemons. No Docker Desktop (use docker-ce). |
| Linux (other) | Best-effort. Flag missing deps. |
| Windows WSL | WSL-specific paths. No launchd. Docker Desktop via WSL backend. |

### Intelligence Pipeline — Adapts to Available Tools

| Feature | Requires | Fallback |
|---------|----------|----------|
| Local LLM filtering | Ollama | Use keyword-only filtering (no LLM classification) |
| Semantic dedup | Ollama embeddings | Use title-based dedup |
| Reddit collection | Network access | RSS fallback if blocked |
| Web research | Perplexity or web_search | Basic URL fetching |

## Phase 3: Setup Wizard Adaptation

After install, the setup wizard (read by OpenClaw) adapts its questions:

1. Greets user, shows what was detected
2. Only asks about integrations the user CAN set up:
   - Has Claude Code? → "Want to configure mesh routing for Claude Code?"
   - Has Ollama? → "Want to use local models for intelligence filtering?"
   - No WHOOP? → Don't even mention it, but infrastructure is there if they add it later
3. For missing tools, offers to help install:
   - "I noticed you don't have Codex. Want me to help you install it? It's free with OpenAI Pro."
   - "Docker isn't installed. Coasts (container isolation) needs it. Want to skip for now?"

## Phase 4: Living Updates

When user runs `git pull` on the superpack and re-runs install.sh:
- Re-detects environment (they may have added new tools)
- Only installs NEW files (doesn't overwrite user customizations)
- Shows changelog of what's new
- Backs up user's current configs before updating

## Key Principle

**The superpack should NEVER fail because the user's setup is different from ours.**
It should always install something useful, even if it's just OpenClaw + the intelligence pipeline + agent templates. The more tools they have, the more they get — but the minimum viable install works with just OpenClaw alone.
