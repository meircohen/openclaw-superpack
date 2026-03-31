#!/usr/bin/env python3
"""
Intercept Layer — Auto-called before heavy operations.

If a task would burn API tokens, suggests a cheaper path.
Returns recommendation + cost comparison.

Usage:
    python3 mesh/intercept.py 'expensive task description'
    python3 mesh/intercept.py --json 'task description'

Exit codes:
    0 — task is cheap, proceed as planned
    1 — error
    2 — task would be expensive, cheaper alternative suggested
"""

from __future__ import annotations

import argparse
import json
import os
import re
import sys
from pathlib import Path

MESH_DIR = Path(__file__).resolve().parent

# Estimated cost per 1K tokens for API-based systems
COST_PER_1K = {
    "openclaw": {"input": 0.003, "output": 0.015},
    "perplexity-api": {"input": 0.001, "output": 0.001},  # rough estimate
}

# Systems that cost $0 at point of use
FREE_SYSTEMS = {"claude-code", "codex", "gemini", "perplexity-browser", "perplexity-mcp"}

# Heavy operation indicators and estimated token counts
HEAVY_INDICATORS = {
    r"\b(entire codebase|full repo|all files|whole project)\b": 200_000,
    r"\b(500k|500K)\b": 500_000,
    r"\b(1m|1M|million token)\b": 1_000_000,
    r"\b(large file|huge file|massive)\b": 100_000,
    r"\b(deep research|comprehensive|thorough analysis)\b": 50_000,
    r"\b(batch|bulk|mass|all \d+)\b": 30_000,
    r"\b(full log|full transcript|entire document)\b": 100_000,
}

# Cheaper alternatives mapping
CHEAPER_ALTERNATIVES = {
    "openclaw": [
        ("claude-code", "$0 (subscription)", "Use Claude Code CLI instead — flat-rate subscription"),
        ("gemini", "$0 (free tier)", "Use Gemini CLI — free tier with 1M context"),
        ("codex", "$0 (subscription)", "Use Codex CLI — flat-rate subscription"),
    ],
    "perplexity-api": [
        ("perplexity-browser", "$0 (free)", "Use browser automation — free and unlimited"),
        ("perplexity-mcp", "$0 (subscription)", "Use Perplexity MCP via Claude Code — covered by subscription"),
        ("gemini", "$0 (free tier)", "Use Gemini with Google Search grounding — free tier"),
    ],
}


def estimate_tokens(task: str) -> int:
    """Estimate how many tokens a task might consume."""
    task_lower = task.lower()
    max_tokens = 5_000  # baseline

    for pattern, tokens in HEAVY_INDICATORS.items():
        if re.search(pattern, task_lower):
            max_tokens = max(max_tokens, tokens)

    return max_tokens


def estimate_cost(system: str, tokens: int) -> float:
    """Estimate dollar cost for a given system and token count."""
    rates = COST_PER_1K.get(system)
    if not rates:
        return 0.0
    # Assume roughly 40% input, 60% output for a typical task
    input_tokens = int(tokens * 0.4)
    output_tokens = int(tokens * 0.6)
    cost = (input_tokens / 1000 * rates["input"]) + (output_tokens / 1000 * rates["output"])
    return round(cost, 4)


def intercept(task: str, target_system: str | None = None) -> dict:
    """Check if a task would burn API tokens and suggest cheaper alternatives.

    Args:
        task: Task description
        target_system: The system that would handle this task (if known)

    Returns:
        Dict with recommendation, cost comparison, and whether to proceed.
    """
    # Import router to get routing decision if no target specified
    if target_system is None:
        try:
            sys.path.insert(0, str(MESH_DIR))
            from router import route
            result = route(task)
            target_system = result["recommended"]
        except ImportError:
            target_system = "claude-code"

    estimated_tokens = estimate_tokens(task)
    estimated_cost = estimate_cost(target_system, estimated_tokens)
    is_free = target_system in FREE_SYSTEMS or estimated_cost == 0.0

    result = {
        "task": task,
        "target_system": target_system,
        "estimated_tokens": estimated_tokens,
        "estimated_cost": f"${estimated_cost:.4f}",
        "is_free": is_free,
        "proceed": True,
        "recommendation": None,
        "alternatives": [],
    }

    if is_free:
        result["recommendation"] = f"Proceed — {target_system} is subscription/free ($0 marginal cost)"
        return result

    # Task would cost money — find cheaper alternatives
    alternatives = CHEAPER_ALTERNATIVES.get(target_system, [])
    alt_list = []
    for alt_sys, alt_cost, alt_reason in alternatives:
        alt_list.append({
            "system": alt_sys,
            "cost": alt_cost,
            "reason": alt_reason,
            "savings": f"${estimated_cost:.4f}",
        })

    if alt_list:
        result["proceed"] = False
        result["recommendation"] = (
            f"INTERCEPT: {target_system} would cost ~${estimated_cost:.4f} "
            f"for ~{estimated_tokens:,} tokens. "
            f"Cheaper alternative: {alt_list[0]['system']} ({alt_list[0]['cost']})"
        )
        result["alternatives"] = alt_list
    else:
        result["recommendation"] = (
            f"Warning: {target_system} estimated cost ~${estimated_cost:.4f} "
            f"for ~{estimated_tokens:,} tokens. No cheaper alternatives found."
        )

    return result


def format_human(result: dict) -> str:
    """Pretty human-readable output."""
    lines = []

    if result["is_free"]:
        lines.append(f"[intercept] CLEAR — {result['recommendation']}")
        return "\n".join(lines)

    lines.append(f"[intercept] WARNING — Expensive operation detected!")
    lines.append(f"  Task: {result['task']}")
    lines.append(f"  Target: {result['target_system']}")
    lines.append(f"  Est. tokens: {result['estimated_tokens']:,}")
    lines.append(f"  Est. cost: {result['estimated_cost']}")
    lines.append("")

    if result["alternatives"]:
        lines.append("  Cheaper alternatives:")
        for alt in result["alternatives"]:
            lines.append(f"    -> {alt['system']} ({alt['cost']}) — {alt['reason']}")
            lines.append(f"       Savings: {alt['savings']}")
        lines.append("")
        lines.append(f"  Recommendation: Use {result['alternatives'][0]['system']} instead")
    else:
        lines.append(f"  {result['recommendation']}")

    return "\n".join(lines)


def main() -> int:
    parser = argparse.ArgumentParser(
        description="Intercept layer — catch expensive operations before they run",
    )
    parser.add_argument("task", help="Task description to check")
    parser.add_argument("--system", help="Target system (auto-detected if not specified)")
    parser.add_argument("--json", action="store_true", dest="json_output", help="JSON output")
    args = parser.parse_args()

    result = intercept(args.task, args.system)

    if args.json_output:
        print(json.dumps(result, indent=2))
    else:
        print(format_human(result))

    # Exit 2 if we're recommending a cheaper path
    if not result["proceed"]:
        return 2
    return 0


if __name__ == "__main__":
    sys.exit(main())
