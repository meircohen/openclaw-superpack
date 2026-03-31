# AI Mesh Management System

## Version & Changelog
- v3.1.0 (2026-03-31) — ECC Round 2: Full extraction. 23 skills (deep-research, market-research, autonomous-loops, tdd-workflow, etc.), 11 Python hooks (cost tracker, quality gate, session manager, MCP health, governance, etc.), 14 reference docs (agent patterns, coding rules, commands, token optimization, MCP configs, research patterns, soul patterns, guides), sync-systems.sh, instinct system in learn.py, worktree orchestration. See mesh/ecc-patterns/README.md.
- v3.0.0 (2026-03-31) — ECC Round 1: 10 new tools (verify, session, orchestrate, loop_safety, security_scan, checkpoint, context_budget, prompt_optimize, eval_harness, hooks). Enhanced router with learning feedback loop. Enhanced learn.py with instinct evolution and clustering.
- v2.0.0 (2026-03-30) — Added 4 API providers: Anthropic API, OpenAI API, xAI/Grok, OpenRouter. 9 systems total. Grok CLI wrapper. Full cost priority order (13 tiers).
- v1.0.0 (2026-03-30) — Initial formalization

## System Inventory

### CLI Agents (Subscription/Free — $0 marginal cost)

#### 1. Claude Code — Primary Coding Agent
- **Role:** Primary coding agent, interactive sessions
- **Auth:** Anthropic Max subscription (flat rate — $0 marginal cost)
- **Cost Model:** Subscription — unlimited usage
- **Context:** 1M tokens (Opus 4.6)
- **Capabilities:** Full IDE integration, TDD, debugging, refactoring, PRs, architecture, MCP servers (Perplexity, Slack, Gmail, Calendar, Notion, Cloudflare, Crypto.com, Scrapling, GitNexus, context-mode), file read/write/edit, bash execution, agent spawning
- **CLI:** claude
- **Config:** ~/.claude/settings.json, ~/.claude.json
- **Limits:** None (subscription)

#### 2. Codex — Deep Reasoning Agent
- **Role:** Async code generation, deep reasoning tasks
- **Auth:** OpenAI Pro subscription (flat rate — $0 marginal cost)
- **Cost Model:** Subscription — unlimited usage
- **Context:** 200K tokens
- **Capabilities:** Code generation, feature branches, test suites, parallel tasks, deep reasoning (gpt-5.4 xhigh), async execution without human in loop
- **CLI:** codex
- **Config:** ~/.codex/config.toml
- **Limits:** None (subscription)

#### 3. Gemini — Speed/Long-Context Agent
- **Role:** Fast responses, long context, multimodal
- **Auth:** Google AI Studio free tier
- **Cost Model:** Free tier — $0
- **Context:** 1M tokens (largest free-tier in mesh)
- **Capabilities:** Speed (Flash), long context analysis, multimodal (video/audio/image), Google Search grounding, thinking mode (Pro)
- **CLI:** gemini
- **Config:** ~/.gemini/settings.json
- **Limits:** 500 req/day (Flash), 25 req/day (Pro)

#### 4. OpenClaw (Oz) — Orchestrator
- **Role:** Gateway orchestrator, 24/7 autonomous operations
- **Auth:** Anthropic API key (pay-per-token)
- **Cost Model:** Variable — ~$0.003/1K input, ~$0.015/1K output (Claude 3.5 Sonnet)
- **Context:** 200K tokens
- **Capabilities:** Orchestration, background tasks, monitoring, cron jobs, Twitter/X, Telegram bridge, MCP access (Gmail, Slack, Calendar, Notion), deployment, heartbeat
- **CLI:** Gateway at localhost:18789
- **Config:** ~/.openclaw/openclaw.json
- **Limits:** Budget-constrained (minimize token usage)

