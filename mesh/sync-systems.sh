#!/usr/bin/env bash
set -euo pipefail

# Sync configuration across Claude Code, Codex CLI, and Gemini CLI.
# Adapted from ECC sync-ecc-to-codex.sh for the OpenClaw mesh.
#
# What it does:
#   - Backs up existing configs before touching anything
#   - Copies shared rules/instructions to each system's config format
#   - Merges MCP server configs (add-only, never removes user servers)
#   - Generates system-specific agent guidance files
#
# Usage:
#   mesh/sync-systems.sh                  # Apply changes
#   mesh/sync-systems.sh --dry-run        # Preview without writing
#   mesh/sync-systems.sh --update-mcp     # Force-update MCP server entries

MODE="apply"
UPDATE_MCP=""
for arg in "$@"; do
  case "$arg" in
    --dry-run)    MODE="dry-run" ;;
    --update-mcp) UPDATE_MCP="yes" ;;
  esac
done

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
WORKSPACE="$(cd "$SCRIPT_DIR/.." && pwd)"
MESH_DIR="$SCRIPT_DIR"
SHARED_DIR="$WORKSPACE/shared"

# System config locations
CLAUDE_CODE_HOME="${CLAUDE_CODE_HOME:-$HOME/.claude}"
CODEX_HOME="${CODEX_HOME:-$HOME/.codex}"
GEMINI_HOME="${GEMINI_HOME:-$HOME/.gemini}"

STAMP="$(date +%Y%m%d-%H%M%S)"
BACKUP_DIR="$MESH_DIR/backups/sync-$STAMP"

log() { printf '[mesh-sync] %s\n' "$*"; }

run_or_echo() {
  if [[ "$MODE" == "dry-run" ]]; then
    printf '[dry-run]'
    printf ' %q' "$@"
    printf '\n'
  else
    "$@"
  fi
}

# ---------------------------------------------------------------------------
# 1. Backup existing configs
# ---------------------------------------------------------------------------
log "Mode: $MODE"
log "Creating backup at $BACKUP_DIR"
run_or_echo mkdir -p "$BACKUP_DIR"

for dir in "$CLAUDE_CODE_HOME" "$CODEX_HOME" "$GEMINI_HOME"; do
  if [[ -d "$dir" ]]; then
    dirname_base="$(basename "$dir")"
    run_or_echo mkdir -p "$BACKUP_DIR/$dirname_base"

    # Back up key config files
    for f in CLAUDE.md AGENTS.md settings.json config.toml .mcp.json; do
      if [[ -f "$dir/$f" ]]; then
        run_or_echo cp "$dir/$f" "$BACKUP_DIR/$dirname_base/$f"
      fi
    done
  fi
done

# ---------------------------------------------------------------------------
# 2. Build shared rules block from mesh context
# ---------------------------------------------------------------------------
MESH_RULES_MARKER_BEGIN="<!-- BEGIN MESH-SYNC -->"
MESH_RULES_MARKER_END="<!-- END MESH-SYNC -->"

build_shared_rules_block() {
  cat <<BLOCK
$MESH_RULES_MARKER_BEGIN
# Mesh Shared Context (auto-synced by mesh/sync-systems.sh)

## Active Systems
- Claude Code: Primary coding, debugging, architecture
- Codex CLI: Implementation, reasoning, background tasks
- Gemini CLI: Long context, multimodal, research

## Shared Rules
- TDD Iron Law: No production code without a failing test first
- Debugging Iron Law: No fixes without root cause investigation first
- Always read shared context before starting work
- Update CONTEXT.md after significant completions
- Create handoff files when work crosses system boundaries

## Shared Context Files
- $SHARED_DIR/CONTEXT.md — Living state document
- $SHARED_DIR/DECISIONS.md — Routing rules and architecture decisions
- $SHARED_DIR/CAPABILITIES.md — Per-system capabilities
- $SHARED_DIR/QUEUE.md — Prioritized work queue
- $SHARED_DIR/handoffs/ — Cross-system handoff documents

## MCP Servers Available
- github: GitHub operations (PRs, issues, repos)
- context7: Live documentation lookup
- exa: Neural web search for research
- memory: Persistent memory across sessions
- sequential-thinking: Chain-of-thought reasoning
- playwright: Browser automation and testing
- perplexity: Web-grounded search and research
$MESH_RULES_MARKER_END
BLOCK
}

