# MCP Server Configurations

Catalogued from ECC's mcp-servers.json (full catalog) and .mcp.json (active baseline).
Use this as a reference when deciding which MCP servers to enable for a task.

## Active Baseline (Always Enabled)

These are the servers enabled in the ECC project-level .mcp.json. Keep under 10 to preserve context window.

### github
**What:** GitHub operations -- PRs, issues, repos, code search.
**When:** Any task involving GitHub repositories, pull requests, or issue management.
```json
{
  "command": "npx",
  "args": ["-y", "@modelcontextprotocol/server-github"]
}
```
**Notes:** Requires GITHUB_PERSONAL_ACCESS_TOKEN env var. Core server for any dev workflow.

### context7
**What:** Live documentation lookup for libraries and frameworks.
**When:** Need to check current API docs, resolve library usage questions, or use `/docs` command.
```json
{
  "command": "npx",
  "args": ["-y", "@upstash/context7-mcp@latest"]
}
```
**Notes:** Very useful for avoiding hallucinated API calls. Use resolve-library-id then query-docs.

### exa
**What:** Neural web search for research, code examples, and company info.
**When:** Broad research tasks, finding code examples, competitive analysis.
```json
{
  "type": "http",
  "url": "https://mcp.exa.ai/mcp"
}
```
**Notes:** HTTP-based (no local process). Prefer for broader research after exhausting GitHub search and primary docs.

### memory
**What:** Persistent key-value memory across sessions.
**When:** Need to remember context between sessions, store decisions, track state.
```json
{
  "command": "npx",
  "args": ["-y", "@modelcontextprotocol/server-memory"]
}
```
**Notes:** Good for cross-session continuity. Consider omega-memory (below) for richer features.

### playwright
**What:** Browser automation and testing via Playwright.
**When:** E2E testing, web scraping, UI verification, screenshot capture.
```json
{
  "command": "npx",
  "args": ["-y", "@playwright/mcp", "--browser", "chrome"]
}
```
**Notes:** The `--extension` flag enables enhanced mode for Claude Code integration.

### sequential-thinking
**What:** Chain-of-thought reasoning support.
**When:** Complex multi-step problems that benefit from structured reasoning.
```json
{
  "command": "npx",
  "args": ["-y", "@modelcontextprotocol/server-sequential-thinking"]
}
```
**Notes:** Useful for architecture decisions, debugging complex issues, planning.

---

## Extended Catalog (Enable As Needed)

These are available in the full ECC catalog. Enable only when a task needs them.

### firecrawl
**What:** Web scraping and crawling with structured output.
**When:** Need to scrape websites, extract structured data, or crawl documentation sites.
```json
{
  "command": "npx",
  "args": ["-y", "firecrawl-mcp"],
  "env": { "FIRECRAWL_API_KEY": "YOUR_KEY" }
}
```
**Notes:** Requires API key. Use for deep-research skill alongside exa.

### supabase
**What:** Supabase database operations (create tables, query, manage).
**When:** Working with Supabase-backed projects.
```json
{
  "command": "npx",
  "args": ["-y", "@supabase/mcp-server-supabase@latest", "--project-ref=YOUR_REF"]
}
```
**Notes:** Requires project-ref. Project-specific, not for general use.

### omega-memory
**What:** Advanced persistent memory with semantic search, multi-agent coordination, knowledge graphs.
**When:** Need richer memory than basic key-value -- semantic search, cross-agent sharing, graph queries.
```json
{
  "command": "uvx",
  "args": ["omega-memory", "serve"]
}
```
**Notes:** Runs via uvx (Python). 100% local. Richer than basic memory server. Good for mesh coordination.

### vercel
**What:** Vercel deployments and projects.
**When:** Managing Vercel deployments, checking build status.
```json
{
  "type": "http",
  "url": "https://mcp.vercel.com"
}
```
**Notes:** HTTP-based. Only needed for Vercel-hosted projects.

### railway
**What:** Railway deployment management.
**When:** Working with Railway-hosted services.
```json
{
  "command": "npx",
  "args": ["-y", "@railway/mcp-server"]
}
```

### cloudflare-docs
**What:** Cloudflare documentation search.
**When:** Building with Cloudflare Workers, Pages, D1, R2, etc.
```json
{
  "type": "http",
  "url": "https://docs.mcp.cloudflare.com/mcp"
}
```
**Notes:** HTTP-based. There are also separate servers for Workers builds, bindings, and observability.