#### 5. Perplexity — Research Agent
- **Role:** Web research, real-time information
- **Auth:** Max subscription ($200/mo) + API key (pplx-...)
- **Cost Model:** Mixed — browser automation FREE, MCP via subscription FREE, API burns $50/mo credit
- **Context:** Varies by method
- **Capabilities:** Web search, deep research, real-time news, citation-backed answers, reasoning
- **Access Methods:**
  - Browser automation: scripts/perplexity_uc.py (FREE, unlimited)
  - MCP server: @perplexity-ai/mcp-server via Claude Code/Codex (subscription, FREE)
  - Direct API: pplx-... key ($50/mo credit — LAST RESORT)
- **Config:** ~/.openclaw/perplexity_uc_profile/
- **Limits:** API credit: $50/mo (track carefully)

### API Providers (Pay-per-token — use only when CLI agents can't do it)

#### 6. Anthropic API (Direct)
- **Role:** Direct Claude model access — fallback when Claude Code CLI unavailable
- **Auth:** API key in auth-profiles.json (anthropic:default)
- **Cost Model:** Pay-per-token (EXPENSIVE)
- **Models:** Opus 4.6 (1M ctx), Opus 4.5, Sonnet 4.5, Sonnet 4, Haiku 4.5
- **Endpoint:** https://api.anthropic.com/v1
- **Config:** ~/.openclaw/auth-profiles.json
- **Note:** ⚠️ Claude Code CLI does the same for $0 — use API only as fallback

#### 7. OpenAI API (Direct)
- **Role:** Direct GPT/o-series access — fallback when Codex CLI unavailable
- **Auth:** API key in auth-profiles.json (openai:default)
- **Cost Model:** Pay-per-token
- **Models:** GPT-5.4, GPT-5.2, GPT-5.1, GPT-5, GPT-4.1, o3, o3-pro, o4-mini, o1, o1-pro
- **Endpoint:** https://api.openai.com/v1
- **Config:** ~/.openclaw/auth-profiles.json
- **Note:** ⚠️ Codex CLI does the same for $0 — use API only as fallback. o3-pro/o1-pro are VERY expensive.

#### 8. xAI / Grok
- **Role:** Ultra-long context (2M tokens!), fast coding
- **Auth:** API key in auth-profiles.json (xai:default)
- **Cost Model:** Pay-per-token
- **Models:** Grok-4 (256K), Grok-4-fast (2M!), Grok-4.20-beta (2M), Grok-3, grok-code-fast-1
- **Endpoint:** https://api.x.ai/v1 (OpenAI-compatible)
- **CLI Wrapper:** `mesh/tools/grok.sh`
- **Config:** ~/.openclaw/auth-profiles.json
- **KILLER FEATURE:** Grok-4-fast has **2M token context** — largest of ANY model in the mesh!
- **Usage:** `grok 'prompt'`, `grok --code 'prompt'`, `grok --long 'prompt'`, stdin piping

#### 9. OpenRouter (Aggregator)
- **Role:** Access to 100+ models including DeepSeek, Llama, Mistral, Qwen
- **Auth:** API key in auth-profiles.json (openrouter:default)
- **Cost Model:** Varies — some models are FREE (rate-limited), others cheap
- **Models:** DeepSeek R1 (free!), Llama 4 (free!), Qwen Coder (free!), Mistral, + 100 more
- **Endpoint:** https://openrouter.ai/api/v1 (OpenAI-compatible)
- **Config:** ~/.openclaw/auth-profiles.json
- **Note:** PRIMARY for: free models ($0), exotic models (DeepSeek/Llama/Qwen), cheap fallback

## Cost Routing Rules (HARD RULES)

### Master Priority Order (cheapest → most expensive)
1. Claude Code CLI (subscription — $0)
2. Codex CLI (subscription — $0)
3. Gemini CLI (free tier — $0)
4. Perplexity browser (free — $0)
5. Perplexity MCP via CC/Codex (subscription — $0)
6. OpenRouter free models ($0, rate-limited)
7. Grok API (pay-per-token, check pricing)
8. Gemini API (pay-per-token, cheap)
9. OpenAI API (pay-per-token)
10. Anthropic API (pay-per-token, expensive)
11. Perplexity API (burns $50/mo credit)
12. OpenRouter paid models (varies)
13. o3-pro / o1-pro (VERY expensive — critical reasoning ONLY)

### Priority: Subscription/Free FIRST → API tokens LAST