inject_rules_block() {
  local target_file="$1"
  local tmp

  if [[ "$MODE" == "dry-run" ]]; then
    printf '[dry-run] inject rules block into %s\n' "$target_file"
    return
  fi

  if [[ ! -f "$target_file" ]]; then
    build_shared_rules_block > "$target_file"
    return
  fi

  # If markers exist, replace the block between them
  if grep -q "$MESH_RULES_MARKER_BEGIN" "$target_file" 2>/dev/null; then
    tmp="$(mktemp)"
    local block_tmp
    block_tmp="$(mktemp)"
    build_shared_rules_block > "$block_tmp"
    awk -v begin="$MESH_RULES_MARKER_BEGIN" -v end="$MESH_RULES_MARKER_END" -v block="$block_tmp" '
      $0 == begin { skip = 1; while ((getline line < block) > 0) print line; close(block); next }
      $0 == end   { skip = 0; next }
      !skip        { print }
    ' "$target_file" > "$tmp"
    cat "$tmp" > "$target_file"
    rm -f "$tmp" "$block_tmp"
  else
    # Append the block
    {
      printf '\n\n'
      build_shared_rules_block
    } >> "$target_file"
  fi
}

# ---------------------------------------------------------------------------
# 3. Sync to Claude Code (~/.claude/CLAUDE.md)
# ---------------------------------------------------------------------------
log "Syncing shared rules to Claude Code"

CLAUDE_MD="$CLAUDE_CODE_HOME/CLAUDE.md"
if [[ -d "$CLAUDE_CODE_HOME" ]]; then
  inject_rules_block "$CLAUDE_MD"
  log "  Updated $CLAUDE_MD"
else
  log "  Skipped: $CLAUDE_CODE_HOME does not exist"
fi

# ---------------------------------------------------------------------------
# 4. Sync to Codex CLI (~/.codex/AGENTS.md)
# ---------------------------------------------------------------------------
log "Syncing shared rules to Codex CLI"

CODEX_AGENTS="$CODEX_HOME/AGENTS.md"
if [[ -d "$CODEX_HOME" ]]; then
  inject_rules_block "$CODEX_AGENTS"

  # Generate Codex-specific guidance
  if [[ "$MODE" != "dry-run" ]]; then
    cat > "$CODEX_HOME/mesh-guidance.md" <<'GUIDANCE'
# Mesh Agent Guidance for Codex CLI

You are part of a multi-agent mesh. Your primary strengths:
- Implementation tasks following plans from Claude Code
- Reasoning-heavy tasks (o3/o4-mini models)
- Background processing with --full-auto

## Workflow
1. Check for handoff documents in ~/.openclaw/workspace/shared/handoffs/
2. If a handoff is addressed to you, read it and execute
3. When done, create a handoff back if follow-up is needed
4. Record your outcome: python3 ~/.openclaw/workspace/mesh/learn.py record --system codex ...

## Security (No Hooks Available)
Since Codex lacks hook support, enforce these manually:
- Never hardcode secrets — use environment variables
- Run security audit before committing
- Review git diff before every push
- Use sandbox_mode = "workspace-write" in config
GUIDANCE
    log "  Generated $CODEX_HOME/mesh-guidance.md"
  else
    printf '[dry-run] generate %s\n' "$CODEX_HOME/mesh-guidance.md"
  fi
else
  log "  Skipped: $CODEX_HOME does not exist"
fi

# ---------------------------------------------------------------------------
# 5. Sync to Gemini CLI (~/.gemini/settings.json or GEMINI.md)
# ---------------------------------------------------------------------------
log "Syncing shared rules to Gemini CLI"

GEMINI_MD="$GEMINI_HOME/GEMINI.md"
if [[ -d "$GEMINI_HOME" ]]; then
  inject_rules_block "$GEMINI_MD"

  # Generate Gemini-specific guidance
  if [[ "$MODE" != "dry-run" ]]; then
    cat > "$GEMINI_HOME/mesh-guidance.md" <<'GUIDANCE'
# Mesh Agent Guidance for Gemini CLI

You are part of a multi-agent mesh. Your primary strengths:
- Long context analysis (1M+ token windows)
- Multimodal tasks (images, video, audio)
- Research and synthesis tasks
- Large codebase analysis

## Workflow
1. Check for handoff documents in ~/.openclaw/workspace/shared/handoffs/
2. If a handoff is addressed to you, read it and execute
3. When done, create a handoff back if follow-up is needed
4. Record your outcome: python3 ~/.openclaw/workspace/mesh/learn.py record --system gemini ...

