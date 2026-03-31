# Token Optimization Guide

Practical settings, habits, and strategies to reduce token consumption, extend session quality, and get more work done within daily limits.

> Adapted from Everything Claude Code (ECC) token-optimization docs with additional context.

---

## Recommended Settings

Add to your `~/.claude/settings.json`:

```json
{
  "model": "sonnet",
  "env": {
    "MAX_THINKING_TOKENS": "10000",
    "CLAUDE_AUTOCOMPACT_PCT_OVERRIDE": "50",
    "CLAUDE_CODE_SUBAGENT_MODEL": "haiku"
  }
}
```

### What Each Setting Does

| Setting | Default | Recommended | Effect |
|---------|---------|-------------|--------|
| `model` | opus | **sonnet** | Sonnet handles ~80% of coding tasks well. Switch to Opus with `/model opus` for complex reasoning. ~60% cost reduction. |
| `MAX_THINKING_TOKENS` | 31,999 | **10,000** | Extended thinking reserves up to 31,999 output tokens per request for internal reasoning. Reducing this cuts hidden cost by ~70%. Set to `0` to disable for trivial tasks. |
| `CLAUDE_AUTOCOMPACT_PCT_OVERRIDE` | 95 | **50** | Auto-compaction triggers when context reaches this % of capacity. Default 95% is too late -- quality degrades before that. Compacting at 50% keeps sessions healthier. |
| `CLAUDE_CODE_SUBAGENT_MODEL` | _(inherits main)_ | **haiku** | Subagents (Task tool) run on this model. Haiku is ~80% cheaper and sufficient for exploration, file reading, and test running. |

### Toggling Extended Thinking

- **Alt+T** (Windows/Linux) or **Option+T** (macOS) -- toggle on/off
- **Ctrl+O** -- see thinking output (verbose mode)

Power users can tune `MAX_THINKING_TOKENS` lower for simple tasks or higher for complex architectural work.

---

## Model Selection Table

Use the right model for the task. Default to Sonnet for 90% of coding tasks. Upgrade to Opus when first attempt failed, task spans 5+ files, architectural decisions, or security-critical code.

| Model | Best For | Cost | When to Switch |
|-------|----------|------|----------------|
| **Haiku** | Subagent exploration, file reading, simple lookups, writing docs | Lowest | Use as subagent default; also good for single-file edits with clear instructions |
| **Sonnet** | Day-to-day coding, reviews, test writing, implementation, PR reviews | Medium | Start here for all coding work |
| **Opus** | Complex architecture, multi-step reasoning, debugging subtle issues, security analysis | Highest | Upgrade when Sonnet fails, 5+ file changes, deep reasoning needed |

Switch models mid-session:

```
/model sonnet     # default for most work
/model opus       # complex reasoning
/model haiku      # quick lookups
```

---

## Context Management Commands

| Command | When to Use |
|---------|-------------|
| `/clear` | Between unrelated tasks. Stale context wastes tokens on every subsequent message. |
| `/compact` | At logical task breakpoints (after planning, after debugging, before switching focus). |
| `/cost` | Check token spending for the current session. |
| `/model <name>` | Switch model tier mid-session. |

---

## MCP Server Management

Each enabled MCP server adds tool definitions to your context window. Rule of thumb: **keep under 10 enabled per project, under 80 tools active**.

Tips:
- Run `/mcp` to see active servers and their context cost
- Prefer CLI tools when available (`gh` instead of GitHub MCP, `aws` instead of AWS MCP, `supabase` CLI instead of Supabase MCP)
- Use `disabledMcpServers` in project config to disable servers per-project
- The `memory` MCP server is configured by default but not used by any skill, agent, or hook -- consider disabling it
- With lazy loading, the context window issue is mostly solved, but token usage and cost is not -- the CLI + skills approach is still a token optimization method

### Replacing MCPs with CLI Commands

Instead of having the GitHub MCP loaded at all times, create a `/gh-pr` command that wraps `gh pr create` with your preferred options. Instead of the Supabase MCP eating context, create skills that use the Supabase CLI directly. Strip out the tools the MCP exposes that make things easy and turn those into commands.

---

## Strategic Compaction Guidelines

Disable auto-compact for fine-grained control. Manually compact at logical intervals or create a skill that does so for you.

### When to Compact

- After exploration, before implementation
- After completing a milestone
- After debugging, before continuing with new work
- Before a major context shift

### When NOT to Compact

- Mid-implementation of related changes
- While debugging an active issue
- During multi-file refactoring

### Subagents Protect Your Context

Use subagents (Task tool) for exploration instead of reading many files in your main session. The subagent reads 20 files but only returns a summary -- your main context stays clean.

---

## Agent Teams Cost Warning

Agent Teams (experimental) spawns multiple independent context windows. Each teammate consumes tokens separately.

- Only use for tasks where parallelism adds clear value (multi-module work, parallel reviews)
- For simple sequential tasks, subagents (Task tool) are more token-efficient
- Enable with: `CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS=1` in settings

---

## Modular Codebase Benefits

Having a more modular codebase with main files being in the hundreds of lines instead of thousands of lines helps both in token optimization costs and getting a task done right on the first try. Smaller files mean less context needed per edit, fewer tokens burned on exploration, and better first-attempt success rates.

---

## Tool-Specific Optimizations

- Replace grep with **mgrep** -- ~50% token reduction on average compared to traditional grep or ripgrep
- Use targeted file reads rather than broad exploration
- Prefer structured tool output (JSON) over verbose text when possible

---

## Dynamic System Prompt Injection

Instead of putting everything in CLAUDE.md (which loads every session), use CLI flags to inject context dynamically:

```bash
claude --system-prompt "$(cat memory.md)"
```

Practical aliases:

```bash
# Daily development
alias claude-dev='claude --system-prompt "$(cat ~/.claude/contexts/dev.md)"'

# PR review mode
alias claude-review='claude --system-prompt "$(cat ~/.claude/contexts/review.md)"'

# Research/exploration mode
alias claude-research='claude --system-prompt "$(cat ~/.claude/contexts/research.md)"'
```

System prompt content has higher authority than user messages, which have higher authority than tool results.

---

## Quick Reference

```bash
# Daily workflow
/model sonnet              # Start here
/model opus                # Only for complex reasoning
/clear                     # Between unrelated tasks
/compact                   # At logical breakpoints
/cost                      # Check spending

# Environment variables (add to ~/.claude/settings.json "env" block)
MAX_THINKING_TOKENS=10000
CLAUDE_AUTOCOMPACT_PCT_OVERRIDE=50
CLAUDE_CODE_SUBAGENT_MODEL=haiku
CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS=1

# Model selection rules of thumb
# - Haiku: exploration, docs, simple edits
# - Sonnet: 90% of coding, reviews, tests
# - Opus: architecture, security, debugging complex bugs, multi-file changes
# - Upgrade to Opus when Sonnet's first attempt fails

# Context management
# - Keep under 10 MCPs enabled / under 80 tools active
# - Compact at 50% context, not 95%
# - Use subagents for exploration to keep main context clean
# - Replace MCPs with CLI + skills where possible
```
