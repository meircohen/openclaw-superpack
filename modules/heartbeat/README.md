# Heartbeat Module

The heartbeat is a recurring maintenance loop that your orchestrator agent runs on a schedule (typically every 15-30 minutes). It keeps your multi-agent system healthy, coordinated, and informed.

## What It Does

The heartbeat executes a fixed sequence of phases on each run:

1. **Memory Blocks Check** -- Load current priorities and pending items so every decision is context-aware.
2. **Shared Context Sync** -- Process cross-system handoffs, dispatch work to other agents, clean up inboxes, and enforce quiet periods (e.g., Shabbat suppression).
3. **Session Briefing Refresh** -- Generate single-file context documents that other agents read at startup. This is how agents stay current without reading dozens of files.
4. **Daily Digest Generation** (once/day) -- Summarize 24h of activity, pending work, blocked items, and stale handoffs.
5. **Memory Maintenance** (once/day) -- Consolidate learnings, update memory blocks, verify task lists.
6. **Agent Roster Refresh** (once/day) -- Discover new specialist agents, read their capabilities, update routing awareness.
7. **Knowledge Sharing** (once/day) -- Sync shared knowledge across agents via a knowledge bus.
8. **Mesh Health Check** -- Verify all systems are online and within budget/rate limits.
9. **Mesh Capability Audit** (weekly) -- Detect new tools/plugins on any system and update routing rules.
10. **Skill Graph Freshness** (weekly) -- Flag stale skill graph nodes.

## Key Signals

- `HEARTBEAT_OK` -- Nothing actionable; all systems nominal.
- `MESH_OK` -- All mesh systems healthy and within limits.
- `KNOWLEDGE_OK` -- No new shared knowledge to sync.

## Files

- `HEARTBEAT-TEMPLATE.md` -- The template you customize for your setup. Contains `{{PLACEHOLDER}}` markers and comments explaining each section.

## Setup

1. Copy `HEARTBEAT-TEMPLATE.md` to your workspace root as `HEARTBEAT.md`.
2. Replace all `{{PLACEHOLDER}}` values with your actual configuration:
   - `{{WORKSPACE}}` -- Your workspace path (e.g., `$HOME/.openclaw/workspace`)
   - `{{AGENT_NAME}}` -- Your orchestrator agent's name
   - `{{TIMEZONE}}` -- Your timezone
   - `{{PROTECTED_CONTACT}}` -- Person who must never receive auto-messages
   - `{{LOCATION}}` -- Your city/region
   - `{{SHABBAT_ZIP}}` -- ZIP for Shabbat times (or remove the section)
   - `{{FREE_TIER_LIMITS}}` -- Your per-provider API limits
3. Remove any phases that don't apply to your setup (e.g., knowledge sharing if you don't use agent-room).
4. Configure your orchestrator to read and execute this file on a schedule.

## Design Principles

- **Minimal token usage** -- Report only actionable items. Skip phases that return OK.
- **Execution order matters** -- Memory loads first so everything else is context-aware. Shared context syncs before briefing generation so briefings reflect the latest state.
- **Daily vs. per-heartbeat** -- Some phases (digest, memory maintenance, roster refresh) only run once per day on the first heartbeat after 8am. This saves tokens and avoids redundant work.
- **Escalation protocol** -- P0 items always escalate. P1 only on weekdays. Lower priority items wait for the daily digest.
