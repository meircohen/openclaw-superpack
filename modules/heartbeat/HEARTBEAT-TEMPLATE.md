# HEARTBEAT.md -- Runtime Operations (Compact)

<!--
  HEARTBEAT TEMPLATE
  ==================
  This file defines the recurring maintenance loop ("heartbeat") that your
  orchestrator agent runs on a schedule. Each section is a phase that runs
  in order. Customize the placeholders below for your setup.

  Placeholders:
    {{WORKSPACE}}          - Absolute path to your workspace root
    {{AGENT_NAME}}         - Name of your orchestrator agent
    {{TIMEZONE}}           - Your local timezone (e.g., America/New_York)
    {{PROTECTED_CONTACT}}  - Name of person who must never receive auto-messages
    {{LOCATION}}           - Your city/region for location-aware features
    {{SHABBAT_ZIP}}        - ZIP code for Shabbat times (if applicable, or remove section)
    {{FREE_TIER_LIMITS}}   - Your API rate limits per provider
-->

Objective: run reliable, high-signal maintenance with minimal token usage.

Execution order: memory blocks check -> shared context sync -> provider health -> channel/cron health -> urgent calendar/email -> stale follow-ups.

Rules:
- Report only actionable items.
- Return `HEARTBEAT_OK` when no action is needed.
- No markdown tables for Telegram.
- Never auto-send messages to {{PROTECTED_CONTACT}}; draft first and ask approval.

<!-- ==========================================================================
  PHASE 1: Memory Blocks Check (FIRST STEP - every heartbeat)
  Purpose: Load current priorities and pending items so every subsequent
           decision is informed by what matters right now.
========================================================================== -->

Memory blocks check (FIRST STEP - every heartbeat):
- Read `memory/blocks/active_guidance.md` for current priorities
- Check `memory/blocks/pending_items.md` for tasks awaiting action
- Use these as context for all heartbeat decisions

<!-- ==========================================================================
  PHASE 2: Shared Context Sync (every heartbeat, after memory blocks)
  Purpose: Process cross-system handoffs, dispatch work, clean up inboxes.
  This is the coordination hub that keeps all agents in sync.
========================================================================== -->

Shared context sync (every heartbeat, after memory blocks):
- Run `bash scripts/shabbat-times.sh check` -- if "shabbat", suppress all non-P0 escalations
  <!-- Remove the shabbat line if not applicable to your setup -->
- Check `shared/escalations/` for any P0/P1 urgent items -- act immediately (P0 always, P1 only on weekdays)
- Run `bash scripts/handoff.sh list pending` -- pick up any handoffs addressed to {{AGENT_NAME}}
- Run `bash scripts/dispatch.sh check` -- auto-dispatch pending handoffs to Claude Code/Codex via CLI
- Run `bash scripts/dispatch.sh verify` -- check if dispatched runs completed
- Run `bash scripts/handoff.sh stale` -- flag any handoffs pending >48 hours
- Update "Currently Working On" in CONTEXT.md if starting/finishing work
- Check `shared/replies/` for completed Telegram-originated tasks -- deliver via Telegram and archive
- Check `shared/notifications/` for pending completion notifications -- deliver via Telegram and archive/suppress
- Check `shared/inbox/` for read messages older than 24h -- clean up

<!-- ==========================================================================
  PHASE 3: Session Briefing Refresh (every heartbeat)
  Purpose: Generate single-file context documents that other agents read at
           session start. This is how agents stay current without reading
           dozens of files.
========================================================================== -->

Session briefing refresh (every heartbeat):
- Run `bash scripts/generate-briefing.sh` to update shared/BRIEFING.md
- Run `bash scripts/generate-code-briefing.sh` to update shared/CLAUDE-CODE-BRIEFING.md
- Check `shared/mcp-proxy/requests/` for pending proxy requests from Claude Code/Cowork
  - If {{AGENT_NAME}} can fulfill (e.g. BTC price, health data), write response directly
  - If stale (>30 min pending), flag in next briefing
- This is the single-file context Claude Code/Cowork reads at session start

<!-- ==========================================================================
  PHASE 4: Daily Digest Generation (once per day, first heartbeat after 8am)
  Purpose: Produce a daily summary of all agent activity, pending work,
           and blocked items. Also handles cleanup of stale data.
========================================================================== -->

Daily digest generation (once per day, first heartbeat after 8am):
- Generate `shared/digest/YYYY-MM-DD.md` summarizing:
  - What {{AGENT_NAME}} did in the last 24 hours
  - Pending handoffs for Claude Code/Cowork
  - Blocked items needing attention
  - Stale handoffs (>48 hours unclaimed)
