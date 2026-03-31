# Getting Started

A quick start guide for installing and configuring the OpenClaw superpack.

## Prerequisites

- **macOS or Linux** (macOS recommended; Linux supported)
- **Node.js 18+** and npm
- **Python 3.10+** with pip
- **Claude Code CLI** installed and authenticated
- **Git** for version control
- **zsh or bash** shell

Optional but recommended:
- A Perplexity API key (for web search capabilities)
- Google Drive CLI tools (for backup sync)

## Installation

### 1. Clone the superpack

```bash
git clone <repo-url> ~/.openclaw/workspace/openclaw-superpack
cd ~/.openclaw/workspace/openclaw-superpack
```

### 2. Run the installer

The adaptive installer detects your environment and installs the appropriate components:

```bash
bash install.sh
```

The installer will:
- Create the `~/.openclaw/workspace/` directory structure
- Install required Python and Node.js dependencies
- Set up MCP server configurations
- Configure the heartbeat system
- Initialize the intelligence pipeline
- Deploy agent definitions

### 3. Configure API keys

Set any required API keys in your shell profile:

```bash
# Add to ~/.zshrc or ~/.bashrc
export PERPLEXITY_API_KEY="your-key-here"
```

Reload your shell:

```bash
source ~/.zshrc
```

### 4. Configure MCP servers

Merge the desired MCP server configs from `modules/mcp-servers/` into your Claude Code settings:

```bash
# Edit your Claude Code settings
vim ~/.claude/settings.json
```

See `modules/mcp-servers/README.md` for details on each server.

## First Steps After Install

### Verify the mesh

Check that the mesh system is operational:

```bash
python3 ~/.openclaw/workspace/mesh/health_check.py
```

You should see status output for each configured LLM provider.

### Index your codebase

If you installed the context-mode MCP server, build an initial index:

```bash
cd /path/to/your/project
npx @context-mode/mcp-server index
```

### Review the agent roster

Browse the available agents:

```bash
ls ~/.openclaw/workspace/agents/
```

Each agent directory contains a `SOUL.md` describing its purpose and an `IDENTITY.md` with its role parameters.

### Check the work queue

See if there are any pending items:

```bash
cat ~/.openclaw/workspace/shared/QUEUE.md
```

### Run a health check

Execute a full system health check:

```bash
bash ~/.openclaw/workspace/heartbeat/health_check.sh
```

## Verifying Everything Works

Run through this checklist to confirm the installation is complete:

1. **Claude Code launches** -- Run `claude` in your terminal and confirm it starts
2. **MCP servers connect** -- In a Claude Code session, check that configured MCP tools appear in the tool list
3. **Mesh responds** -- Run the mesh health check script and confirm providers are reachable
4. **Agents are available** -- Confirm agent directories exist under `~/.openclaw/workspace/agents/`
5. **Heartbeat runs** -- Check that the cron job is installed: `crontab -l | grep openclaw`
6. **Backups are configured** -- Verify the nightly backup cron entry exists
7. **Intelligence pipeline** -- Check for recent digest files in `~/.openclaw/workspace/shared/digest/`

## Troubleshooting

### MCP server fails to start

- Ensure Node.js 18+ is installed: `node --version`
- Try running the npx command manually to see error output
- Check that your network allows npm package downloads

### Mesh health check fails

- Verify API keys are set for configured providers
- Check network connectivity to provider endpoints
- Review `~/.openclaw/workspace/mesh/config.json` for correct settings

### Cron jobs not running

- Verify crontab entries: `crontab -l`
- Check system logs for cron execution errors
- Ensure scripts have execute permissions: `chmod +x ~/.openclaw/workspace/heartbeat/*.sh`

## Next Steps

- Read [architecture.md](architecture.md) for a system overview
- Read [mesh-guide.md](mesh-guide.md) to understand LLM routing
- Read [agent-guide.md](agent-guide.md) to work with specialized agents
- Read [customization.md](customization.md) to tailor the system to your workflow
