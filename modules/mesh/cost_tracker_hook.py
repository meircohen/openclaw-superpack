#!/usr/bin/env python3
"""
Cost Tracker Hook — Python adaptation of ECC cost-tracker.js

Appends lightweight session usage metrics to ~/.openclaw/workspace/mesh/metrics/costs.jsonl.
Estimates API costs based on token usage for different Claude models.

Usage:
    # As a hook (reads JSON from stdin, passes through to stdout):
    echo '{"model":"sonnet","usage":{"input_tokens":1000,"output_tokens":500}}' | python cost_tracker_hook.py

    # As a library:
    from cost_tracker_hook import estimate_cost, log_usage
    cost = estimate_cost("sonnet", input_tokens=1000, output_tokens=500)
    log_usage(model="sonnet", input_tokens=1000, output_tokens=500)

Source: Adapted from github.com/affaan-m/everything-claude-code/scripts/hooks/cost-tracker.js
"""

import json
import os
import sys
from datetime import datetime, timezone
from pathlib import Path
from typing import Optional

# Per-1M-token rates (USD) — conservative defaults as of 2026-03
PRICING = {
    "haiku": {"input": 0.80, "output": 4.00},
    "sonnet": {"input": 3.00, "output": 15.00},
    "opus": {"input": 15.00, "output": 75.00},
}

METRICS_DIR = Path.home() / ".openclaw" / "workspace" / "mesh" / "metrics"
MAX_STDIN = 1024 * 1024  # 1 MB


def estimate_cost(
    model: str,
    input_tokens: int,
    output_tokens: int,
) -> float:
    """Estimate API cost in USD given model and token counts."""
    normalized = (model or "").lower()
    if "haiku" in normalized:
        rates = PRICING["haiku"]
    elif "opus" in normalized:
        rates = PRICING["opus"]
    else:
        rates = PRICING["sonnet"]

    cost = (input_tokens / 1_000_000) * rates["input"] + (output_tokens / 1_000_000) * rates["output"]
    return round(cost, 6)


def log_usage(
    model: str = "unknown",
    input_tokens: int = 0,
    output_tokens: int = 0,
    session_id: Optional[str] = None,
    metrics_dir: Optional[Path] = None,
) -> dict:
    """Log a usage record to costs.jsonl and return the record."""
    dest = metrics_dir or METRICS_DIR
    dest.mkdir(parents=True, exist_ok=True)

    row = {
        "timestamp": datetime.now(timezone.utc).isoformat(),
        "session_id": session_id or os.environ.get("CLAUDE_SESSION_ID", "default"),
        "model": model,
        "input_tokens": input_tokens,
        "output_tokens": output_tokens,
        "estimated_cost_usd": estimate_cost(model, input_tokens, output_tokens),
    }

    costs_file = dest / "costs.jsonl"
    with open(costs_file, "a") as f:
        f.write(json.dumps(row) + "\n")

    return row


def get_session_total(
    session_id: Optional[str] = None,
    metrics_dir: Optional[Path] = None,
) -> dict:
    """Sum costs for a session from the costs.jsonl file."""
    dest = metrics_dir or METRICS_DIR
    costs_file = dest / "costs.jsonl"
    if not costs_file.exists():
        return {"total_cost_usd": 0.0, "total_input_tokens": 0, "total_output_tokens": 0, "calls": 0}

    sid = session_id or os.environ.get("CLAUDE_SESSION_ID", "default")
    total_cost = 0.0
    total_in = 0
    total_out = 0
    calls = 0

    for line in costs_file.read_text().strip().split("\n"):
        if not line.strip():
            continue
        try:
            rec = json.loads(line)
            if rec.get("session_id") == sid:
                total_cost += rec.get("estimated_cost_usd", 0)
                total_in += rec.get("input_tokens", 0)
                total_out += rec.get("output_tokens", 0)
                calls += 1
        except json.JSONDecodeError:
            continue

    return {
        "total_cost_usd": round(total_cost, 4),
        "total_input_tokens": total_in,
        "total_output_tokens": total_out,
        "calls": calls,
    }


def get_daily_total(
    date_str: Optional[str] = None,
    metrics_dir: Optional[Path] = None,
) -> dict:
    """Sum costs for a specific date (YYYY-MM-DD) from the costs.jsonl file."""
    dest = metrics_dir or METRICS_DIR
    costs_file = dest / "costs.jsonl"
    if not costs_file.exists():
        return {"total_cost_usd": 0.0, "calls": 0, "date": date_str}

    target = date_str or datetime.now(timezone.utc).strftime("%Y-%m-%d")
    total_cost = 0.0
    calls = 0

    for line in costs_file.read_text().strip().split("\n"):
        if not line.strip():
            continue
        try:
            rec = json.loads(line)
            if rec.get("timestamp", "").startswith(target):
                total_cost += rec.get("estimated_cost_usd", 0)
                calls += 1
        except json.JSONDecodeError:
            continue

    return {"total_cost_usd": round(total_cost, 4), "calls": calls, "date": target}


def _safe_int(val) -> int:
    """Convert value to int, returning 0 for non-numeric."""
    try:
        n = int(val)
        return n if n >= 0 else 0
    except (TypeError, ValueError):
        return 0


def main():
    """Hook entry point — reads JSON from stdin, logs usage, passes through to stdout."""
    raw = sys.stdin.read(MAX_STDIN)

    try:
        data = json.loads(raw) if raw.strip() else {}
        usage = data.get("usage") or data.get("token_usage") or {}

        input_tokens = _safe_int(usage.get("input_tokens") or usage.get("prompt_tokens") or 0)
        output_tokens = _safe_int(usage.get("output_tokens") or usage.get("completion_tokens") or 0)
        model = str(data.get("model") or os.environ.get("CLAUDE_MODEL", "unknown"))

        log_usage(model=model, input_tokens=input_tokens, output_tokens=output_tokens)
    except Exception:
        pass  # Keep hook non-blocking

    sys.stdout.write(raw)


if __name__ == "__main__":
    main()