### clickhouse
**What:** ClickHouse analytics queries.
**When:** Running analytics queries against ClickHouse databases.
```json
{
  "type": "http",
  "url": "https://mcp.clickhouse.cloud/mcp"
}
```

### magic
**What:** Magic UI component library.
**When:** Building UIs with Magic UI components.
```json
{
  "command": "npx",
  "args": ["-y", "@magicuidesign/mcp@latest"]
}
```

### filesystem
**What:** Filesystem operations via MCP.
**When:** Need structured filesystem access from an MCP-only client.
```json
{
  "command": "npx",
  "args": ["-y", "@modelcontextprotocol/server-filesystem", "/path/to/projects"]
}
```
**Notes:** Set the path arg to your projects directory. Not needed in Claude Code (has native fs access).

### insaits
**What:** AI-to-AI security monitoring -- anomaly detection, credential exposure, hallucination checks.
**When:** Security-sensitive tasks, production monitoring, OWASP MCP Top 10 coverage.
```json
{
  "command": "python3",
  "args": ["-m", "insa_its.mcp_server"]
}
```
**Notes:** 100% local. Install via `pip install insa-its`. 23 anomaly types.

### fal-ai
**What:** AI image/video/audio generation via fal.ai models.
**When:** Need to generate images, videos, or audio using AI models.
```json
{
  "command": "npx",
  "args": ["-y", "fal-ai-mcp-server"],
  "env": { "FAL_KEY": "YOUR_KEY" }
}
```

### browserbase
**What:** Cloud browser sessions via Browserbase.
**When:** Need remote browser sessions (avoiding local browser resource usage).
```json
{
  "command": "npx",
  "args": ["-y", "@browserbasehq/mcp-server-browserbase"],
  "env": { "BROWSERBASE_API_KEY": "YOUR_KEY" }
}
```

### browser-use
**What:** AI browser agent for web tasks.
**When:** Need autonomous web browsing/interaction.
```json
{
  "type": "http",
  "url": "https://api.browser-use.com/mcp",
  "headers": { "x-browser-use-api-key": "YOUR_KEY" }
}
```

### devfleet
**What:** Multi-agent orchestration -- dispatch parallel Claude Code agents in isolated worktrees.
**When:** Large parallel tasks, project planning with auto-chained missions.
```json
{
  "type": "http",
  "url": "http://localhost:18801/mcp"
}
```
**Notes:** Requires local devfleet server running. See https://github.com/LEC-AI/claude-devfleet

### token-optimizer
**What:** Token optimization via content deduplication and compression (95%+ reduction).
**When:** Hitting context limits, need to compress large inputs.
```json
{
  "command": "npx",
  "args": ["-y", "token-optimizer-mcp"]
}
```

### confluence
**What:** Confluence Cloud integration -- search pages, retrieve content, explore spaces.
**When:** Working with Confluence-hosted documentation.
```json
{
  "command": "npx",
  "args": ["-y", "confluence-mcp-server"],
  "env": {
    "CONFLUENCE_BASE_URL": "YOUR_URL",
    "CONFLUENCE_EMAIL": "YOUR_EMAIL",
    "CONFLUENCE_API_TOKEN": "YOUR_TOKEN"
  }
}
```

---

## Recommendations for Our Setup

### Must-Have (always enabled)
- **github** -- Core for all dev workflows
- **context7** -- Prevents hallucinated API calls
- **memory** -- Cross-session continuity for mesh coordination

### High Value (enable per-task)
- **playwright** -- E2E testing and web verification
- **exa** -- Research tasks
- **sequential-thinking** -- Architecture and complex debugging
- **perplexity** -- Web-grounded search (already configured via our mesh)

### Worth Exploring
- **omega-memory** -- Upgrade from basic memory for multi-agent coordination
- **devfleet** -- Could replace/augment our orchestrate.py for parallel dispatch
- **token-optimizer** -- Useful when hitting context limits on large codebases
- **insaits** -- Security monitoring for production-facing work

### Context Window Budget
Keep under 10 MCP servers enabled at once. Each server consumes context for tool definitions. The baseline 6 servers (github, context7, exa, memory, playwright, sequential-thinking) is a good default.
