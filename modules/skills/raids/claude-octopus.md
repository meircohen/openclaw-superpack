# Repo Raid: nyldn/claude-octopus

**Repo**: https://github.com/nyldn/claude-octopus
**Type**: Multi-LLM orchestration plugin for Claude Code
**Version**: 9.17.1 (production)
**License**: MIT
**Audited**: 2026-03-31

---

## What It Does

Claude Octopus orchestrates up to 8 AI providers (Claude, Codex, Gemini, Perplexity, OpenRouter, Copilot, Qwen, Ollama) on every task to catch blind spots before code ships. It implements a **Double Diamond** methodology (Discover → Define → Develop → Deliver) with consensus gates, adversarial cross-model review, and comprehensive safety controls.

**Key numbers**: 48 commands, 51 skills, 32 specialist personas, 146+ tests.

---

## Coordination Model

### Architecture
```
Claude Code (orchestrator entry point)
  → Plugin (.claude-plugin/plugin.json)
    → orchestrate.sh (main dispatcher)
      ├─ scripts/lib/*.sh (25+ modular libraries)
      ├─ Provider routers (codex, gemini, perplexity, openrouter, etc.)
      ├─ MCP Server (mcp-server/src/index.ts)
      └─ OpenClaw Extension (openclaw/src/index.ts)
```

### How LLMs Coordinate Per Phase

| Phase | Execution | Duration | Cost |
|-------|-----------|----------|------|
| **Discover** (Probe) | Codex + Gemini **parallel**, Claude synthesizes | 30-60s | $0.02-0.04 |
| **Define** (Grasp) | Sequential: Codex → problem, Gemini → criteria/constraints/consensus | 30-60s | $0.02-0.04 |
| **Develop** (Tangle) | Codex + Gemini propose **parallel**, Claude merges + quality gate | 1-2min | $0.04-0.10 |
| **Deliver** (Ink) | Codex (quality) + Gemini (security) **parallel**, Claude validates | 30-90s | $0.02-0.06 |
| **Full Embrace** | All 4 phases chained | 2-5min | $0.10-0.30 |

### Provider Degradation
- Codex + Gemini → Full orchestration
- One provider only → Dual perspective (that provider + Claude)
- Neither → Claude-only mode (basic functionality)

### Dynamic Fleet Dispatch
`build-fleet.sh` enforces **model family diversity** — never uses two models from the same family (OpenAI, Google, Microsoft, Alibaba, Anthropic) to prevent same-training-bias agreement.

---

## Consensus Gate

### The 75% Quality Gate

Located in `scripts/lib/quality.sh`. Per-phase thresholds:

| Phase | Threshold |
|-------|-----------|
| Discover | 50% |
| Define | 60% |
| Develop | **75%** (default) |
| Deliver | 80% |
| Security | 90% |

### Decision Tree

```
≥90% → proceed (ship it)
≥threshold → proceed_warn (ship with caution)
<threshold + retries left → retry
<threshold + supervised → escalate (human review)
else → abort
```

### Adversarial Debate Mode
- Round 1: All providers argue positions in parallel
- Round 2: Cross-critique (each critiques the other two)
- Round 3: Synthesis with winner determination
- Evidence-based rules: anti-contrarian, anti-rubber-stamp, proportional scoring
- Blinded mode available to prevent anchoring bias

### Loop Self-Regulation (v9.14.1)
Prevents runaway fix cycles with WTF (What The Fuck) scoring:
- Tracks nonsensical changes, circular fix-revert patterns, scope drift
- Sliding-window stuck detection
- Hard cap: 15 iterations (configurable)

---

## Production Readiness: YES

### Evidence
- **v9.17.1** — mature semantic versioning, 1,700+ line CHANGELOG
- **146+ tests** — smoke (13), unit (48), integration (14), E2E (8), regression (18+)
- **E2E on VPS** — automated smoke testing every 2 hours on Oracle Cloud
- **Circuit breaker pattern** — graduated backoff for transient errors, persistent state across sessions
- **Security controls** — input validation, secrets management (keys never logged), audit logging
- **Documentation** — README, SECURITY.md, AGENTS.md, CHANGELOG, 7+ architecture docs

### Safety
- Quality gates prevent blind spots from shipping
- Audit logging for all gate decisions
- Three autonomy modes: interactive, semi-autonomous, autonomous
- Provider circuit breakers prevent cascading failures

---

## Integration Points

### Claude Code Plugin
- Registered as `octo` namespace — only `/octo:*` commands activate it
- Zero changes to existing Claude Code setup
- Clean uninstall: `claude plugin uninstall octo`

### MCP Server
10 tools exposed: `octopus_discover`, `octopus_define`, `octopus_develop`, `octopus_deliver`, `octopus_embrace`, `octopus_debate`, `octopus_review`, `octopus_security`, `octopus_list_skills`, `octopus_status`

### OpenClaw Extension
- `openclaw/src/index.ts` wraps MCP tools for OpenClaw's extension API
- Exposes Octopus workflows to messaging platforms (Telegram, Discord, Signal, WhatsApp)
- Optional — core plugin works without it
- `OCTOPUS_HOST=openclaw` detection enables OpenClaw-specific features

### Hook System
| Hook | Purpose |
|------|---------|
| SessionStart | Detect context, initialize orchestrator |
| WorktreeCreate | Propagate env vars to worktrees |
| CwdChanged | Re-detect project context |
| StopFailure | Log API errors |
| FileChanged | Re-evaluate skill relevance |

---

## Key Architecture Decisions

1. **Modular decomposition** — `orchestrate.sh` decomposed into 25+ libraries in `scripts/lib/` for testability
2. **Cache-aligned prompts** — stable content first (persona, skills) + variable suffix (context, memory) → 90% token discount on repeated calls
3. **Model family diversity** — fleet dispatch enforces cross-family agreement to catch training bias
4. **Dual metadata format** — parallel agent/skill definitions for Claude Code and GitHub Copilot compatibility

---

## Relevance to Our Multi-Agent Mesh

### What We Can Steal
1. **Consensus gate pattern** — 75% agreement threshold with per-phase tuning. We should implement this for our Claude+Codex+Gemini parallel runs.
2. **Circuit breaker for providers** — graduated backoff with persistent state. Better than our current "retry 3 times then fail" approach.
3. **Model family diversity enforcement** — prevents same-bias agreement. Critical for our mesh where we run multiple models.
4. **WTF loop detection** — prevents runaway iteration. We need this for our autonomous pipelines.
5. **Cache-aligned prompt structure** — stable prefix + variable suffix for token savings.
6. **OpenClaw extension model** — their `openclaw/` directory shows how to expose multi-LLM orchestration to messaging platforms.

### What We Should NOT Copy
- Their shell-based architecture (`orchestrate.sh` + bash libraries) — works but fragile for complex state management
- The 48-command surface area — too many entry points for users to learn
- Their persona system (32 personas) — overhead without clear evidence of improved outcomes

### Recommended Actions
1. **Install it**: `claude plugin install octo` — try the consensus gate on our next feature
2. **Port the quality gate**: Adapt `scripts/lib/quality.sh` logic into our mesh coordinator
3. **Use their OpenClaw extension**: Already built for our platform, just needs configuration
4. **Study the circuit breaker**: `scripts/lib/quality.sh` `classify_error()` and `lock_provider()` patterns
