#!/usr/bin/env python3
"""
AI Mesh Usage Analytics — tracks routing decisions, costs, and performance.

Reads mesh/usage.json (routing decisions) and mesh/dispatch-log.json
(execution logs) to surface daily/weekly/monthly stats, cost breakdowns,
success rates, response times, and optimization recommendations.

Usage:
    python3 mesh/stats.py              # today's stats (default)
    python3 mesh/stats.py --weekly     # last 7 days
    python3 mesh/stats.py --monthly    # last 30 days
    python3 mesh/stats.py --all        # all time
    python3 mesh/stats.py --json       # machine-readable output
"""

from __future__ import annotations

import argparse
import json
import sys
from collections import defaultdict
from datetime import datetime, timedelta
from pathlib import Path
from typing import Any


# ---------------------------------------------------------------------------
# Paths
# ---------------------------------------------------------------------------

MESH_DIR = Path(__file__).resolve().parent
USAGE_FILE = MESH_DIR / "usage.json"
DISPATCH_FILE = MESH_DIR / "dispatch-log.json"


# ---------------------------------------------------------------------------
# Free-tier limits (used for recommendations)
# ---------------------------------------------------------------------------

FREE_TIER_LIMITS = {
    "gemini-flash": {"daily": 500, "label": "Gemini Flash"},
    "gemini-pro": {"daily": 25, "label": "Gemini Pro"},
    "perplexity": {"monthly_budget": 50.00, "label": "Perplexity API"},
}

# Systems that are subscription/free (cost $0 at point of use)
SUBSCRIPTION_SYSTEMS = {"claude-code", "codex", "openclaw"}
# Systems where specific models may be free-tier or paid
MIXED_SYSTEMS = {"gemini", "perplexity"}


# ---------------------------------------------------------------------------
# Data loading
# ---------------------------------------------------------------------------

def load_json(path: Path) -> list[dict]:
    """Load a JSON array from *path*, returning [] on missing/empty/corrupt files."""
    if not path.exists():
        return []
    try:
        text = path.read_text().strip()
        if not text:
            return []
        data = json.loads(text)
        if not isinstance(data, list):
            print(f"  Warning: {path.name} is not a JSON array — skipping.", file=sys.stderr)
            return []
        return data
    except json.JSONDecodeError as exc:
        print(f"  Warning: {path.name} has malformed JSON — {exc}", file=sys.stderr)
        return []


def parse_timestamp(raw: str) -> datetime | None:
    """Parse an ISO-8601-ish timestamp, returning None on failure."""
    if not raw:
        return None
    # Try fromisoformat first (handles timezone offsets like +00:00)
    try:
        dt = datetime.fromisoformat(raw)
        # Strip timezone for consistent naive comparisons
        return dt.replace(tzinfo=None)
    except (ValueError, TypeError):
        pass
    for fmt in ("%Y-%m-%dT%H:%M:%S", "%Y-%m-%dT%H:%M:%S.%f", "%Y-%m-%d %H:%M:%S"):
        try:
            return datetime.strptime(raw, fmt)
        except (ValueError, TypeError):
            continue
    return None


def parse_cost(raw: str) -> float:
    """Extract a dollar amount from a string like '$0.02' or '$0'."""
    if not raw:
        return 0.0
    cleaned = raw.strip().lstrip("$").strip()
    try:
        return float(cleaned)
    except (ValueError, TypeError):
        return 0.0


# ---------------------------------------------------------------------------
# Filtering
# ---------------------------------------------------------------------------

def filter_by_window(
    records: list[dict],
    window_start: datetime,
    window_end: datetime,
    ts_key: str = "timestamp",
) -> list[dict]:
    """Return records whose timestamp falls within [window_start, window_end]."""
    result = []
    for rec in records:
        ts = parse_timestamp(rec.get(ts_key, ""))
        if ts is None:
            continue
        if window_start <= ts <= window_end:
            result.append(rec)
    return result


def compute_window(mode: str) -> tuple[datetime, datetime, str]:
    """Return (start, end, label) for the requested time window."""
    now = datetime.now()
    today_start = now.replace(hour=0, minute=0, second=0, microsecond=0)
    today_end = now.replace(hour=23, minute=59, second=59, microsecond=999999)

    if mode == "weekly":
        start = today_start - timedelta(days=6)
        return start, today_end, f"Weekly: {start.strftime('%Y-%m-%d')} — {now.strftime('%Y-%m-%d')}"
    elif mode == "monthly":
        start = today_start - timedelta(days=29)
        return start, today_end, f"Monthly: {start.strftime('%Y-%m-%d')} — {now.strftime('%Y-%m-%d')}"
    elif mode == "all":
        return datetime.min, today_end, "All Time"
    else:  # daily
        return today_start, today_end, f"Daily: {now.strftime('%Y-%m-%d')}"


