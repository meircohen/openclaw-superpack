# Scripts Module

Utility scripts for orchestrating a multi-agent AI mesh. These scripts handle agent discovery, cross-system handoffs, task dispatch, configuration sync, and integrations.

## Core Scripts

### discover-agents.sh
Scans all registered agents from your `openclaw.json` config and displays their specialties by reading SOUL.md and IDENTITY.md files. Used by the orchestrator's heartbeat to maintain an up-to-date roster of available agents.

```bash
bash scripts/discover-agents.sh
```

### handoff.sh
Create, pick up, complete, and monitor handoffs between agents and systems. Handoffs are JSON files in `shared/handoffs/` that track work as it moves between systems.

```bash
bash scripts/handoff.sh create openclaw claude-code "Implement feature X" high
bash scripts/handoff.sh pickup 2026-03-30-implement-feature-x.json
bash scripts/handoff.sh complete 2026-03-30-implement-feature-x.json "Done, PR #42"
bash scripts/handoff.sh list pending
bash scripts/handoff.sh stale      # Flag handoffs pending >48 hours
```

### dispatch.sh
Auto-dispatches pending handoffs to Claude Code or Codex CLI. Features context injection, result verification, and fallback routing (if one system fails, retries on the other).

```bash
bash scripts/dispatch.sh check                           # Auto-dispatch + verify
bash scripts/dispatch.sh run claude-code "Fix the bug"   # Direct dispatch
bash scripts/dispatch.sh status                          # Show running dispatches
bash scripts/dispatch.sh verify                          # Check completed runs
```

### generate-briefing.sh
Generates `shared/BRIEFING.md`, the single-file context document that agents read at session start. Aggregates current work, priorities, handoffs, escalations, and queue status.

```bash
bash scripts/generate-briefing.sh
```

## Mesh Scripts

### sync-systems.sh
Syncs shared rules and MCP server configurations across Claude Code, Codex CLI, and Gemini CLI. Backs up existing configs before modifying anything. Supports dry-run mode.

```bash
bash mesh/sync-systems.sh              # Apply changes
bash mesh/sync-systems.sh --dry-run    # Preview without writing
bash mesh/sync-systems.sh --update-mcp # Force-update MCP servers
```

### inject-bootstrap.sh
Injects mesh awareness rules into each system's config files so they know about the multi-agent mesh on startup. Uses markers to allow clean injection and removal.

```bash
bash mesh/inject-bootstrap.sh              # Inject all
bash mesh/inject-bootstrap.sh --dry-run    # Preview
bash mesh/inject-bootstrap.sh --remove     # Remove injected rules
```

### install-aliases.sh
Installs the `mesh` shell function into `~/.zshrc` for quick access to mesh commands (route, dispatch, cost, health, stats, queue, etc.).

```bash
bash mesh/install-aliases.sh           # Install
bash mesh/install-aliases.sh --remove  # Remove
```

## Integration Templates

Templates for optional integrations. Each requires API keys or OAuth setup.

### templates/x-post-template.py
Post to X/Twitter via the official API (OAuth 1.0a, free tier: 500 posts/month). Supports single tweets, replies, and threads.

**Setup:** Create `~/.config/x-cli/.env` with your X API credentials.

### templates/whoop-template.sh
Pull health data (recovery, sleep, strain) from the WHOOP API. Requires OAuth tokens.

**Setup:** Complete WHOOP OAuth flow and save tokens to `~/.openclaw/.whoop-tokens.json`.

### templates/shabbat-times-template.sh
Check Shabbat/Yom Tov times using the free Hebcal API. The heartbeat uses this to suppress non-emergency notifications during Shabbat.

**Setup:** Set your ZIP code via the `SHABBAT_ZIP` environment variable or edit the script directly.

## Environment Variables

| Variable | Default | Description |
|----------|---------|-------------|
| `OPENCLAW_WORKSPACE` | `$HOME/.openclaw/workspace` | Workspace root path |
| `DISPATCH_TIMEOUT` | `120` | Seconds before dispatch fallback |
| `CLAUDE_CODE_HOME` | `$HOME/.claude` | Claude Code config directory |
| `CODEX_HOME` | `$HOME/.codex` | Codex CLI config directory |
| `GEMINI_HOME` | `$HOME/.gemini` | Gemini CLI config directory |
| `SHABBAT_ZIP` | `10001` | ZIP code for Shabbat times |
| `SHABBAT_CANDLE_MINUTES` | `18` | Minutes before sunset for candle lighting |
| `SHABBAT_UTC_OFFSET` | `-5` | UTC offset for Shabbat check |

## Dependencies

- `jq` -- JSON processing (required by handoff.sh, dispatch.sh)
- `python3` -- Used by discover-agents.sh, sync-systems.sh, and templates
- `curl` -- HTTP requests (Shabbat times, WHOOP API)
- `tweepy` -- Python library for X/Twitter API (only for x-post template)
- `claude` CLI -- Required by dispatch.sh for Claude Code dispatches
- `codex` CLI -- Required by dispatch.sh for Codex dispatches