- Run `bash scripts/generate-memory-snapshot.sh` to refresh shared/MEMORY-SNAPSHOT.md
- Update shared/METRICS.md with current handoff/escalation/performance stats
- Clean up resolved escalation files older than 7 days
- Clean up read messages in shared/inbox/ older than 24 hours

<!-- ==========================================================================
  PHASE 5: Memory Maintenance (once per day, first heartbeat after 8am)
  Purpose: Consolidate learnings from yesterday, update memory blocks,
           and keep the memory system accurate.
========================================================================== -->

Memory maintenance (once per day, first heartbeat after 8am):
- Review yesterday's daily notes -- extract key patterns
- Update relevant memory blocks (active_guidance, session_patterns, pending_items)
- Consolidate completions: pending_items -> active_guidance "Recent Completions"
- Update tool_usage if new tools added or patterns learned
- Verify active-tasks.md still reflects reality (legacy, will migrate to blocks)

<!-- ==========================================================================
  PHASE 6: Agent Roster Refresh (once per day, first heartbeat after 8am)
  Purpose: Discover new specialist agents and update routing awareness.
========================================================================== -->

Agent roster refresh (once per day, first heartbeat after 8am):
- Run `bash scripts/discover-agents.sh` to see all registered specialist agents
- Compare against known roster -- note any new agents or removed agents
- If a new specialist is found, read their SOUL.md to understand their domain
- Update routing awareness: know when to delegate vs handle yourself

<!-- ==========================================================================
  PHASE 7: Knowledge Sharing (once per day, first heartbeat after 8am)
  Purpose: Sync shared knowledge across agents via the agent-room system.
  Remove this section if you don't use an agent-room knowledge bus.
========================================================================== -->

Knowledge sharing (once per day, first heartbeat after 8am):
- Check for new shared knowledge: `cd agent-room && node scripts/heartbeat-knowledge-sync.js <agent_id>`
- If new items available, sync: `cd agent-room && node scripts/sync-knowledge.js --agent <agent_id> --all`
- Returns `KNOWLEDGE_OK` if nothing new

<!-- ==========================================================================
  PHASE 8: Mesh Health Check (every heartbeat, after shared context sync)
  Purpose: Verify all systems in the multi-agent mesh are online and within
           their free tier / budget limits.
========================================================================== -->

Mesh health check (every heartbeat, after shared context sync):
- Run `python3 mesh/health.py --json` to check all mesh systems
- If ANY system is OFFLINE:
  - Log to shared/MESH-STATUS.md with timestamp and error
  - If critical system (Claude Code, {{AGENT_NAME}}): escalate to P1
  - If non-critical: note in briefing, no escalation
- Check free tier limits:
  <!-- Customize these limits for your providers and plans -->
  - {{FREE_TIER_LIMITS}}
- If all systems healthy and within limits: `MESH_OK`
- Update shared/MESH-STATUS.md with latest health snapshot
- Run `python3 mesh/stats.py --daily --json` and include summary in daily digest

<!-- ==========================================================================
  PHASE 9: Mesh Capability Audit (once per week, Monday heartbeat)
  Purpose: Detect new tools/plugins installed on any system and update
           routing rules accordingly.
========================================================================== -->

Mesh capability audit (once per week, Monday heartbeat):
- Run `claude -p "List ALL tools" --max-turns 1 --output-format text` and compare to last known list
- Run `codex exec "List ALL tools" --sandbox read-only` and compare to last known list
- Check `cat ~/.codex/config.toml` for new plugins
- Check `cat ~/.claude/plugins/installed_plugins.json` for new plugins
- Compare against documented capabilities in active_guidance.md
- If ANY new tools/plugins found: update active_guidance.md AND routing decision tree immediately
- **RULE: Never assume a system can't do something. Verify first.**

<!-- ==========================================================================
  PHASE 10: Skill Graph Freshness (once per week, Monday heartbeat)
  Purpose: Ensure skill graph nodes haven't gone stale. Each node has a
           last_verified date and stale_after_days threshold.
========================================================================== -->

Skill graph freshness (once per week, Monday heartbeat):
- Scan YAML `last_verified` + `stale_after_days` across skill-graphs/*/
- Flag any nodes past their stale date
- Update nodes with fresh data if source files have changed

<!-- ==========================================================================
  References
  Point these at your own docs if you have extended heartbeat documentation.
========================================================================== -->

References:
- `{{WORKSPACE}}/docs/HEARTBEAT_FULL.md`
- `{{WORKSPACE}}/memory/LONGTERM_PROFILE.md`