# ---------------------------------------------------------------------------
# Aggregation
# ---------------------------------------------------------------------------

def aggregate(
    usage: list[dict],
    dispatch: list[dict],
) -> dict[str, Any]:
    """Build a stats dict from filtered usage + dispatch records."""

    # --- System usage counts (from usage.json) ---
    system_counts: dict[str, int] = defaultdict(int)
    classification_counts: dict[str, int] = defaultdict(int)
    cost_free_count = 0
    cost_paid_count = 0
    cost_paid_total = 0.0

    for rec in usage:
        sys_name = rec.get("recommended", rec.get("routed_to", "unknown"))
        system_counts[sys_name] += 1
        cat = rec.get("classification", "unknown")
        classification_counts[cat] += 1

        cost = parse_cost(rec.get("cost_estimate", rec.get("cost", "$0")))
        if cost > 0:
            cost_paid_count += 1
            cost_paid_total += cost
        else:
            cost_free_count += 1

    total_routed = sum(system_counts.values())

    # --- Dispatch stats (from dispatch-log.json) ---
    dispatch_by_system: dict[str, list[dict]] = defaultdict(list)
    for rec in dispatch:
        sys_used = rec.get("system_used", rec.get("system_chosen", "unknown"))
        dispatch_by_system[sys_used].append(rec)

    system_stats: dict[str, dict[str, Any]] = {}
    for sys_name in sorted(set(list(system_counts.keys()) + list(dispatch_by_system.keys()))):
        dispatches = dispatch_by_system.get(sys_name, [])
        total = len(dispatches)
        successes = sum(1 for d in dispatches if d.get("success", False))
        durations = [
            d["duration_seconds"]
            for d in dispatches
            if isinstance(d.get("duration_seconds"), (int, float))
        ]
        avg_duration = sum(durations) / len(durations) if durations else 0.0
        failures = total - successes
        fallback_count = sum(1 for d in dispatches if d.get("fallback", False))

        system_stats[sys_name] = {
            "routed": system_counts.get(sys_name, 0),
            "dispatched": total,
            "successes": successes,
            "failures": failures,
            "fallbacks": fallback_count,
            "success_rate": (successes / total * 100) if total > 0 else 0.0,
            "avg_duration_s": round(avg_duration, 1),
        }

    # --- Free-tier tracking (approximate from dispatch log) ---
    now = datetime.now()
    today_start = now.replace(hour=0, minute=0, second=0, microsecond=0)
    month_start = now.replace(day=1, hour=0, minute=0, second=0, microsecond=0)

    gemini_flash_today = 0
    gemini_pro_today = 0
    perplexity_month_cost = 0.0

    for rec in dispatch:
        ts = parse_timestamp(rec.get("timestamp", ""))
        sys_used = rec.get("system_used", "")
        if ts and ts >= today_start:
            if sys_used == "gemini" or sys_used == "gemini-flash":
                gemini_flash_today += 1
            elif sys_used == "gemini-pro":
                gemini_pro_today += 1
        if ts and ts >= month_start:
            if sys_used in ("perplexity", "perplexity-api"):
                # Rough cost: use the cost_estimate from usage if available, else $0
                perplexity_month_cost += parse_cost(rec.get("cost_estimate", "$0"))

    # Also pull Perplexity costs from usage.json for the month
    for rec in usage:
        ts = parse_timestamp(rec.get("timestamp", ""))
        sys_name = rec.get("recommended", rec.get("routed_to", ""))
        if ts and ts >= month_start and sys_name in ("perplexity", "perplexity-api"):
            perplexity_month_cost += parse_cost(rec.get("cost_estimate", rec.get("cost", "$0")))

    free_tier = {
        "gemini_flash_today": gemini_flash_today,
        "gemini_pro_today": gemini_pro_today,
        "perplexity_month_cost": round(perplexity_month_cost, 2),
    }

    return {
        "total_routed": total_routed,
        "total_dispatched": sum(s["dispatched"] for s in system_stats.values()),
        "system_counts": dict(system_counts),
        "classification_counts": dict(classification_counts),
        "cost_free_count": cost_free_count,
        "cost_paid_count": cost_paid_count,
        "cost_paid_total": round(cost_paid_total, 4),
        "system_stats": system_stats,
        "free_tier": free_tier,
    }


# ---------------------------------------------------------------------------
# Recommendations engine
# ---------------------------------------------------------------------------

