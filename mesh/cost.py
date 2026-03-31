#!/usr/bin/env python3
"""
Cost Dashboard — Real-time cost tracking across the AI mesh.

Usage:
    python3 mesh/cost.py                    # Today's spend per system
    python3 mesh/cost.py --week             # Weekly view
    python3 mesh/cost.py --month            # Monthly view
    python3 mesh/cost.py --json             # Machine-readable output
    python3 mesh/cost.py --alert-threshold 5.00   # Alert if daily spend > $5
"""

from __future__ import annotations

import argparse
import json
import sys
from collections import defaultdict
from datetime import datetime, timedelta, timezone
from pathlib import Path

MESH_DIR = Path(__file__).resolve().parent
USAGE_FILE = MESH_DIR / "usage.json"
DISPATCH_FILE = MESH_DIR / "dispatch-log.json"
LEARNINGS_FILE = MESH_DIR / "learnings.json"

# Cost estimates per system per task (rough averages)
COST_MODEL = {
    "claude-code": 0.0,       # subscription
    "codex": 0.0,             # subscription
    "gemini": 0.0,            # free tier
    "gemini-flash": 0.0,      # free tier
    "gemini-pro": 0.0,        # free tier
    "gemini-cli": 0.0,        # free tier
    "gemini-search": 0.0,     # free tier
    "gemini-pro-thinking": 0.0, # free tier
    "openclaw": 0.05,         # ~$0.05 per typical task (API tokens)
    "perplexity-browser": 0.0, # free
    "perplexity-mcp": 0.0,     # subscription
    "perplexity-mcp-claude": 0.0,
    "perplexity-mcp-codex": 0.0,
    "perplexity-api": 0.10,    # ~$0.10 per API call from credit
    "codex-gpt5.4-xhigh": 0.0, # subscription
}

# Default alert thresholds
DEFAULT_DAILY_THRESHOLD = 5.00
DEFAULT_WEEKLY_THRESHOLD = 20.00

def load_json(path: Path) -> list[dict]:
    if not path.exists():
        return []
    try:
        data = json.loads(path.read_text().strip() or "[]")
        return data if isinstance(data, list) else []
    except (json.JSONDecodeError, OSError):
        return []


def parse_ts(raw: str) -> datetime | None:
    if not raw:
        return None
    try:
        dt = datetime.fromisoformat(raw)
        return dt.replace(tzinfo=None)
    except (ValueError, TypeError):
        return None


def filter_records(records: list[dict], start: datetime, end: datetime) -> list[dict]:
    result = []
    for rec in records:
        ts = parse_ts(rec.get("timestamp", ""))
        if ts and start <= ts <= end:
            result.append(rec)
    return result


def estimate_cost_for_record(rec: dict) -> float:
    """Estimate cost for a single record."""
    # Check if learnings has actual cost
    cost_val = rec.get("cost", "")
    if isinstance(cost_val, (int, float)):
        return float(cost_val)

    # Try to parse cost string
    if isinstance(cost_val, str):
        cleaned = cost_val.strip().lstrip("$~").strip()
        try:
            val = float(cleaned.split()[0].rstrip(","))
            if val > 0:
                return val
        except (ValueError, IndexError):
            pass

    # Fall back to model estimate
    system = rec.get("routed_to", rec.get("system_used", rec.get("system", "")))
    return COST_MODEL.get(system, 0.0)