**Coding/File tasks:**
1. Claude Code CLI (subscription — $0) ★ PRIMARY
2. Codex CLI (subscription — $0)
3. Gemini CLI (free tier — $0)
4. OpenRouter free models (Qwen Coder, Llama — $0)
5. Grok code-fast-1 (cheap, fast)
6. OpenAI API / Anthropic API (expensive fallback)
7. ⛔ NEVER use OpenClaw sub-agents for coding

**Research/Search tasks:**
1. Perplexity browser automation (free — unlimited)
2. Perplexity MCP via Claude Code (subscription — $0)
3. Perplexity MCP via Codex (subscription — $0)
4. Gemini with Google Search grounding (free tier)
5. Perplexity API ($50/mo credit — LAST RESORT)

**Reasoning/Analysis tasks:**
1. Codex CLI with gpt-5.4 xhigh reasoning (subscription — $0) ★ PRIMARY
2. Gemini 2.5 Pro thinking mode (free tier)
3. Claude Code (subscription — $0)
4. DeepSeek R1 via OpenRouter (free, rate-limited)
5. Grok-4 (pay-per-token)
6. o3 via OpenAI API (expensive)
7. o3-pro / o1-pro (VERY expensive — critical reasoning ONLY)

**Long context tasks (>200K tokens):**
1. Grok-4-fast (2M context!) ★ for >1M tokens
2. Gemini (1M context — free tier) ★ for ≤1M tokens
3. Claude Code (1M context — subscription, Opus 4.6)
4. Codex (200K context — subscription)
5. Anthropic API (1M context — expensive)

**Quick answers/messaging:**
1. OpenClaw (already running — marginal cost)
2. Gemini Flash (free tier — fastest)
3. OpenRouter free models ($0)

**Multimodal (video/audio/image analysis):**
1. Gemini (native multimodal — free tier) ★ PRIMARY
2. OpenClaw (has image tool)
3. Claude Code (limited image support)

**Exotic models (DeepSeek, Llama, Qwen, Mistral):**
1. OpenRouter (free or cheap) ★ ONLY SOURCE

## Decision Tree

```
TASK RECEIVED
│
├─ Is it coding/file work?
│  ├─ Interactive session? → Claude Code ($0)
│  ├─ Async, no human needed? → Codex ($0)
│  ├─ Quick file edit? → Gemini CLI ($0)
│  ├─ Need exotic model? → OpenRouter free (Qwen Coder, $0)
│  ├─ Need fast cheap code? → Grok code-fast-1 ($)
│  └─ ⛔ NEVER OpenClaw for coding
│
├─ Is it research/search?
│  ├─ Can use browser? → Perplexity browser ($0)
│  ├─ In Claude Code session? → Perplexity MCP ($0)
│  ├─ Need Google grounding? → Gemini ($0)
│  └─ API only? → Perplexity API (track credit!)
│
├─ Is it reasoning/analysis?
│  ├─ Deep reasoning needed? → Codex gpt-5.4 xhigh ($0)
│  ├─ Needs thinking mode? → Gemini Pro ($0)
│  ├─ Free alternative? → DeepSeek R1 via OpenRouter ($0)
│  ├─ Critical, must be best? → o3 via API ($$)
│  └─ General analysis? → Claude Code ($0)
│
├─ Is it long context?
│  ├─ >1M tokens? → Grok-4-fast (2M context!) ($)
│  ├─ ≤1M tokens? → Gemini (1M, free) ($0)
│  ├─ ≤1M, needs coding? → Claude Code (1M Opus 4.6) ($0)
│  └─ ≤200K? → Codex ($0)
│
├─ Is it multimodal?
│  └─ → Gemini (native multimodal, $0)
│
├─ Is it quick answer/status?
│  ├─ OpenClaw running? → OpenClaw (~$0)
│  ├─ → Gemini Flash ($0)
│  └─ → OpenRouter free ($0)
│
├─ Is it background/monitoring?
│  └─ → OpenClaw (24/7)
│
├─ Need exotic model (DeepSeek/Llama/Qwen)?
│  └─ → OpenRouter (free or cheap)
│
└─ Is it MCP action (email/slack/calendar)?
   └─ → Claude Code (has MCP servers)
```

