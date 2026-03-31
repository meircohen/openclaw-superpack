# Repo Raid: awesome-claude-code-toolkit
- **URL**: https://github.com/rohitg00/awesome-claude-code-toolkit
- **Stars**: 972
- **Language**: JavaScript
- **Last updated**: 2026-03-31
- **License**: Apache-2.0

## Architecture Overview

The most comprehensive single-repo catalogue of Claude Code extensions. Contains 850+ files organized into 10 top-level directories: plugins (176+), agents (135 across 10 categories), skills (35 curated + 28 community), commands (42 slash commands in 8 categories), hooks (20 scripts covering all 8 lifecycle events), rules (15 coding standards), templates (7 CLAUDE.md templates), MCP configs (13 server profiles), contexts (5 behavioral modes), and examples (3 walkthroughs).

The repo serves as both a curated directory (linking to external repos with star counts) and a self-contained toolkit (most agents, skills, commands, hooks, and rules are fully defined inline). It can be installed as a Claude Code plugin, cloned manually, or bootstrapped via a one-liner install script.

---

## Key Patterns Found

### Pattern 1: Lifecycle Hook Architecture (20 hooks across 8 event types)

The repo defines a complete `hooks.json` with scripts for every Claude Code lifecycle event:

| Event Type | Scripts | Purpose |
|---|---|---|
| **SessionStart** | `session-start.js`, `context-loader.js` | Load project context, detect package manager, inject git state and pending todos |
| **SessionEnd** | `session-end.js`, `learning-log.js` | Persist session state, extract and save learnings to daily log |
| **PreToolUse (Bash)** | `smart-approve.py`, `block-dev-server.js`, `pre-push-check.js`, `commit-guard.js` | Decompose compound bash commands and check each against allow/deny patterns; block dev servers outside tmux; verify branch before push; validate conventional commits |
| **PreToolUse (Write/Edit)** | `block-md-creation.js`, `secret-scanner.js` | Block unnecessary .md creation; scan for leaked secrets (AWS keys, GitHub tokens, private keys, JWTs, DB URLs, Slack tokens, generic API keys) |
| **PostToolUse (Write/Edit)** | `post-edit-check.js`, `lint-fix.js`, `type-check.js`, `auto-test.js` | Run linter, auto-fix lint issues, TypeScript type checking, run related tests after edits |
| **PostToolUse (Bash)** | `bundle-check.js`, `suggest-compact.js` | Check bundle size after builds; track edit count and suggest compaction |
| **PreCompact** | `pre-compact.js` | Save important context before compaction |
| **Stop** | `stop-check.js` | Remind to run tests if code was modified |
| **Notification** | `notification-log.js` | Log notifications for later review |
| **UserPromptSubmit** | `prompt-check.js` | Detect vague prompts and suggest clarification |

**Key insight**: The `smart-approve.py` hook is particularly sophisticated -- it recursively decomposes compound bash commands (`&&`, `||`, `;`, `|`, `$()`, newlines), strips heredoc bodies, handles quoting/escaping, normalizes away env vars and redirections, and checks each sub-command against merged permission patterns from global + project + project-local settings. This is a production-grade security gate.

### Pattern 2: Context Modes (Behavioral Switching)

Five context files that configure Claude Code's persona for different tasks:

- **dev.md** - "Write working code first, optimize later." Speed-oriented, test alongside implementation, feature branches, avoid unrelated refactoring.
- **review.md** - Check logic, security, edge cases. Quality lens.
- **research.md** - Evaluate tools, compare alternatives, document findings.
- **debug.md** - Reproduce, hypothesize, fix root cause, regression test.
- **deploy.md** - Pre-deploy checklist, staging-first, rollback criteria.

Usage pattern: `/context load dev` before starting work. This is essentially a behavioral prompt injection that shifts Claude's priorities.

### Pattern 3: Multi-Agent Pipeline Orchestration

The repo defines 135 agents across 10 categories with a structured coordination model:

**Agent Categories**: Core Development (13), Language Experts (25), Infrastructure (11), QA (10), Data/AI (16), Developer Experience (15), Specialized Domains (15), Business/Product (12), Orchestration (8), Research/Analysis (11).