def compute_costs(period: str) -> dict:
    """Compute cost breakdown for the given period."""
    now = datetime.now()
    today_start = now.replace(hour=0, minute=0, second=0, microsecond=0)

    if period == "week":
        start = today_start - timedelta(days=6)
        label = f"Weekly: {start.strftime('%Y-%m-%d')} - {now.strftime('%Y-%m-%d')}"
    elif period == "month":
        start = today_start - timedelta(days=29)
        label = f"Monthly: {start.strftime('%Y-%m-%d')} - {now.strftime('%Y-%m-%d')}"
    else:  # today
        start = today_start
        label = f"Today: {now.strftime('%Y-%m-%d')}"

    end = now.replace(hour=23, minute=59, second=59)

    # Load all data sources
    usage = filter_records(load_json(USAGE_FILE), start, end)
    dispatch = filter_records(load_json(DISPATCH_FILE), start, end)
    learnings = filter_records(load_json(LEARNINGS_FILE), start, end)

    # Combine all records
    all_records = usage + dispatch + learnings

    # Aggregate by system
    by_system: dict[str, dict] = defaultdict(lambda: {"count": 0, "cost": 0.0})
    total_cost = 0.0

    for rec in all_records:
        system = rec.get("routed_to", rec.get("system_used", rec.get("system", "unknown")))
        cost = estimate_cost_for_record(rec)
        by_system[system]["count"] += 1
        by_system[system]["cost"] += cost
        total_cost += cost

    # Daily breakdown (for week/month views)
    daily: dict[str, float] = defaultdict(float)
    if period in ("week", "month"):
        for rec in all_records:
            ts = parse_ts(rec.get("timestamp", ""))
            if ts:
                day_key = ts.strftime("%Y-%m-%d")
                daily[day_key] += estimate_cost_for_record(rec)

    # Check alerts
    alerts = []
    today_cost = sum(
        estimate_cost_for_record(r) for r in all_records
        if parse_ts(r.get("timestamp", "")) and parse_ts(r.get("timestamp", "")) >= today_start
    )
    if today_cost > DEFAULT_DAILY_THRESHOLD:
        alerts.append(f"Daily spend ${today_cost:.2f} exceeds threshold ${DEFAULT_DAILY_THRESHOLD:.2f}")

    if period == "week":
        week_cost = total_cost
        if week_cost > DEFAULT_WEEKLY_THRESHOLD:
            alerts.append(f"Weekly spend ${week_cost:.2f} exceeds threshold ${DEFAULT_WEEKLY_THRESHOLD:.2f}")

    # Spike detection: check if today's cost is >3x the average daily cost
    if period in ("week", "month") and daily:
        avg_daily = sum(daily.values()) / len(daily)
        if avg_daily > 0 and today_cost > avg_daily * 3:
            alerts.append(
                f"Spike detected: today ${today_cost:.2f} is {today_cost/avg_daily:.1f}x "
                f"the average daily spend ${avg_daily:.2f}"
            )

    return {
        "label": label,
        "period": period,
        "total_cost": round(total_cost, 4),
        "total_tasks": len(all_records),
        "by_system": {k: {"count": v["count"], "cost": round(v["cost"], 4)} for k, v in sorted(by_system.items())},
        "daily_breakdown": {k: round(v, 4) for k, v in sorted(daily.items())} if daily else None,
        "alerts": alerts,
        "generated_at": now.isoformat(),
    }


def format_human(costs: dict) -> str:
    """Pretty human-readable cost report."""
    lines = [
        f"=== AI Mesh Cost Dashboard ===",
        f"{costs['label']}",
        "",
        f"Total: ${costs['total_cost']:.2f} across {costs['total_tasks']} tasks",
        "",
        "Per System:",
    ]

    max_name = max((len(k) for k in costs["by_system"]), default=10)
    for sys_name, data in costs["by_system"].items():
        cost_str = f"${data['cost']:.4f}" if data["cost"] > 0 else "$0.00"
        marker = " *" if data["cost"] > 0 else ""
        lines.append(f"  {sys_name:<{max_name}}  {data['count']:>4} tasks  {cost_str:>10}{marker}")

    if costs.get("daily_breakdown"):
        lines.append("")
        lines.append("Daily Breakdown:")
        for day, cost in costs["daily_breakdown"].items():
            bar_len = min(40, int(cost * 20)) if cost > 0 else 0
            bar = "\u2588" * bar_len if bar_len > 0 else "\u2591"
            lines.append(f"  {day}  ${cost:.4f}  {bar}")

    if costs["alerts"]:
        lines.append("")
        lines.append("ALERTS:")
        for alert in costs["alerts"]:
            lines.append(f"  \u26a0 {alert}")

    lines.append("")
    lines.append("* = costs money (API tokens)")
    return "\n".join(lines)


def weekly_cost_summary() -> str:
    """Generate a brief weekly cost summary for heartbeat digest."""
    costs = compute_costs("week")
    paid = {k: v for k, v in costs["by_system"].items() if v["cost"] > 0}

    if not paid:
        return f"Weekly mesh cost: $0.00 ({costs['total_tasks']} tasks, all free/subscription)"

    paid_str = ", ".join(f"{k}: ${v['cost']:.2f}" for k, v in paid.items())
    return f"Weekly mesh cost: ${costs['total_cost']:.2f} ({costs['total_tasks']} tasks) — Paid: {paid_str}"


def main() -> int:
    parser = argparse.ArgumentParser(description="AI Mesh Cost Dashboard")
    window = parser.add_mutually_exclusive_group()
    window.add_argument("--today", action="store_const", const="today", dest="period", help="Today's costs (default)")
    window.add_argument("--week", action="store_const", const="week", dest="period", help="Weekly view")
    window.add_argument("--month", action="store_const", const="month", dest="period", help="Monthly view")
    parser.add_argument("--json", action="store_true", dest="json_output", help="JSON output")
    parser.add_argument("--alert-threshold", type=float, help="Daily alert threshold in USD")
    parser.add_argument("--weekly-summary", action="store_true", help="One-line summary for heartbeat")
    parser.set_defaults(period="today")
    args = parser.parse_args()

    if args.alert_threshold:
        global DEFAULT_DAILY_THRESHOLD
        DEFAULT_DAILY_THRESHOLD = args.alert_threshold

    if args.weekly_summary:
        print(weekly_cost_summary())
        return 0

    costs = compute_costs(args.period)

    if args.json_output:
        print(json.dumps(costs, indent=2))
    else:
        print(format_human(costs))

    return 0


if __name__ == "__main__":
    sys.exit(main())