## Current Status

| System | Type | Status | Notes |
|--------|------|--------|-------|
| Claude Code | CLI (subscription) | 🟢 Online | Primary coding |
| Codex | CLI (subscription) | 🟢 Online | Deep reasoning |
| Gemini | CLI (free tier) | 🟢 Online | Speed/multimodal |
| OpenClaw | Gateway (API) | 🟢 Online | 24/7 orchestrator |
| Perplexity | Mixed (free/API) | 🟢 Online | Research |
| Anthropic API | API (pay-per-token) | 🟡 Check | Claude fallback |
| OpenAI API | API (pay-per-token) | 🟡 Check | GPT/o-series fallback |
| xAI / Grok | API (pay-per-token) | 🟡 Check | 2M context! |
| OpenRouter | API (free + paid) | 🟡 Check | 100+ models |

_Run `python3 mesh/health.py` to update all status._

## Free Tier Tracking

| Resource | Limit | Used | Remaining |
|----------|-------|------|-----------|
| Gemini Flash | 500 req/day | — | — |
| Gemini Pro | 25 req/day | — | — |
| Perplexity API | $50/mo | — | — |
| OpenRouter free models | rate-limited | — | — |

_Run `python3 mesh/stats.py` for detailed tracking._

## Architecture

```
                         ┌─────────────┐
                         │   the operator      │
                         └──────┬──────┘
                                │
              ┌─────────────────┼─────────────────┐
              │                 │                  │
        ┌─────┴─────┐    ┌─────┴─────┐    ┌──────┴──────┐
        │Claude Code │    │  OpenClaw  │    │  Telegram   │
        │(Interactive)│    │  (24/7)   │    │  (Mobile)   │
        └─────┬─────┘    └─────┬─────┘    └──────┬──────┘
              │                 │                  │
    ┌─────────┼─────────────────┼──────────────────┘
    │         │                 │
┌───┴───┐ ┌──┴──┐ ┌───────────┴───────────┐ ┌────────┐
│ Codex │ │Gemini│ │     Perplexity        │ │  MCP   │
│(Async)│ │(Fast)│ │    (Research)         │ │Servers │
└───────┘ └─────┘ └───────────────────────┘ └────────┘
                                │
              ┌─────────────────┼─────────────────┐
              │                 │                  │
        ┌─────┴─────┐    ┌─────┴─────┐    ┌──────┴──────┐
        │Anthropic   │    │OpenAI API │    │ OpenRouter  │
        │API ($$)    │    │  ($$)     │    │(free+paid)  │
        └───────────┘    └───────────┘    └─────────────┘
              │                                    │
        ┌─────┴─────┐                              │
        │ xAI/Grok  │ ←── 2M context!             │
        │  ($)      │                              │
        └───────────┘                    DeepSeek, Llama,
                                         Mistral, Qwen...
```

## Mesh Tools (v3.0 — ECC-Enhanced)

### Core (v1-v2)

| Tool | File | Description |
|------|------|-------------|
| Router | `router.py` | Intelligent task routing with learning feedback loop |
| Health | `health.py` | Parallel health checks for all 9 systems |
| Dispatch | `dispatch.py` | Task execution with fallback chain |
| Stats | `stats.py` | Usage analytics and cost breakdown |
| Intercept | `intercept.py` | Cost intercept layer — catches expensive ops |
| Learn | `learn.py` | Records outcomes, adjusts weights, instinct evolution |
| Cost | `cost.py` | Real-time cost tracking with alerts |
| Refresh | `refresh.py` | Auto-capability discovery and config update |
| Task Queue | `task_queue.py` | Batch processing with priority ordering |
| Add System | `add-system.py` | Single-command new system setup |

### v3 Tools (ECC-Integrated)