def build_recommendations(stats: dict[str, Any]) -> list[dict[str, str]]:
    """Generate actionable recommendations from the aggregated stats."""
    recs: list[dict[str, str]] = []
    total = stats["total_routed"]
    if total == 0:
        return recs

    # Cost efficiency
    free_pct = (stats["cost_free_count"] / total * 100) if total > 0 else 0
    if free_pct >= 80:
        recs.append({
            "icon": "ok",
            "msg": f"Cost efficiency: {free_pct:.0f}% of tasks used free/subscription systems",
        })
    elif free_pct >= 50:
        recs.append({
            "icon": "info",
            "msg": f"Cost efficiency: {free_pct:.0f}% free — consider routing more tasks to subscription systems",
        })
    else:
        recs.append({
            "icon": "warn",
            "msg": f"Cost efficiency: only {free_pct:.0f}% free — review routing rules to reduce API spend",
        })

    # Failure warnings
    for sys_name, ss in stats["system_stats"].items():
        if ss["failures"] > 0:
            recs.append({
                "icon": "warn",
                "msg": f"{sys_name} had {ss['failures']} failure(s) — check logs for details",
            })

    # Fallback warnings
    for sys_name, ss in stats["system_stats"].items():
        if ss["fallbacks"] > 0:
            recs.append({
                "icon": "info",
                "msg": f"{sys_name} used fallback routing {ss['fallbacks']} time(s)",
            })

    # Free-tier usage
    ft = stats["free_tier"]
    gl = FREE_TIER_LIMITS
    if ft["gemini_flash_today"] > 0:
        limit = gl["gemini-flash"]["daily"]
        pct = ft["gemini_flash_today"] / limit * 100
        icon = "warn" if pct > 80 else "ok"
        recs.append({
            "icon": icon,
            "msg": f"Gemini Flash free tier: {ft['gemini_flash_today']}/{limit} today ({pct:.0f}%)",
        })
    if ft["gemini_pro_today"] > 0:
        limit = gl["gemini-pro"]["daily"]
        pct = ft["gemini_pro_today"] / limit * 100
        icon = "warn" if pct > 80 else "ok"
        recs.append({
            "icon": icon,
            "msg": f"Gemini Pro free tier: {ft['gemini_pro_today']}/{limit} today ({pct:.0f}%)",
        })
    if ft["perplexity_month_cost"] > 0:
        budget = gl["perplexity"]["monthly_budget"]
        pct = ft["perplexity_month_cost"] / budget * 100
        icon = "warn" if pct > 80 else "ok"
        recs.append({
            "icon": icon,
            "msg": f"Perplexity API: ${ft['perplexity_month_cost']:.2f}/${budget:.2f} this month ({pct:.0f}%)",
        })

    # Slow systems
    for sys_name, ss in stats["system_stats"].items():
        if ss["avg_duration_s"] > 120 and ss["dispatched"] >= 3:
            recs.append({
                "icon": "info",
                "msg": f"{sys_name} averaging {ss['avg_duration_s']}s — consider simpler tasks or async dispatch",
            })

    return recs


# ---------------------------------------------------------------------------
# Rendering (human-readable)
# ---------------------------------------------------------------------------

ICONS = {"ok": "\u2713", "warn": "\u26a0", "info": "\u2139"}
BAR_WIDTH = 20


def render_bar(count: int, total: int) -> str:
    """Render a Unicode bar chart segment."""
    if total == 0:
        return "\u2591" * BAR_WIDTH
    filled = round(count / total * BAR_WIDTH)
    return "\u2588" * filled + "\u2591" * (BAR_WIDTH - filled)


def plural(n: int, word: str = "task") -> str:
    return f"{n} {word}" if n == 1 else f"{n} {word}s"