**Orchestration agents** are the most relevant pattern:
- **Task Coordinator** - Decomposes requests into atomic tasks, builds DAG of dependencies, assigns agents by domain, maximizes parallelism, aggregates results.
- **Context Manager** - Context compression, session summaries.
- **Workflow Director** - Multi-agent pipeline orchestration.
- **Multi-Agent Coordinator** - Parallel agent execution, merge outputs.
- **Error Coordinator** - Handle errors across multi-agent workflows.

**Pipeline pattern** from examples:
```
[Planner Agent] --> [Developer Agent] --> [Reviewer Agent] --> [Deploy Agent]
```
Each agent runs with a specific context mode. The reviewer is always a different agent than the developer.

### Pattern 4: CLAUDE.md Template Hierarchy

Seven templates ranging from minimal to enterprise:

1. **Minimal** - Scripts, quick prototypes
2. **Standard** - Most projects. Includes: Stack, Commands, Project Structure, Conventions, Environment Variables, Key Decisions
3. **Comprehensive** - Large codebases with detailed conventions
4. **Monorepo** - Turborepo/Nx with multiple packages
5. **Enterprise** - Large teams with compliance and SSO
6. **Python Project** - FastAPI/Django specific
7. **Fullstack App** - Next.js + API

The Standard template is a good reference: 54 lines covering stack declaration, all dev commands, project structure tree, coding conventions (conventional commits, feature branches, server-first components, Zod validation, no `any`, 80% coverage), env vars, and key architectural decisions.

### Pattern 5: MCP Server Profiles (13 curated configs)

Pre-built `.json` files for different development contexts:

| Profile | Key Servers |
|---|---|
| **Recommended** (14 servers) | filesystem, github, postgres, redis, docker, memory, fetch, brave-search, sqlite, puppeteer, slack, linear, sentry, firecrawl |
| **Fullstack** | Filesystem, GitHub, Postgres, Redis, Puppeteer |
| **Kubernetes** | kubectl-mcp-server, Docker, GitHub |
| **Data Science** | Jupyter, SQLite, PostgreSQL, Filesystem |
| **DevOps** | AWS, Docker, GitHub, Terraform, Sentry |
| **Research** | BGPT scientific papers, Brave Search, Fetch, Memory, Filesystem |
| **Security** | Ghidra reverse engineering, Snyk vulnerability scanning |
| **Workflow Automation** | n8n workflow builder, Pipedream integration |
| **Observability** | Iris eval & observability for agent tracing |
| **Design** | Figma design context, Blender 3D automation |
| **Mobile** | Android ADB automation, Xcode build tools |

### Pattern 6: Slash Command Categories

42 commands organized into 8 categories, each as a standalone `.md` file:

- **Git** (7): `/commit`, `/pr-create`, `/changelog`, `/release`, `/worktree`, `/fix-issue`, `/pr-review`
- **Testing** (6): `/tdd`, `/test-coverage`, `/e2e`, `/integration-test`, `/snapshot-test`, `/test-fix`
- **Architecture** (6): `/plan`, `/refactor`, `/migrate`, `/adr`, `/diagram`, `/design-review`
- **Documentation** (5): `/doc-gen`, `/update-codemap`, `/api-docs`, `/onboard`, `/memory-bank`
- **Security** (5): `/audit`, `/hardening`, `/secrets-scan`, `/csp`, `/dependency-audit`
- **Refactoring** (5): `/dead-code`, `/simplify`, `/extract`, `/rename`, `/cleanup`
- **DevOps** (5): `/dockerfile`, `/ci-pipeline`, `/k8s-manifest`, `/deploy`, `/monitor`
- **Workflow** (3): `/checkpoint`, `/wrap-up`, `/orchestrate`

### Pattern 7: Secret Scanning as a Pre-Write Gate

The `secret-scanner.js` hook runs on both Write and Edit PreToolUse events. It scans for 8 pattern types:
- AWS Access Keys (`AKIA...`)
- AWS Secret Keys
- GitHub Tokens (`ghp_`, `gho_`, `ghu_`, `ghs_`, `ghr_`)
- Private Keys (RSA, EC, OPENSSH, PGP)
- Generic API Keys
- Slack Tokens (`xox[bpors]-...`)
- Database URLs with credentials
- JWT Tokens

