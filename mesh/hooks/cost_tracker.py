#!/usr/bin/env python3
"""
Cost Tracker Hook
Adapted from ECC cost-tracker.js

Appends lightweight session usage metrics to ~/.openclaw/workspace/mesh/metrics/costs.jsonl.
Estimates costs based on per-model token pricing.
"""

import json
import os
from datetime import datetime
from pathlib import Path
from typing import Any, Dict, Optional

# Per-1M-token pricing (input, output)
MODEL_PRICING = {
    "haiku": {"input": 0.25, "output": 1.25},
    "sonnet": {"input": 3.0, "output": 15.0},
    "opus": {"input": 15.0, "output": 75.0},
}

METRICS_DIR = Path.home() / ".openclaw" / "workspace" / "mesh" / "metrics"


def _to_number(value: Any) -> int:
    """Safely convert a value to a non-negative integer."""
    try:
        n = int(value)
        return n if n >= 0 else 0
    except (TypeError, ValueError):
        return 0


def _detect_model_tier(model_name: str) -> str:
    """Detect model tier from model name string."""
    normalized = str(model_name).lower()
    if "haiku" in normalized:
        return "haiku"
    if "opus" in normalized:
        return "opus"
    return "sonnet"  # default


def estimate_cost(model: str, input_tokens: int, output_tokens: int) -> float:
    """Estimate cost in USD for a given model and token counts."""
    tier = _detect_model_tier(model)
    rates = MODEL_PRICING.get(tier, MODEL_PRICING["sonnet"])
    cost = (input_tokens / 1_000_000) * rates["input"] + (output_tokens / 1_000_000) * rates["output"]
    return round(cost, 6)


def track_cost(
    model: str = "unknown",
    input_tokens: int = 0,
    output_tokens: int = 0,
    session_id: str = "default",
    usage: Optional[Dict[str, Any]] = None,
) -> Dict[str, Any]:
    """
    Track token usage by appending a JSONL row to the costs file.

    Can be called with explicit parameters or with a usage dict that
    may contain input_tokens/prompt_tokens and output_tokens/completion_tokens.

    Returns the row that was written.
    """
    if usage is not None:
        input_tokens = _to_number(
            usage.get("input_tokens", usage.get("prompt_tokens", input_tokens))
        )
        output_tokens = _to_number(
            usage.get("output_tokens", usage.get("completion_tokens", output_tokens))
        )

    row = {
        "timestamp": datetime.now().isoformat(),
        "session_id": session_id,
        "model": model,
        "input_tokens": input_tokens,
        "output_tokens": output_tokens,
        "estimated_cost_usd": estimate_cost(model, input_tokens, output_tokens),
    }

    try:
        METRICS_DIR.mkdir(parents=True, exist_ok=True)
        costs_file = METRICS_DIR / "costs.jsonl"
        with open(costs_file, "a") as f:
            f.write(json.dumps(row) + "\n")
    except OSError:
        # Keep hook non-blocking
        pass

    return row


def get_session_total(session_id: str = "default") -> Dict[str, Any]:
    """Read all cost rows for a session and return totals."""
    costs_file = METRICS_DIR / "costs.jsonl"
    total_input = 0
    total_output = 0
    total_cost = 0.0
    count = 0

    if costs_file.exists():
        try:
            with open(costs_file) as f:
                for line in f:
                    line = line.strip()
                    if not line:
                        continue
                    try:
                        row = json.loads(line)
                        if row.get("session_id") == session_id:
                            total_input += row.get("input_tokens", 0)
                            total_output += row.get("output_tokens", 0)
                            total_cost += row.get("estimated_cost_usd", 0.0)
                            count += 1
                    except json.JSONDecodeError:
                        continue
        except OSError:
            pass

    return {
        "session_id": session_id,
        "total_input_tokens": total_input,
        "total_output_tokens": total_output,
        "total_estimated_cost_usd": round(total_cost, 6),
        "request_count": count,
    }


if __name__ == "__main__":
    import sys

    # Read JSON from stdin for CLI usage
    raw = sys.stdin.read(1024 * 1024)
    try:
        data = json.loads(raw) if raw.strip() else {}
        usage = data.get("usage", data.get("token_usage", {}))
        model = str(data.get("model", os.environ.get("CLAUDE_MODEL", "unknown")))
        sid = os.environ.get("CLAUDE_SESSION_ID", "default")
        row = track_cost(model=model, session_id=sid, usage=usage)
        print(json.dumps(row))
    except Exception:
        pass