def render_text(stats: dict[str, Any], label: str) -> str:
    """Render a full human-readable stats report."""
    lines: list[str] = []

    lines.append(f"\u2550\u2550\u2550 AI Mesh Usage Stats ({label}) \u2550\u2550\u2550")
    lines.append("")

    total = stats["total_routed"]

    if total == 0 and stats["total_dispatched"] == 0:
        lines.append("No usage data found for this period.")
        lines.append("")
        lines.append("To start collecting data:")
        lines.append("  1. Route tasks:    python3 mesh/router.py 'your task description'")
        lines.append("  2. Dispatch tasks: python3 mesh/dispatch.py 'your task description'")
        lines.append("  3. Re-run stats:   python3 mesh/stats.py")
        lines.append("")
        lines.append(f"Data files checked:")
        lines.append(f"  {USAGE_FILE}")
        lines.append(f"  {DISPATCH_FILE}")
        return "\n".join(lines)

    # --- System Usage ---
    lines.append("System Usage:")
    sorted_systems = sorted(
        stats["system_counts"].items(), key=lambda kv: kv[1], reverse=True
    )
    max_name_len = max((len(s) for s, _ in sorted_systems), default=12)
    for sys_name, count in sorted_systems:
        pct = (count / total * 100) if total > 0 else 0
        bar = render_bar(count, total)
        padded = sys_name.ljust(max_name_len)
        lines.append(f"  {padded}  {bar}  {plural(count):>10s}  ({pct:.0f}%)")
    lines.append("")

    # --- Cost Breakdown ---
    lines.append("Cost Breakdown:")
    free_c = stats["cost_free_count"]
    paid_c = stats["cost_paid_count"]
    paid_t = stats["cost_paid_total"]
    total_cost = paid_t
    lines.append(f"  Subscription (free):  {plural(free_c):>10s} — $0.00")
    lines.append(f"  API (paid):           {plural(paid_c):>10s} — ${paid_t:.2f}")
    lines.append(f"  Total:                             ${total_cost:.2f}")
    lines.append("")

    # --- Success Rates ---
    lines.append("Success Rates:")
    for sys_name in sorted(stats["system_stats"].keys()):
        ss = stats["system_stats"][sys_name]
        if ss["dispatched"] == 0:
            continue
        rate = ss["success_rate"]
        padded = sys_name.ljust(max_name_len)
        ratio = f"({ss['successes']}/{ss['dispatched']})"
        avg = f"avg {ss['avg_duration_s']}s" if ss["avg_duration_s"] > 0 else ""
        lines.append(f"  {padded}  {rate:5.0f}% {ratio:>8s}  {avg}")
    lines.append("")

    # --- Free Tier Usage ---
    ft = stats["free_tier"]
    gl = FREE_TIER_LIMITS
    has_free_tier = any([
        ft["gemini_flash_today"],
        ft["gemini_pro_today"],
        ft["perplexity_month_cost"] > 0,
    ])
    if has_free_tier:
        lines.append("Free Tier Usage:")
        if ft["gemini_flash_today"] > 0:
            lines.append(
                f"  Gemini Flash:    {ft['gemini_flash_today']}/{gl['gemini-flash']['daily']} today"
            )
        if ft["gemini_pro_today"] > 0:
            lines.append(
                f"  Gemini Pro:      {ft['gemini_pro_today']}/{gl['gemini-pro']['daily']} today"
            )
        if ft["perplexity_month_cost"] > 0:
            lines.append(
                f"  Perplexity API:  ${ft['perplexity_month_cost']:.2f}"
                f"/${gl['perplexity']['monthly_budget']:.2f} this month"
            )
        lines.append("")

    # --- Recommendations ---
    recs = build_recommendations(stats)
    if recs:
        lines.append("Recommendations:")
        for r in recs:
            icon = ICONS.get(r["icon"], " ")
            lines.append(f"  {icon} {r['msg']}")
        lines.append("")

    return "\n".join(lines)


# ---------------------------------------------------------------------------
# JSON output
# ---------------------------------------------------------------------------

def render_json(stats: dict[str, Any], label: str) -> str:
    """Render machine-readable JSON output."""
    output = {
        "window": label,
        "generated_at": datetime.now().strftime("%Y-%m-%dT%H:%M:%S"),
        **stats,
        "recommendations": build_recommendations(stats),
    }
    return json.dumps(output, indent=2)


# ---------------------------------------------------------------------------
# CLI
# ---------------------------------------------------------------------------

def parse_args(argv: list[str] | None = None) -> argparse.Namespace:
    parser = argparse.ArgumentParser(
        description="AI Mesh usage analytics",
        formatter_class=argparse.RawDescriptionHelpFormatter,
        epilog=(
            "Examples:\n"
            "  python3 mesh/stats.py            # today\n"
            "  python3 mesh/stats.py --weekly    # last 7 days\n"
            "  python3 mesh/stats.py --monthly   # last 30 days\n"
            "  python3 mesh/stats.py --all       # all time\n"
            "  python3 mesh/stats.py --json      # JSON output\n"
        ),
    )
    window = parser.add_mutually_exclusive_group()
    window.add_argument("--daily", action="store_const", const="daily", dest="mode", help="Today's stats (default)")
    window.add_argument("--weekly", action="store_const", const="weekly", dest="mode", help="Last 7 days")
    window.add_argument("--monthly", action="store_const", const="monthly", dest="mode", help="Last 30 days")
    window.add_argument("--all", action="store_const", const="all", dest="mode", help="All time")
    parser.add_argument("--json", action="store_true", help="Machine-readable JSON output")
    parser.set_defaults(mode="daily")
    return parser.parse_args(argv)


def main(argv: list[str] | None = None) -> int:
    args = parse_args(argv)

    # Load raw data
    raw_usage = load_json(USAGE_FILE)
    raw_dispatch = load_json(DISPATCH_FILE)

    # Compute time window
    win_start, win_end, label = compute_window(args.mode)

    # Filter
    usage = filter_by_window(raw_usage, win_start, win_end)
    dispatch = filter_by_window(raw_dispatch, win_start, win_end)

    # Aggregate
    stats = aggregate(usage, dispatch)

    # Render
    if args.json:
        print(render_json(stats, label))
    else:
        print(render_text(stats, label))

    return 0


if __name__ == "__main__":
    raise SystemExit(main())
