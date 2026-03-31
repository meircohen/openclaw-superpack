# Optimized CLAUDE.md — Adapted from ECC

## Source
Adapted from github.com/affaan-m/everything-claude-code CLAUDE.md

## Project Architecture Guidance

### Component Organization
- **agents/** - Specialized subagents for delegation (planner, reviewer, security, etc.)
- **skills/** - Workflow definitions and domain knowledge
- **commands/** - Slash commands invoked by users
- **hooks/** - Trigger-based automations (session persistence, pre/post-tool hooks)
- **rules/** - Always-follow guidelines (security, coding style, testing)

### Key Principles (from ECC)
1. Use existing solutions first — search GitHub, docs, web before building
2. Immutability is CRITICAL — use frozen dataclasses, NamedTuple, avoid mutation
3. Many small files (200-400 lines, 800 max) over monoliths
4. Test-driven development — write failing test first, always
5. Agent-first — route work to the right specialist early
6. Plan before execute — complex changes need deliberate phases

### Context Management
- Keep MCP servers under 10 per project
- Use subagents for exploration to protect main context
- Compact at logical breakpoints, not mid-task
- Set CLAUDE_AUTOCOMPACT_PCT_OVERRIDE=50 (default 95 is too late)
- Use CLI tools over MCP wrappers when available (gh over GitHub MCP)

### Dynamic System Prompt Injection
```bash
# Daily development
alias claude-dev='claude --system-prompt "$(cat ~/.claude/contexts/dev.md)"'
# PR review mode
alias claude-review='claude --system-prompt "$(cat ~/.claude/contexts/review.md)"'
# Research mode
alias claude-research='claude --system-prompt "$(cat ~/.claude/contexts/research.md)"'
```
System prompt > user messages > tool results in authority hierarchy.

### Model Selection Strategy
| Model | Best for | Cost |
|-------|----------|------|
| Haiku | Subagent exploration, file reading, simple lookups | Lowest |
| Sonnet | Day-to-day coding, reviews, test writing | Medium |
| Opus | Complex architecture, multi-step reasoning, debugging | Highest |

### Token Optimization Settings
```json
{
  "env": {
    "MAX_THINKING_TOKENS": "10000",
    "CLAUDE_AUTOCOMPACT_PCT_OVERRIDE": "50",
    "CLAUDE_CODE_SUBAGENT_MODEL": "haiku"
  }
}
```

### Development Workflow
1. Research/reuse: Search GitHub → docs → web before building
2. Plan: Use planner agent for complex features
3. TDD: Write failing test → implement → refactor
4. Review: Use code-reviewer agent
5. Commit: Conventional commits format
6. Pre-review checks before push

### Memory Persistence Pattern
- PreCompact Hook: Save state before compaction
- Stop Hook: Persist learnings on session end
- SessionStart Hook: Load previous context automatically
- Session files: Summary of what worked, what didn't, what's left

### Continuous Learning
When Claude discovers non-trivial patterns — debugging techniques, workarounds, project-specific knowledge — save as skill for automatic future loading.

### Hook System
- PreToolUse: Intercept before tool execution (block dangerous ops)
- PostToolUse: Run after tool execution (format, lint, notify)
- Stop: Run when session ends (persist learnings)
- PreCompact: Save state before context compaction

### Agent Routing
Use agents immediately without extra prompts:
- planner: Complex feature breakdown
- architect: System design decisions
- tdd-guide: Test-driven development
- code-reviewer: Code quality
- security-reviewer: Security audit
- build-error-resolver: Fix build errors
- performance-optimizer: Bottleneck analysis
