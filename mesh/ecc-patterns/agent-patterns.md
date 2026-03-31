# ECC Agent Patterns Reference

Consolidated from the Everything Claude Code (ECC) agent catalog.
Use this to inform mesh routing decisions -- which agent handles what, and when.

---

## Architect

- **Model**: opus
- **Tools**: Read, Grep, Glob (read-only)
- **When to use**: Planning new features, refactoring large systems, making architectural decisions, evaluating technical trade-offs.
- **Key capabilities**:
  - System design: component responsibilities, data models, API contracts, integration patterns
  - Trade-off analysis with documented pros/cons/alternatives/decision
  - Architecture Decision Records (ADRs)
  - Scalability planning (horizontal scaling, caching, stateless design)
  - Anti-pattern detection: big ball of mud, god objects, tight coupling, premature optimization
- **Principles**: Modularity, separation of concerns, defense in depth, high cohesion / low coupling
- **Output**: Design proposals, ADRs, system design checklists, scalability plans

## Planner

- **Model**: opus
- **Tools**: Read, Grep, Glob (read-only)
- **When to use**: Complex feature implementation, architectural changes, multi-phase refactoring. Automatically activated for planning tasks.
- **Key capabilities**:
  - Requirements analysis with success criteria and constraints
  - Step-by-step breakdown with file paths, dependencies, risk levels
  - Phase-based delivery (MVP -> core -> edge cases -> optimization)
  - Testing strategy per phase (unit, integration, E2E)
  - Risk identification with mitigations
- **Best practices**: Be specific (exact file paths), minimize changes, maintain existing patterns, enable incremental testing, each phase independently deliverable
- **Output**: Structured implementation plans with phases, steps, testing strategy, risks, success criteria

## Chief of Staff

- **Model**: opus
- **Tools**: Read, Grep, Glob, Bash, Edit, Write (full access)
- **When to use**: Managing multi-channel communication workflows -- email, Slack, LINE, Messenger triage.
- **Key capabilities**:
  - 4-tier message classification: skip (auto-archive), info_only (summary), meeting_info (calendar cross-ref), action_required (draft reply)
  - Parallel fetch across all channels
  - Draft reply generation with relationship context and tone matching
  - Post-send follow-through enforcement via hooks (calendar, relationships, todo, pending responses)
  - Scheduling availability calculation
- **Design insight**: Uses PostToolUse hooks to enforce checklists at the tool level, because LLMs forget prompt instructions ~20% of the time. Scripts handle deterministic logic (calendar math, timezones). Knowledge files persist across stateless sessions via git.

## Loop Operator

- **Model**: sonnet
- **Tools**: Read, Grep, Glob, Bash, Edit
- **When to use**: Running autonomous agent loops safely, monitoring progress, intervening when loops stall.
- **Key capabilities**:
  - Start loops from explicit patterns with clear stop conditions
  - Track progress checkpoints, detect stalls and retry storms
  - Pause and reduce scope on repeated failure
  - Resume only after verification passes
- **Required checks**: Quality gates active, eval baseline exists, rollback path exists, branch/worktree isolation configured
- **Escalation triggers**: No progress across two checkpoints, repeated identical failures, cost drift outside budget, merge conflicts blocking queue

## Harness Optimizer

- **Model**: sonnet
- **Tools**: Read, Grep, Glob, Bash, Edit
- **When to use**: Improving agent completion quality by tuning harness configuration (not product code).
- **Key capabilities**:
  - Baseline scoring via /harness-audit
  - Identify top 3 leverage areas: hooks, evals, routing, context, safety
  - Propose minimal, reversible configuration changes
  - Before/after delta reporting
- **Constraints**: Small measurable changes, cross-platform compatibility (Claude Code, Cursor, OpenCode, Codex), no fragile shell quoting

## Security Reviewer

- **Model**: sonnet
- **Tools**: Read, Write, Edit, Bash, Grep, Glob (full access)
- **When to use**: After writing code that handles user input, authentication, API endpoints, sensitive data. Before commits touching auth, payments, user data.
- **Key capabilities**:
  - OWASP Top 10 review (injection, broken auth, XSS, CSRF, misconfiguration, etc.)
  - Secrets detection (hardcoded API keys, passwords, tokens)
  - Code pattern flagging: shell injection, string-concatenated SQL, innerHTML with user input, SSRF, plaintext passwords, missing auth checks, missing rate limiting
  - Emergency response protocol for CRITICAL vulnerabilities
