# ECC Command Reference

Consolidated reference for all Everything Claude Code (ECC) slash commands, grouped by category. For each command: name, one-line description, and when to use.

> Source: `github.com/affaan-m/everything-claude-code`

---

## Session Management

| Command | Description | When to Use |
|---------|-------------|-------------|
| `/save-session` | Save current session state to a dated file so work can be resumed later. | End of a work session, before hitting context limits, after solving a complex problem. |
| `/resume-session` | Load the most recent session file and orient before doing any work. | Starting a new session to continue previous work, after a fresh start due to context limits. |
| `/sessions` | Manage session history -- list, load, alias, and inspect session metadata. | When you need to find, organize, or review past sessions. |
| `/checkpoint` | Create or verify a named checkpoint in your workflow with git state tracking. | At implementation milestones, before/after risky changes, to track progress. |
| `/aside` | Answer a quick side question without interrupting or losing context from the current task. | Mid-task curiosity, needing a quick explanation without derailing work. |

---

## Development

| Command | Description | When to Use |
|---------|-------------|-------------|
| `/tdd` | Enforce test-driven development: scaffold interfaces, write tests FIRST, then implement minimal code to pass. | Implementing new features, adding functions, fixing bugs, building critical logic. |
| `/plan` | Restate requirements, assess risks, and create a step-by-step implementation plan. Waits for user CONFIRM before touching code. | Starting a new feature, significant architectural changes, complex refactoring. |
| `/code-review` | Comprehensive security and quality review of uncommitted changes. | Before committing, reviewing PRs, checking for security issues and code quality. |
| `/build-fix` | Incrementally fix build and type errors with minimal, safe changes. One error at a time. | When `npm run build`, `cargo build`, `go build`, etc. fails with errors. |
| `/verify` | Run comprehensive verification: build, types, lint, tests, console.log audit, git status. | Before PRs, before committing, to confirm codebase is clean. |
| `/refactor-clean` | Safely identify and remove dead code with test verification at every step. | After long coding sessions, when codebase has accumulated unused code. |

---

## Quality

| Command | Description | When to Use |
|---------|-------------|-------------|
| `/quality-gate` | Run the ECC quality pipeline (formatter, lint, type checks) on demand for a file or project scope. | When you want hook-like checks on demand, before merging. |
| `/test-coverage` | Analyze test coverage, identify gaps, and generate missing tests to reach 80%+ coverage. | When coverage is below target, to find and fill testing gaps. |
| `/e2e` | Generate and run end-to-end Playwright tests for user flows. Captures screenshots/videos/traces. | Testing critical user journeys, multi-step flows, UI interactions, pre-deployment. |
| `/eval` | Manage eval-driven development: define capability/regression evals, run checks, generate reports. | When shipping features that need measurable quality criteria. |
| `/learn-eval` | Extract reusable patterns from the session with a quality gate and save-location decision before writing any skill file. | After solving a non-trivial problem, to capture knowledge with quality assurance. |

---

## Learning

| Command | Description | When to Use |
|---------|-------------|-------------|
| `/learn` | Analyze the current session and extract patterns worth saving as skills. | After solving a non-trivial problem, to capture reusable knowledge. |
| `/evolve` | Analyze instincts and suggest or generate evolved structures (commands, skills, agents). | When you have accumulated instincts and want to consolidate them into higher-level artifacts. |
| `/instinct-export` | Export instincts from project/global scope to a shareable YAML file. | Sharing with teammates, transferring to a new machine, contributing to project conventions. |
| `/instinct-import` | Import instincts from a local file or URL into project/global scope. | Onboarding team conventions, importing shared patterns. |
| `/instinct-status` | Show learned instincts (project + global) with confidence levels, grouped by domain. | To review what has been learned, check confidence levels. |
| `/skill-create` | Analyze local git history to extract coding patterns and generate SKILL.md files. | When setting up skills for a new project, understanding team patterns. |
| `/promote` | Promote project-scoped instincts to global scope when they appear useful across projects. | When a project pattern proves universally useful. |
| `/prune` | Delete pending instincts older than 30 days that were never promoted. | Periodic cleanup of the instinct system. |
| `/projects` | List known projects and their instinct statistics. | To see which projects have learning data. |

---

## Context and Optimization

| Command | Description | When to Use |
|---------|-------------|-------------|
| `/context-budget` | Analyze context window usage across agents, skills, MCP servers, and rules to find optimization opportunities. | When sessions feel slow, when hitting context limits early, to audit token overhead. |
| `/prompt-optimize` | Analyze a draft prompt and output an optimized, ECC-enriched version ready to paste and run. Advisory only. | Before starting a complex task, to maximize ECC leverage. |
| `/model-route` | Recommend the best model tier (haiku/sonnet/opus) for the current task by complexity and budget. | When unsure which model to use for a task. |
| `/rules-distill` | Scan skills to extract cross-cutting principles and distill them into rules. | When skills have accumulated enough patterns to warrant rule extraction. |

---

## Orchestration

