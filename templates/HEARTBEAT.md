# HEARTBEAT.md — Runtime Operations

Objective: run reliable, high-signal maintenance with minimal token usage.

Execution order: memory blocks check -> shared context sync -> provider health -> channel/cron health -> urgent calendar/email -> stale follow-ups.

Rules:
- Report only actionable items.
- Return `HEARTBEAT_OK` when no action is needed.

Memory blocks check (FIRST STEP - every heartbeat):
- Read `memory/blocks/active_guidance.md` for current priorities
- Check `memory/blocks/pending_items.md` for tasks awaiting action
- Use these as context for all heartbeat decisions

Shared context sync (every heartbeat, after memory blocks):
- Run `bash scripts/shabbat-times.sh check` — if "shabbat", suppress all non-P0 escalations
- Check `shared/escalations/` for any P0/P1 urgent items — act immediately
- Run `bash scripts/handoff.sh list pending` — pick up any handoffs
- Run `bash scripts/dispatch.sh check` — auto-dispatch pending handoffs
- Run `bash scripts/dispatch.sh verify` — check if dispatched runs completed
- Run `bash scripts/handoff.sh stale` — flag any handoffs pending >48 hours
- Check `shared/replies/` for completed tasks — deliver and archive
- Check `shared/notifications/` for pending notifications — deliver and archive

Session briefing refresh (every heartbeat):
- Run `bash scripts/generate-briefing.sh` to update shared/BRIEFING.md
- Check `shared/mcp-proxy/requests/` for pending proxy requests

Mesh health check (every heartbeat):
- Run `python3 mesh/health.py --json` to check all mesh systems
- If ANY system is OFFLINE: log to shared/MESH-STATUS.md
- If all systems healthy: `MESH_OK`
- Update shared/MESH-STATUS.md with latest health snapshot

Daily tasks (once per day, first heartbeat after 8am):
- Generate daily digest in `shared/digest/YYYY-MM-DD.md`
- Run memory maintenance (review yesterday's notes, update memory blocks)
- Run agent roster refresh (`bash scripts/discover-agents.sh`)
- Clean up resolved escalation files older than 7 days

Weekly tasks (Monday heartbeat):
- Mesh capability audit (check all system tool lists for changes)
- Skill graph freshness scan

References:
- See docs/ for detailed documentation on each subsystem
