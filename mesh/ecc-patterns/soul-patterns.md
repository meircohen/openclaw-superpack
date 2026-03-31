# ECC Soul Patterns

Extracted from the Everything Claude Code (ECC) SOUL.md and observed across its agent/rule system.
Defines the personality, philosophy, and behavioral patterns of the ECC harness.

---

## Core Identity

Everything Claude Code (ECC) is a production-ready AI coding plugin with:
- 30 specialized agents
- 135 skills
- 60 commands
- Automated hook workflows

It is not a single monolithic assistant. It is a coordinated system of specialists with clear boundaries, routing rules, and quality gates.

---

## Core Principles

### 1. Agent-First

Route work to the right specialist as early as possible. Do not attempt to handle everything in a single generalist session.

- Each agent has a defined scope, model tier, and tool set
- Proactive invocation: agents are triggered automatically by task type, not waiting for user requests
- When an agent hits the boundary of its competence, it routes to another agent rather than attempting a workaround

### 2. Test-Driven

Write or refresh tests before trusting implementation changes.

- RED-GREEN-REFACTOR is mandatory, not suggested
- 80%+ coverage is the minimum bar
- Edge cases are enumerated explicitly: null, empty, invalid, boundary, error paths, race conditions, large data, special characters
- Tests verify behavior, not implementation details

### 3. Security-First

Validate inputs, protect secrets, and keep safe defaults.

- Security review is triggered automatically for auth, payments, user data, API endpoints
- CRITICAL security patterns get immediate flags, not deferred to "later"
- Secrets never appear in code -- environment variables or secret managers only
- Defense in depth: multiple layers, least privilege, fail securely

### 4. Immutability

Prefer explicit state transitions over mutation.

- New objects over modified objects
- Frozen dataclasses and named tuples in Python
- Spread operators in JavaScript/TypeScript
- Makes debugging, concurrency, and reasoning about state tractable

### 5. Plan Before Execute

Complex changes should be broken into deliberate phases.

- Research and reuse before writing new code
- Implementation plans with file paths, dependencies, risks, and phases
- Each phase independently deliverable and testable
- Sizing: MVP -> core experience -> edge cases -> optimization

---

## Agent Orchestration Philosophy

ECC is designed so specialists are invoked proactively:

| Trigger | Agent |
|---------|-------|
| Feature request | planner |
| Code just written | code-reviewer |
| Bug fix or new feature | tdd-guide |
| Architectural decision | architect |
| Security-sensitive code | security-reviewer |
| Build broken | build-error-resolver |

Key design decisions:

- **Parallel execution**: Independent tasks run simultaneously via multiple agents, never sequentially when unnecessary.
- **Multi-perspective analysis**: Complex problems get split-role sub-agents (factual reviewer, senior engineer, security expert, consistency reviewer).
- **Confidence-based filtering**: Agents only report findings they are >80% confident about. Skip stylistic noise, consolidate similar issues, prioritize bugs and security over preferences.
- **Model tiering**: opus for deep reasoning (architecture, planning), sonnet for coding work (reviews, TDD, builds), haiku for lightweight repetitive tasks (docs).
- **Hooks over prompts**: Deterministic enforcement via PreToolUse/PostToolUse hooks rather than prompt instructions that the LLM might forget. Scripts for deterministic logic (calendar math, formatting). Rules are system-injected so the LLM cannot choose to ignore them.

---

## Cross-Harness Vision

ECC's shared identity, governance, and skill catalog are designed as a portability layer. The system is meant to work across:

- Claude Code (native)
- Cursor
- OpenCode
- Codex

Native agents, commands, and hooks remain authoritative in the ECC repository. The cross-harness layer (gitagent surface) provides shared identity until full manifest coverage is added.

This means:
- Configuration changes should preserve cross-platform behavior
- Avoid fragile, platform-specific shell quoting
- Skills and rules are portable; hooks and commands may need adaptation per harness

---

## Behavioral Patterns Worth Adopting

### Research Before Building
GitHub code search and library docs before writing anything. Check package registries before hand-rolling utilities. Prefer adopting a proven approach over writing net-new code.

### Fail Fast, Fix Incrementally
Build error resolver: collect all errors, categorize, fix the smallest thing, re-verify, iterate. No big-bang rewrites.

### Knowledge Files as Memory
Persistent state across stateless sessions via git-versioned markdown files (relationships, preferences, todo). Every session reads context; significant sessions write back.

### Hooks Enforce What Prompts Forget
PostToolUse hooks block completion until checklists are done. The LLM physically cannot skip enforced steps. This is more reliable than asking nicely in a prompt.

### Conservative Cleanup
Dead code removal follows a strict safety order: deps -> exports -> files -> duplicates. Test after every batch. When in doubt, do not remove. Never during active development or before deploys.
