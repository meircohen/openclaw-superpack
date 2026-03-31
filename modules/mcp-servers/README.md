# MCP Servers

Template configuration files for Model Context Protocol (MCP) servers supported by the OpenClaw superpack. Each JSON file contains a standalone MCP server configuration that can be merged into your Claude Code `settings.json` or `claude_desktop_config.json`.

## Available Servers

### context-mode

**File:** `context-mode.json`

Semantic code search powered by Context Mode. Indexes your codebase and provides fast, intelligent search across files, functions, and symbols. Useful for navigating large codebases and understanding code relationships.

- **Transport:** npx (Node.js)
- **Package:** `@context-mode/mcp-server`
- **Configuration:** No environment variables required. Run `ctx index` in your project root to build the initial index.

### context7

**File:** `context7.json`

Documentation lookup service. Fetches up-to-date documentation for libraries, frameworks, and APIs directly into your context window. Preferred over web search for library docs since it returns structured, relevant content.

- **Transport:** npx (Node.js)
- **Package:** `@context7/mcp-server`
- **Configuration:** No environment variables required.

### claude-peers

**File:** `claude-peers.json`

Multi-instance communication for Claude Code. Allows multiple Claude Code sessions running on the same machine to discover each other, exchange messages, and coordinate work. Essential for parallel development workflows.

- **Transport:** npx (Node.js)
- **Package:** `claude-peers`
- **Configuration:** No environment variables required. Peers are discovered automatically on the local machine.

### ai-mesh (Mesh MCP)

**File:** `mesh-mcp.json`

The OpenClaw mesh system's MCP interface. Provides access to multi-LLM routing, cost optimization, and health monitoring through the mesh layer. Routes requests to the optimal LLM provider based on task type, cost, and availability.

- **Transport:** Python
- **Script:** `$HOME/.openclaw/workspace/mesh/mcp_server.py`
- **Configuration:** Set `PYTHONPATH` to `$HOME/.openclaw/workspace`. The mesh system must be installed and configured separately.

### perplexity

**File:** `perplexity.json`

Web-grounded search, research, and reasoning via Perplexity AI. Provides tools for quick fact lookups, in-depth research, and complex reasoning with live web data and citations.

- **Transport:** npx (Node.js)
- **Package:** `@anthropic/perplexity-mcp`
- **Configuration:** Requires `PERPLEXITY_API_KEY`. Replace `{{PERPLEXITY_API_KEY}}` with your actual API key, or set it as an environment variable before launching.

## Usage

### Adding to Claude Code

Copy the server configuration from the relevant JSON file and merge it into your Claude Code settings:

```bash
# Settings location (macOS)
~/.claude/settings.json

# Or project-level
.claude/settings.json
```

Merge the `mcpServers` object from the template into your existing settings file's `mcpServers` section.

### Adding to Claude Desktop

Merge the configuration into your Claude Desktop config:

```bash
# macOS
~/Library/Application Support/Claude/claude_desktop_config.json

# Linux
~/.config/Claude/claude_desktop_config.json
```

### Environment Variables

For servers that require API keys (like Perplexity), you can either:

1. Replace the placeholder directly in the config file
2. Set the environment variable in your shell profile (`~/.zshrc`, `~/.bashrc`)
3. Use a `.env` file with a tool like `direnv`

## Adding New MCP Servers

To add a new server template:

1. Create a new JSON file named after the server (e.g., `my-server.json`)
2. Follow the standard MCP configuration format with a `mcpServers` root key
3. Use `{{PLACEHOLDER}}` syntax for any required secrets or API keys
4. Update this README with the server description and configuration details