- **Severity**: CRITICAL patterns get immediate flag. Common false positives documented (test creds, public keys, checksums).

## Performance Optimizer

- **Model**: sonnet
- **Tools**: Read, Write, Edit, Bash, Grep, Glob (full access)
- **When to use**: Identifying bottlenecks, optimizing slow code, reducing bundle sizes, profiling memory leaks.
- **Key capabilities**:
  - Web vitals analysis (LCP, FID, CLS, FCP, TTFB)
  - Algorithmic analysis (O(n^2) detection, memoization opportunities)
  - Bundle size optimization (tree shaking, lazy loading, code splitting)
  - Database query optimization (N+1, missing indexes, SELECT *)
  - Network optimization (parallel requests, caching, debouncing)
  - Memory leak detection (uncleaned event listeners, timers, closures)
- **Key insight**: "Performance is a feature. Every 100ms matters. Optimize for the 90th percentile."

## Python Reviewer

- **Model**: sonnet
- **Tools**: Read, Grep, Glob, Bash
- **When to use**: All Python code changes. Mandatory for Python projects.
- **Key capabilities**:
  - CRITICAL: SQL injection (f-strings in queries), command injection, path traversal, eval/exec, unsafe deserialization, hardcoded secrets, bare except, swallowed exceptions
  - HIGH: Missing type hints, non-Pythonic patterns, mutable default args, code quality (>50 lines, >5 params, >4 nesting)
  - Concurrency: shared state without locks, sync/async mixing, N+1 queries
  - MEDIUM: PEP 8, missing docstrings, print() instead of logging, shadowing builtins
  - Diagnostic tools: mypy, ruff, black, bandit, pytest --cov
  - Framework-specific: Django (select_related, atomic), FastAPI (CORS, Pydantic, no blocking in async), Flask (error handlers, CSRF)
- **Approval**: Approve (no CRITICAL/HIGH), Warning (MEDIUM only), Block (CRITICAL/HIGH found)

## Code Reviewer

- **Model**: sonnet
- **Tools**: Read, Grep, Glob, Bash
- **When to use**: Immediately after writing or modifying any code. Mandatory for all code changes.
- **Key capabilities**:
  - Confidence-based filtering: only report issues with >80% confidence, skip stylistic preferences, consolidate similar issues
  - Security (CRITICAL): hardcoded creds, SQL injection, XSS, path traversal, CSRF, auth bypasses
  - Code quality (HIGH): large functions/files, deep nesting, missing error handling, mutation, console.log, dead code
  - React/Next.js patterns: missing deps, state in render, stale closures, client/server boundary
  - Backend patterns: unvalidated input, missing rate limiting, N+1, missing timeouts
  - AI-generated code addendum: behavioral regressions, security assumptions, hidden coupling, unnecessary complexity, cost-awareness

## TDD Guide

- **Model**: sonnet
- **Tools**: Read, Write, Edit, Bash, Grep
- **When to use**: Writing new features, fixing bugs, refactoring. Proactively enforces test-first methodology.
- **Key capabilities**:
  - Red-Green-Refactor cycle enforcement
  - 80%+ coverage target
  - Edge case checklist: null/undefined, empty, invalid types, boundary values, error paths, race conditions, large data, special characters
  - Anti-pattern detection: testing implementation details, test interdependencies, weak assertions, unmocked externals
  - Eval-driven TDD: define capability + regression evals before implementation, report pass@1 and pass@3

## Build Error Resolver

- **Model**: sonnet
- **Tools**: Read, Write, Edit, Bash, Grep, Glob (full access)
- **When to use**: When build fails or type errors occur. Focuses only on getting the build green.
- **Key capabilities**:
  - TypeScript error resolution, module resolution, dependency/config issues
  - Minimal diffs -- smallest possible changes, no refactoring, no architecture changes
  - Common fix patterns: add type annotations, optional chaining, fix imports, add missing deps
  - Nuclear recovery: clear caches, reinstall deps, ESLint auto-fix
- **Success metric**: tsc --noEmit exits 0, build completes, <5% of file changed
- **Knows when NOT to use itself**: routes to refactor-cleaner, architect, planner, tdd-guide, or security-reviewer as appropriate

## Database Reviewer