| Command | Description | When to Use |
|---------|-------------|-------------|
| `/orchestrate` | Sequential agent workflow for complex tasks (feature, bugfix, refactor, security). Chains agents with handoff documents. | Multi-agent workflows: features needing plan+TDD+review+security, complex bugs, refactors. |
| `/loop-start` | Start a managed autonomous loop pattern with safety defaults (sequential, continuous-pr, rfc-dag, infinite). | When running Claude in an autonomous development loop. |
| `/loop-status` | Inspect active loop state, progress, and failure signals. | Monitoring an active autonomous loop. |
| `/multi-plan` | Multi-model collaborative planning (Codex + Gemini + Claude) with context retrieval and dual-model analysis. | Complex planning requiring multiple AI perspectives (backend + frontend). |
| `/multi-execute` | Multi-model collaborative execution: get prototype from plan, Claude refactors and implements, multi-model audit. | Executing a plan generated by `/multi-plan`. |
| `/multi-workflow` | Full multi-model development workflow (Research, Ideation, Plan, Execute, Optimize, Review). | End-to-end development with multi-model collaboration. |
| `/multi-backend` | Backend-focused multi-model workflow, Codex-led. | Backend tasks: API design, algorithms, database optimization, business logic. |
| `/multi-frontend` | Frontend-focused multi-model workflow, Gemini-led. | Frontend tasks: component design, responsive layout, UI animations, style optimization. |
| `/devfleet` | Orchestrate parallel Claude Code agents via DevFleet -- plan from natural language, dispatch in isolated worktrees. | Large-scale parallel development with multiple agents. |

---

## Language-Specific

### Python

| Command | Description | When to Use |
|---------|-------------|-------------|
| `/python-review` | Comprehensive Python code review for PEP 8, type hints, security, and Pythonic idioms. | After writing/modifying Python code, before committing, reviewing Python PRs. |

### Go

| Command | Description | When to Use |
|---------|-------------|-------------|
| `/go-review` | Comprehensive Go code review for idiomatic patterns, concurrency safety, error handling, and security. | After writing/modifying Go code, before committing, reviewing Go PRs. |
| `/go-build` | Fix Go build errors, go vet warnings, and linter issues incrementally. | When `go build ./...` fails. |
| `/go-test` | Enforce TDD workflow for Go with table-driven tests. Write tests first, then implement. | Implementing new Go functions, adding test coverage, fixing bugs. |

### Rust

| Command | Description | When to Use |
|---------|-------------|-------------|
| `/rust-review` | Comprehensive Rust code review for ownership, lifetimes, error handling, unsafe usage, and idiomatic patterns. | After writing/modifying Rust code, before committing, reviewing Rust PRs. |
| `/rust-build` | Fix Rust build errors, borrow checker issues, and dependency problems incrementally. | When `cargo build` fails. |
| `/rust-test` | Enforce TDD workflow for Rust with tests first and 80%+ coverage via cargo-llvm-cov. | Implementing new Rust functions, adding test coverage. |

### C++

| Command | Description | When to Use |
|---------|-------------|-------------|
| `/cpp-review` | Comprehensive C++ code review for memory safety, modern C++ idioms, concurrency, and security. | After writing/modifying C++ code, before committing. |
| `/cpp-build` | Fix C++ build errors, CMake issues, and linker problems incrementally. | When C++ build fails. |
| `/cpp-test` | Enforce TDD workflow for C++ with GoogleTest tests first and gcov/lcov coverage. | Implementing new C++ functions, adding test coverage. |

### Kotlin / Android

| Command | Description | When to Use |
|---------|-------------|-------------|
| `/kotlin-review` | Comprehensive Kotlin code review for idiomatic patterns, null safety, coroutine safety, and security. | After writing/modifying Kotlin code, before committing. |
| `/kotlin-build` | Fix Kotlin/Gradle build errors, compiler warnings, and dependency issues incrementally. | When Kotlin build fails. |
| `/kotlin-test` | Enforce TDD workflow for Kotlin with Kotest tests first and 80%+ coverage via Kover. | Implementing new Kotlin functions, adding test coverage. |
| `/gradle-build` | Fix Gradle build errors for Android and Kotlin Multiplatform projects. | When Gradle build fails for Android/KMP projects. |

---

## Documentation and Maintenance

| Command | Description | When to Use |
|---------|-------------|-------------|
| `/docs` | Look up current documentation for a library or topic via Context7 MCP. | When you need up-to-date docs for a library, framework, or API. |
| `/update-docs` | Sync documentation with the codebase, generating from source-of-truth files. | When code has changed and docs need updating. |
| `/update-codemaps` | Analyze codebase structure and generate token-lean architecture documentation. | When codebase structure has changed, to help Claude navigate efficiently. |
| `/harness-audit` | Run a deterministic repository harness audit and return a prioritized scorecard. | Periodic health checks on your ECC setup (hooks, skills, commands, agents). |
| `/skill-health` | Show skill portfolio health dashboard with charts, success rates, and failure patterns. | Reviewing the health and effectiveness of your skills. |

---

## Utilities

| Command | Description | When to Use |
|---------|-------------|-------------|
| `/claw` | Start NanoClaw v2 -- ECC's persistent, zero-dependency REPL with model routing and skill hot-load. | When you want a lightweight interactive AI agent session. |
| `/pm2` | Auto-analyze project and generate PM2 service management commands. | Setting up process management for project services. |
| `/setup-pm` | Configure your preferred package manager (npm/pnpm/yarn/bun). | Project setup, switching package managers. |
