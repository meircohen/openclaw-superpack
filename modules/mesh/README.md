# AI Mesh Module

The mesh module is the multi-agent orchestration layer for OpenClaw Superpack. It routes tasks to the cheapest capable AI system, dispatches work with automatic fallback, tracks costs, and learns from outcomes to improve routing over time.

## Architecture

```
User Task -> router.py (classify + route) -> dispatch.py (execute with fallback)
                                                  |
                                          health.py (system status)
                                          stats.py  (usage analytics)
                                          cost.py   (spend tracking)
                                          learn.py  (outcome feedback loop)
```

## Core Components

| File | Purpose |
|------|---------|
| `router.py` | Keyword-based task classifier + cost-priority routing tables |
| `dispatch.py` | Executes tasks on target systems with automatic fallback chain |
| `health.py` | Connectivity, auth, and usage-limit checks for all mesh systems |
| `stats.py` | Usage analytics: daily/weekly/monthly breakdowns, success rates |
| `cost.py` | Real-time cost dashboard with spike detection and alerts |
| `mcp_server.py` | FastMCP server exposing mesh tools (route, health, dispatch, intel) |
| `learn.py` | Learning system: records outcomes, extracts instincts, evolves routing weights |
| `session.py` | Session save/resume with structured handoff sections |
| `checkpoint.py` | Git-based checkpoint system for workflow state snapshots |
| `orchestrate.py` | Multi-agent workflows (feature, bugfix, refactor, security-audit, research) |
| `verify.py` | Quality gate pipeline: build, types, lint, tests, security (fail-fast) |

## Supporting Modules

| File | Purpose |
|------|---------|
| `intercept.py` | Pre-dispatch cost/governance checks |
| `context_budget.py` | Token budget management for context windows |
| `prompt_optimize.py` | Prompt compression and optimization |
| `loop_safety.py` | Infinite loop detection for autonomous agents |
| `security_scan.py` | Secret detection and security scanning |
| `eval_harness.py` | Evaluation harness for comparing system outputs |
| `cost_tracker_hook.py` | Hook for automatic cost tracking |
| `refresh.py` | System state refresh utilities |

## Directory Structure

```
mesh/
  config/          # Per-system YAML configs (capabilities, limits, costs)
  hooks/           # Claude Code hooks (cost tracking, quality gates, governance)
  bootstrap/       # System bootstrap prompts (injected into each AI agent)
  skills/          # Reusable skill definitions (SKILL.md per skill)
  ecc-patterns/    # Engineering patterns, guides, and superpowers
  tools/           # Shell utilities (grok.sh for xAI API)
```

## Routing Philosophy

1. **Subscription/free systems FIRST** -- Claude Code, Codex, Gemini, Perplexity browser
2. **Cheap pay-per-token SECOND** -- xAI Grok, Gemini API
3. **Expensive API tokens LAST** -- OpenAI API, Anthropic API, Perplexity API

The learning system continuously adjusts these weights based on actual task outcomes.

## Quick Start

```bash
# Route a task (see recommendation without executing)
python3 mesh/router.py 'build a REST API for inventory management'

# Dispatch a task (auto-route and execute)
python3 mesh/dispatch.py 'research latest Bitcoin ETF flows'

# Check system health
python3 mesh/health.py

# View usage stats
python3 mesh/stats.py --weekly

# View cost dashboard
python3 mesh/cost.py --week
```

## MCP Server

The mesh exposes tools via MCP for use inside Claude Code or other MCP clients:

- `mesh_route` -- Route a task to the best system
- `mesh_health` -- Check all system statuses
- `mesh_dispatch` -- Execute a task with routing and fallback
- `intel_query` -- Search intelligence digests

Configure in your MCP client using `mcp_config.json`.