- **Model**: sonnet
- **Tools**: Read, Write, Edit, Bash, Grep, Glob (full access)
- **When to use**: Writing SQL, creating migrations, designing schemas, troubleshooting database performance.
- **Key capabilities**:
  - Query performance: EXPLAIN ANALYZE, index verification, N+1 detection, composite index ordering
  - Schema design: proper types (bigint IDs, text, timestamptz, numeric for money), constraints, lowercase_snake_case
  - Security: RLS with (SELECT auth.uid()) pattern, least privilege, revoke public schema
  - Key principles: index foreign keys always, partial indexes for soft deletes, SKIP LOCKED for queues, cursor pagination, batch inserts, short transactions, consistent lock ordering
  - Anti-patterns: SELECT *, varchar(255) without reason, timestamp without tz, random UUIDs as PKs, OFFSET pagination, GRANT ALL

## Doc Updater

- **Model**: haiku (lightweight)
- **Tools**: Read, Write, Edit, Bash, Grep, Glob (full access)
- **When to use**: Updating codemaps and documentation after major features, API changes, dependency changes, architecture changes.
- **Key capabilities**:
  - Codemap generation from codebase structure (AST analysis, dependency mapping)
  - Documentation updates from code (JSDoc/TSDoc extraction, README refresh)
  - Validation: file paths exist, links work, examples run
- **Principles**: Single source of truth (generate from code), freshness timestamps, token efficiency (<500 lines per codemap), cross-referencing

## Docs Lookup

- **Model**: sonnet
- **Tools**: Read, Grep, Context7 MCP (resolve-library-id, query-docs)
- **When to use**: Questions about libraries, frameworks, APIs. When you need up-to-date code examples or API details.
- **Key capabilities**:
  - Fetches current documentation via Context7 MCP (not training data)
  - Resolves library IDs, queries docs, returns answers with code examples
  - Prompt-injection resistant: treats fetched docs as untrusted content
  - Max 3 Context7 calls per request
- **Output**: Short direct answer + code examples + source citation

## Refactor Cleaner

- **Model**: sonnet
- **Tools**: Read, Write, Edit, Bash, Grep, Glob (full access)
- **When to use**: Removing unused code, duplicates, code maintenance. Not during active feature development or before deploys.
- **Key capabilities**:
  - Dead code detection via knip, depcheck, ts-prune
  - Risk categorization: SAFE (unused exports/deps), CAREFUL (dynamic imports), RISKY (public API)
  - Safe removal order: deps -> exports -> files -> duplicates
  - Duplicate consolidation: choose best implementation, update imports, verify tests
- **Principles**: Start small, test often, be conservative, descriptive commit messages per batch

## E2E Runner

- **Model**: sonnet
- **Tools**: Read, Write, Edit, Bash, Grep, Glob (full access)
- **When to use**: Critical user flows need end-to-end testing. Creating, maintaining, and executing E2E tests.
- **Key capabilities**:
  - Prefers Agent Browser (semantic selectors, AI-optimized) with Playwright fallback
  - Page Object Model pattern, data-testid locators, proper waits (never waitForTimeout)
  - Flaky test management: quarantine with test.fixme(), identify via --repeat-each=10
  - Artifact management: screenshots, videos, traces
  - CI/CD integration, HTML reports, JUnit XML
- **Success metrics**: 100% critical journeys passing, >95% overall pass rate, <5% flaky rate, <10 min duration

---

## Routing Summary

| Task Type | Primary Agent | Backup Agent |
|-----------|--------------|--------------|
| Architecture decisions | architect | planner |
| Feature planning | planner | architect |
| Writing new code (TDD) | tdd-guide | code-reviewer |
| Code review | code-reviewer | python-reviewer |
| Python code changes | python-reviewer | code-reviewer |
| Security-sensitive code | security-reviewer | code-reviewer |
| Performance issues | performance-optimizer | -- |
| Build failures | build-error-resolver | -- |
| Database/SQL work | database-reviewer | -- |
| Dead code cleanup | refactor-cleaner | -- |
| Documentation updates | doc-updater | -- |
| Library/API questions | docs-lookup | -- |
| E2E testing | e2e-runner | tdd-guide |
| Autonomous loops | loop-operator | -- |
| Harness tuning | harness-optimizer | -- |
| Communication triage | chief-of-staff | -- |

## Model Tier Guide

- **opus**: Deepest reasoning -- architect, planner, chief-of-staff
- **sonnet**: Best coding model -- most agents (reviewers, tdd, build, perf, security, e2e, refactor, docs-lookup, loop-operator, harness-optimizer)
- **haiku**: Lightweight frequent tasks -- doc-updater