If secrets are found, it blocks the write with line-level detail. This runs before the file is written, not after.

### Pattern 8: Community Ecosystem of High-Star Projects

The most impactful external projects catalogued:

| Project | Stars | What It Does |
|---|---|---|
| **everything-claude-code** | 78,600+ | Agent harness performance optimization (skills, instincts, memory, security) |
| **claude-mem** | 35,900+ | Auto-capture + compress + inject context across sessions |
| **cc-switch** | 35,500+ | All-in-One desktop assistant for Claude Code, Codex, OpenCode, Gemini CLI |
| **wshobson/agents** | 31,300+ | 112 agents, 16 orchestrators, 146 skills, 79 tools |
| **claude-code-router** | 30,700+ | Custom model routing and interaction infrastructure |
| **awesome-claude-skills (Composio)** | 49,300+ | 30 curated skills + 832 SaaS templates |
| **awesome-claude-code (hesreallyhim)** | 34,000+ | Alternative curated list focused on skills/hooks/slash-commands |
| **claude-code-best-practice** | 25,000+ | Reference implementation for config |
| **vibe-kanban** | 23,200+ | Kanban orchestration for 10+ coding agents with isolated worktrees |
| **opcode** | 21,000+ | Tauri 2 desktop GUI for Claude Code |
| **claude-code-templates** | 23,800+ | CLI for configuring/monitoring projects |
| **SuperClaude** | 22,000+ | Config framework with cognitive personas |
| **gstack** | 15,000+ | Garry Tan's setup: 6 tools serving as CEO, Eng Manager, Release Manager, QA |
| **ccusage** | 11,500+ | Offline usage analytics from local JSONL files |
| **ccpm** | 7,600+ | GitHub Issues + Git worktrees for parallel agent execution |
| **serena** | 22,200+ | Semantic retrieval and editing MCP server |

### Pattern 9: Session Continuity Architecture

Multiple approaches to cross-session memory:

1. **Hook-based**: `session-start.js` loads, `session-end.js` saves, `learning-log.js` extracts learnings.
2. **claude-mem** (35,900 stars): Auto-captures everything Claude does, compresses with AI, injects relevant context into future sessions. SQLite + full-text search.
3. **claude-supermemory** (2,300 stars): User profile injection at session start, automatic conversation capture.
4. **claude-recap**: Per-topic session memory via Shell hooks -- archives each conversation as separate Markdown summary.
5. **cog** (240 stars): Cognitive architecture with persistent memory, self-reflection, and foresight via plain-text conventions.
6. **PreCompact hook**: Saves important context before compaction so it survives context window reduction.

### Pattern 10: Safety and Governance Layers

The community has built multiple safety/governance patterns:

- **Bouncer**: Independent quality gate using Gemini to audit Claude Code's output
- **VibeGuard**: 88 rules + 13 hooks + 14 agents for real-time interception
- **The Claude Protocol**: 13 hooks for enforcing worktree isolation and blocking unsafe operations
- **obey**: Rule enforcement with 17 lifecycle hooks, three scopes (global/stack/project), active blocking
- **cc-safe-setup**: One command (`npx cc-safe-setup`) installs 6 essential safety hooks in 10 seconds
- **brood-box**: Run agents inside hardware-isolated microVMs with egress control

---

## Notable Tools Worth Investigating Further

| Tool | Why |
|---|---|
| **claude-code-mcp** (steipete, 1,100 stars) | Run Claude Code as an MCP server -- "an agent in your agent". Permissions bypassed automatically. Enables nesting agents. |
| **preflight** | 24-tool MCP server that catches vague prompts before they cost 2-3x in wrong-then-fix cycles. Scorecards, cost estimation. |
| **reporecall** | Tree-sitter AST indexing (22 languages), hybrid keyword + vector search, call-graph traversal. Injects context in ~5ms. |
| **claude-context** (Zilliz, 5,600 stars) | Hybrid BM25 + dense vector search for semantic code search. ~40% token reduction. |
| **fractal** | Recursive project management: decomposes goals into verifiable predicates, works riskiest piece first, re-evaluates as it learns. |
| **ccusage** (11,500 stars) | Offline CLI for usage analytics from local JSONL files. Daily/monthly/session/billing reports. |
| **AIRIS MCP Gateway** | Docker-based MCP multiplexer aggregating 60+ tools behind 7 meta-tools, 97% token reduction. |
| **clooks** | Persistent hook daemon replacing per-invocation spawning -- 112x faster hooks. |

