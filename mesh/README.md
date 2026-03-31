# AI Mesh Management System

## Overview
The mesh manages 5 AI systems with intelligent routing, cost optimization, health monitoring, and usage analytics. Core principle: **subscription/free systems FIRST, pay-per-token LAST**.

## Quick Start
```bash
# Check system health
python3 mesh/health.py

# Route a task (see recommendation)
python3 mesh/router.py 'build a REST API for watch inventory'

# Dispatch a task (actually execute it)
python3 mesh/dispatch.py 'research latest Bitcoin ETF flows'

# View usage stats
python3 mesh/stats.py --daily
```

## Systems

| System | Role | Cost | Context | Primary Use |
|--------|------|------|---------|-------------|
| Claude Code | Coding agent | Subscription ($0) | 1M | Interactive coding, TDD, PRs |
| Codex | Deep reasoning | Subscription ($0) | 200K | Async code, deep analysis |
| Perplexity | Research | Mixed (free→$50/mo API) | Varies | Web search, research |
| Gemini | Speed/multimodal | Free tier ($0) | 1M | Long context, multimodal, speed |
| OpenClaw | Orchestrator | API tokens ($$) | 200K | Background, monitoring, routing |

## How Routing Works

The router classifies tasks into categories and applies hard-coded cost routing rules:

1. **Classify** — keyword matching + heuristics determine task type
2. **Route** — each task type has a priority-ordered list of systems
3. **Cost filter** — subscription/free always before API tokens
4. **Dispatch** — execute on chosen system with fallback chain

### Task Categories
- `coding` — Write, debug, refactor, test code
- `research` — Web search, analysis, real-time info
- `reasoning` — Deep analysis, architecture decisions
- `long_context` — Documents >200K tokens
- `multimodal` — Image/video/audio analysis
- `quick_answer` — Simple questions, status checks
- `background` — Monitoring, crons, autonomous tasks

## How to Add a New System

1. **Create config**: `mesh/config/<system-name>.yaml`
   ```yaml
   system:
     name: new-system
     display_name: "New System"
     role: "What it does"
   auth:
     method: subscription|api_key|free_tier
     cost_model: flat_rate|per_token|free
   runtime:
     cli: /path/to/cli
     context_window: 200000
   capabilities:
     primary: [list, of, capabilities]
   cost_routing:
     priority_for:
       coding: 4  # priority number (1=first choice)
   limits:
     daily: null
   health_check:
     command: "cli --version"
   ```

2. **Update router.py**: Add system to `SYSTEMS` dict and routing tables
3. **Update health.py**: Add health check for the new system
4. **Update dispatch.py**: Add execution method for the new system
5. **Update MESH.md**: Add to system inventory and decision tree

## How to Update Capabilities

Edit the system's YAML config in `mesh/config/`. The config files are the source of truth for what each system can do.

Key fields:
- `capabilities.primary` — What the system is best at
- `capabilities.secondary` — What it can do but isn't optimal for
- `capabilities.cannot` — Hard restrictions
- `cost_routing.priority_for` — Routing priority per task type (1=highest)
- `cost_routing.never_use_for` — Tasks this system must never handle

## How to Override Routing

### Force a specific system:
```bash
python3 mesh/dispatch.py --system gemini 'task description'
```

### Override in code:
The router returns recommendations, not mandates. Any system calling the router can choose to ignore the recommendation with justification logged.

### Permanent overrides:
Add rules to the routing tables in router.py for specific task patterns.

## Cost Routing Rules (HARD)

These are non-negotiable:

1. **NEVER** use OpenClaw for coding tasks
2. **ALWAYS** prefer subscription ($0) over API tokens
3. **ALWAYS** use Perplexity browser/MCP before Perplexity API
4. **TRACK** Gemini free tier daily limits (500 Flash, 25 Pro)
5. **TRACK** Perplexity API monthly credit ($50/mo)
6. **ALERT** when free tier hits 80% usage

## File Structure
```
mesh/
├── MESH.md              # Source of truth — system inventory, routing rules
├── README.md            # This file — developer docs
├── router.py            # Task classification and routing
├── health.py            # System health checking
├── dispatch.py          # Task execution with fallback
├── stats.py             # Usage analytics
├── config/              # Per-system configuration
│   ├── claude-code.yaml
│   ├── codex.yaml
│   ├── perplexity.yaml
│   ├── gemini.yaml
│   └── openclaw.yaml
├── usage.json           # Routing decision log (auto-created)
├── dispatch-log.json    # Execution log (auto-created)
└── health-status.json   # Last health check results (auto-created)
```

## Troubleshooting

### System shows OFFLINE
1. Check if the CLI is installed: `which claude` / `which codex` / `which gemini`
2. Check if config exists: look at the config YAML for required config files
3. For OpenClaw: check if gateway is running on localhost:18789
4. For Perplexity: check if API key env var is set, check if browser script exists

### Routing seems wrong
1. Run `python3 mesh/router.py --json 'your task'` to see classification details
2. Check if keywords in your task match the expected category
3. Override with `--system` flag if needed

### Free tier limit warnings
1. Check current usage: `python3 mesh/stats.py --daily`
2. Gemini limits reset at midnight PT
3. Perplexity API credit resets monthly
4. If near limit, tasks auto-route to alternatives

### Dispatch failures
1. Check dispatch-log.json for error details
2. Verify system is online: `python3 mesh/health.py`
3. Try with --dry-run first to verify routing
4. Force a different system with --system flag
