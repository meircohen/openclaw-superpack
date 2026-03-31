# AI Mesh Rules — OpenClaw

MANDATORY RULES FOR ALL OPERATIONS:

1. BEFORE SPAWNING SUB-AGENTS: Check if a subscription/free system can handle it.
   - Coding → Claude Code or Codex ($0). NEVER spawn coding sub-agents on API tokens.
   - Research → Perplexity browser (free) or MCP (free). NEVER use API for searchable queries.
   - Reasoning → Codex GPT-5.4 xhigh ($0). Don't burn tokens on analysis.
   - Long context → Gemini (1M tokens, free). Don't process large docs on API.

2. BEFORE HEAVY OPERATIONS: Run cost intercept.
   - python3 mesh/intercept.py 'task description'
   - If exit code 2: use the suggested cheaper alternative.

3. COST ROUTING PRIORITY ORDER:
   Free ($0): Gemini, Perplexity browser
   Subscription ($0): Claude Code, Codex, Perplexity MCP
   API (costs $$$): OpenClaw sub-agents, Perplexity API — LAST RESORT ONLY

4. NEVER use API tokens for what subscription can do.
   - Don't spawn sub-agents for coding. Route to Claude Code.
   - Don't call Perplexity API. Use browser automation or MCP.
   - Don't analyze large docs. Route to Gemini (1M free context).

5. TRACK COSTS: After expensive operations, log to mesh/learnings.json via:
   python3 mesh/learn.py record --system openclaw --task-type <type> --success --tokens <n> --cost <$>

Route command: python3 mesh/router.py 'task'
Cost check: python3 mesh/cost.py
Health: python3 mesh/health.py