---

## Actionable Takeaways for AI Agent Mesh

### Hooks We Should Adopt or Adapt

1. **Secret scanner as pre-write gate** -- Our mesh should prevent agents from writing secrets to files. The pattern of scanning before write (not after) is correct. The 8 regex patterns in `secret-scanner.js` are a solid starting set.

2. **Smart command decomposition** -- The `smart-approve.py` pattern of recursively decomposing compound bash commands before permission-checking is more robust than checking the full command string. Worth adopting for any safety layer.

3. **Session start/end context persistence** -- Hook into session lifecycle to automatically save and restore state. This is better than relying on agents to manually manage their own context.

4. **PreCompact hook** -- Save critical context before compaction. This is something our mesh should do to prevent information loss during long sessions.

5. **Prompt quality gate (UserPromptSubmit)** -- Catch vague prompts before they waste tokens. The `prompt-check.js` hook is lightweight but could save significant cost.

### Architecture Patterns to Consider

6. **Context modes as behavioral switching** -- Instead of one-size-fits-all instructions, define named modes (dev/review/debug/deploy/research) that shift agent priorities. Simple, effective, no code needed.

7. **MCP server profiles** -- Pre-bundle MCP server configs by use case rather than forcing per-server configuration. The "Recommended 14" is a good default set.

8. **Agent specialization by domain** -- The 10-category agent taxonomy (Core Dev, Language, Infra, QA, Data/AI, DX, Specialized, Business, Orchestration, Research) is a useful organizational model.

9. **Task Coordinator as DAG orchestrator** -- The decompose-assign-parallelize-aggregate pattern with explicit dependency classification (data/schema/environment) is a mature orchestration model.

10. **Reviewer != Developer** -- Always assign review tasks to a different agent than the one that created the code. Prevents rubber-stamping.

### Ecosystem Tools to Integrate

11. **claude-mem for persistent memory** -- At 35,900 stars it is the dominant memory solution. Auto-capture, AI compression, SQLite full-text search, injection into future sessions.

12. **ccusage for cost tracking** -- Offline, local JSONL analysis. Zero API calls. Good for understanding where tokens go.

13. **claude-context (Zilliz) for semantic search** -- Hybrid BM25 + vector search giving 40% token reduction. Directly relevant to our context management.

14. **AIRIS MCP Gateway for tool aggregation** -- 97% token reduction by multiplexing 60+ tools behind 7 meta-tools. Relevant for reducing our MCP tool count in context.

### CLAUDE.md Best Practices

15. **Standard template structure**: Stack, Commands, Project Structure, Conventions, Environment Variables, Key Decisions. 50-60 lines. Concise, no fluff.

16. **Explicit anti-patterns**: The contexts include "Avoid" sections listing what NOT to do. Negative instructions are often more effective than positive ones.

17. **Convention over documentation**: "Follow existing patterns in the codebase" appears in every context mode. Point Claude at existing code rather than describing patterns from scratch.

### Community Velocity Indicators

18. The Claude Code ecosystem is moving fast. Projects are hitting 10K-70K+ stars within weeks. The SkillKit marketplace claims 400,000+ skills. Multiple competing awesome-lists exist (hesreallyhim at 34K stars, Composio at 49K stars).

19. Multi-agent orchestration is the hottest category: vibe-kanban (23K), ccpm (7.6K), oh-my-claudecode (9.9K), ruflo (21K), myclaude (2.4K) -- all tackling parallel agent coordination.

20. Safety/governance tooling is emerging as a distinct category (Bouncer, VibeGuard, The Claude Protocol, obey, brood-box) -- indicating the community is hitting real problems with uncontrolled agent behavior.