## Context Window
You have a much larger context window than other systems.
Use this for tasks that require reading many files at once.
GUIDANCE
    log "  Generated $GEMINI_HOME/mesh-guidance.md"
  else
    printf '[dry-run] generate %s\n' "$GEMINI_HOME/mesh-guidance.md"
  fi
else
  log "  Skipped: $GEMINI_HOME does not exist"
fi

# ---------------------------------------------------------------------------
# 6. Merge MCP server configs
# ---------------------------------------------------------------------------
log "Merging MCP server configurations"

# Canonical MCP servers for the mesh
MESH_MCP_SERVERS='{
  "github": {
    "command": "npx",
    "args": ["-y", "@modelcontextprotocol/server-github"]
  },
  "context7": {
    "command": "npx",
    "args": ["-y", "@upstash/context7-mcp@latest"]
  },
  "memory": {
    "command": "npx",
    "args": ["-y", "@modelcontextprotocol/server-memory"]
  },
  "sequential-thinking": {
    "command": "npx",
    "args": ["-y", "@modelcontextprotocol/server-sequential-thinking"]
  },
  "playwright": {
    "command": "npx",
    "args": ["-y", "@playwright/mcp", "--browser", "chrome"]
  }
}'

merge_mcp_to_claude_code() {
  local mcp_file="$WORKSPACE/.mcp.json"

  if [[ "$MODE" == "dry-run" ]]; then
    printf '[dry-run] merge MCP servers into %s\n' "$mcp_file"
    return
  fi

  if [[ ! -f "$mcp_file" ]]; then
    printf '{"mcpServers": %s}\n' "$MESH_MCP_SERVERS" > "$mcp_file"
    log "  Created $mcp_file with mesh MCP servers"
    return
  fi

  # Add-only merge: only add servers that don't already exist
  if command -v python3 >/dev/null 2>&1; then
    python3 -c "
import json, sys

with open('$mcp_file') as f:
    existing = json.load(f)

mesh = json.loads('''$MESH_MCP_SERVERS''')
servers = existing.get('mcpServers', {})
added = 0
update = '$UPDATE_MCP' == 'yes'

for name, config in mesh.items():
    if name not in servers or update:
        servers[name] = config
        added += 1

existing['mcpServers'] = servers
with open('$mcp_file', 'w') as f:
    json.dump(existing, f, indent=2)

print(f'  Merged: {added} servers added/updated in $mcp_file')
"
  else
    log "  WARNING: python3 not found, skipping MCP merge"
  fi
}

merge_mcp_to_codex() {
  local config_file="$CODEX_HOME/config.toml"

  if [[ "$MODE" == "dry-run" ]]; then
    printf '[dry-run] merge MCP servers into %s (TOML)\n' "$config_file"
    return
  fi

  if [[ ! -f "$config_file" ]]; then
    log "  Skipped: $config_file does not exist"
    return
  fi

  # For Codex, MCP servers are in config.toml under [mcp_servers.<name>]
  # We append missing sections only
  if command -v python3 >/dev/null 2>&1; then
    python3 -c "
import json

mesh = json.loads('''$MESH_MCP_SERVERS''')
config_path = '$config_file'

with open(config_path) as f:
    content = f.read()

added = 0
for name, config in mesh.items():
    section = f'[mcp_servers.{name}]'
    if section not in content:
        cmd = config.get('command', 'npx')
        args_list = config.get('args', [])
        args_str = ', '.join(f'\"{a}\"' for a in args_list)
        content += f'''

{section}
command = \"{cmd}\"
args = [{args_str}]
'''
        added += 1

with open(config_path, 'w') as f:
    f.write(content)

print(f'  Merged: {added} MCP servers appended to {config_path}')
"
  else
    log "  WARNING: python3 not found, skipping Codex MCP merge"
  fi
}

merge_mcp_to_claude_code
if [[ -d "$CODEX_HOME" ]]; then
  merge_mcp_to_codex
fi

# ---------------------------------------------------------------------------
# 7. Summary
# ---------------------------------------------------------------------------
log "Sync complete"
log "Backup saved at: $BACKUP_DIR"
log "Systems synced: Claude Code, Codex CLI, Gemini CLI"
if [[ "$MODE" == "apply" ]]; then
  log "Restart each CLI to reload updated configs."
fi