| Tool | File | Description | Source |
|------|------|-------------|--------|
| Verify | `verify.py` | Quality gate pipeline: Build→Types→Lint→Tests→Security | ECC /verify |
| Session | `session.py` | Session save/resume with "What Not To Retry" | ECC /save-session |
| Orchestrate | `orchestrate.py` | Multi-agent orchestration with handoff documents | ECC /orchestrate |
| Loop Safety | `loop_safety.py` | Autonomous loop management with checkpoints | ECC loop-operator |
| Security Scan | `security_scan.py` | Secret detection + OWASP vulnerability patterns | ECC security-reviewer |
| Checkpoint | `checkpoint.py` | Lightweight workflow state snapshots via git | ECC /checkpoint |
| Context Budget | `context_budget.py` | Context window budget analysis and optimization | ECC /context-budget |
| Prompt Optimize | `prompt_optimize.py` | Prompt analysis → intent/scope/system matching | ECC /prompt-optimize |
| Eval Harness | `eval_harness.py` | Eval-driven development with pass@k metrics | ECC eval-harness |
| Hooks | `hooks.py` | Event-driven automation with profiles (minimal/standard/strict) | ECC cursor hooks |

### Quick Reference

```bash
# Quality gates
python3 mesh/verify.py --pre-pr              # Full verification before PR
python3 mesh/verify.py --quick               # Just build + tests
python3 mesh/security_scan.py --pre-commit   # Scan staged files

# Session management
python3 mesh/session.py save --name "auth" --building "OAuth2 integration"
python3 mesh/session.py resume               # Resume most recent session
python3 mesh/session.py list                 # List all sessions

# Multi-agent orchestration
python3 mesh/orchestrate.py feature "Add user auth"
python3 mesh/orchestrate.py bugfix "Fix race condition"
python3 mesh/orchestrate.py research "Compare vector DBs"

# Loop safety
python3 mesh/loop_safety.py start --pattern sequential --task "Process PRs"
python3 mesh/loop_safety.py checkpoint --name "batch-1"
python3 mesh/loop_safety.py status
python3 mesh/loop_safety.py stop --reason "completed"

# Checkpoints
python3 mesh/checkpoint.py create "feature-start"
python3 mesh/checkpoint.py verify "feature-start"  # Diff since checkpoint

# Context management
python3 mesh/context_budget.py               # Analyze context usage
python3 mesh/context_budget.py --verbose     # Full item breakdown

# Prompt optimization
python3 mesh/prompt_optimize.py "Add caching to the API"

# Eval harness
python3 mesh/eval_harness.py create --name "router-test" --command "python3 mesh/router.py 'test'"
python3 mesh/eval_harness.py run --name "router-test" --trials 5
python3 mesh/eval_harness.py report

# Learning & instincts
python3 mesh/learn.py instincts              # Extract patterns from learnings
python3 mesh/learn.py evolve                 # Cluster into routing rules
python3 mesh/learn.py analyze --per-category # Per-system + task-type breakdown

# Hooks
python3 mesh/hooks.py setup                  # Register default hooks
python3 mesh/hooks.py list                   # Show registered hooks
python3 mesh/hooks.py profiles               # Show available profiles
python3 mesh/hooks.py fire pre-dispatch --context '{"task":"..."}'
```

## ECC Integration Patterns

Patterns extracted from [everything-claude-code](https://github.com/affaan-m/everything-claude-code) (50K+ stars). Full details in `mesh/ecc-patterns/README.md`.

### Key Principles Applied

1. **Evidence Before Assertions** — Verification runs BEFORE claiming success
2. **Deterministic Over Probabilistic** — Code-based checks (tests, build) preferred over LLM judgment
3. **Non-Blocking Security** — Scans warn but don't block by default; only CRITICAL blocks
4. **Handoff Documents** — Structured context passing between systems in multi-agent workflows
5. **Session Continuity** — "What Did NOT Work" prevents blind retry across sessions
6. **Phase-Aware Context** — Compact between phases (Research→Planning→Implementation→Testing)
7. **Instinct Evolution** — Learnings cluster into routing rules automatically
8. **Hook Profiles** — Three levels (minimal/standard/strict) control automation depth
9. **Checkpoint-Based Progress** — Explicit state snapshots for safe autonomous loops
10. **pass@k Metrics** — Measure agent reliability statistically, not anecdotally
