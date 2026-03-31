#!/usr/bin/env python3
"""
AI Mesh Dispatch System — Unified task dispatcher with intelligent routing.

Routes tasks to the best available system in the mesh, with automatic
fallback if the primary system fails.

Usage:
    python3 mesh/dispatch.py 'build a REST API for watch inventory'
    python3 mesh/dispatch.py --dry-run 'research latest Bitcoin ETF flows'
    python3 mesh/dispatch.py --system gemini 'analyze this 500K token document'
    python3 mesh/dispatch.py --timeout 300 'deep reasoning about architecture'
"""

from __future__ import annotations

import argparse
import json
import os
import re
import subprocess
import sys
import time
import urllib.error
import urllib.request
from datetime import datetime, timezone
from pathlib import Path

# ---------------------------------------------------------------------------
# Constants
# ---------------------------------------------------------------------------

MESH_DIR = Path(__file__).resolve().parent
LOG_FILE = MESH_DIR / "dispatch-log.json"

CLI_PATHS = {
    "claude-code": "$HOME/.nvm/versions/node/v22.22.0/bin/claude",
    "codex": "$HOME/.nvm/versions/node/v22.22.0/bin/codex",
    "gemini": "$HOME/.nvm/versions/node/v22.22.0/bin/gemini",
}

PERPLEXITY_BROWSER_SCRIPT = Path(__file__).resolve().parent.parent / "scripts" / "perplexity_uc.py"

OPENCLAW_URL = "http://localhost:18789"

SYSTEM_NAMES = [
    "claude-code",
    "codex",
    "gemini",
    "openclaw",
    "perplexity-browser",
    "perplexity-mcp",
    "perplexity-api",
]

# Cost labels for display
COST_LABELS = {
    "claude-code": "$0 (subscription)",
    "codex": "$0 (subscription)",
    "gemini": "$0 (free tier)",
    "openclaw": "~$0.003/1K tokens",
    "perplexity-browser": "$0 (free)",
    "perplexity-mcp": "$0 (subscription)",
    "perplexity-api": "API credit ($50/mo pool)",
}

# ---------------------------------------------------------------------------
# Task Classification
# ---------------------------------------------------------------------------

# Keyword / pattern sets for classification (order matters for priority)
PATTERNS = {
    "coding": [
        r"\b(build|create|implement|code|write|develop|refactor|debug|fix bug|test|tdd)\b",
        r"\b(api|endpoint|function|class|module|component|service|script|cli)\b",
        r"\b(python|javascript|typescript|rust|go|java|swift|html|css|sql)\b",
        r"\b(git|commit|pr|pull request|merge|branch|deploy)\b",
        r"\b(file|edit|read|write|directory|path)\b",
    ],
    "research": [
        r"\b(research|search|find|look up|latest|news|current|today)\b",
        r"\b(what is|who is|how does|when did|where is)\b",
        r"\b(article|paper|report|study|source|citation)\b",
        r"\b(price|market|stock|crypto|bitcoin|etf|flow)\b",
        r"\b(trend|update|announcement)\b",
    ],
    "reasoning": [
        r"\b(analyze|reason|think|evaluate|compare|assess|critique)\b",
        r"\b(architecture|design|tradeoff|pros and cons|strategy)\b",
        r"\b(deep dive|thorough|comprehensive|step by step)\b",
        r"\b(proof|theorem|logic|mathematical)\b",
    ],
    "long_context": [
        r"\b\d+[kK]\b",  # any numeric size like 100K, 500K
        r"\b(500k|1m|million token|large document|huge file|long context)\b",
        r"\b(entire codebase|full repo|analyze all|token document|token file)\b",
    ],
    "multimodal": [
        r"\b(image|video|audio|photo|picture|screenshot|diagram)\b",
        r"\b(visual|multimodal|watch|listen|transcribe)\b",
    ],
    "quick": [
        r"\b(quick|fast|simple|status|ping|check|what time)\b",
    ],
    "background": [
        r"\b(monitor|cron|schedule|background|watch|poll|recurring)\b",
        r"\b(24.7|always on|daemon)\b",
    ],
    "mcp_action": [
        r"\b(email|gmail|slack|calendar|notion|send message)\b",
        r"\b(schedule meeting|create event|read inbox)\b",
    ],
}


def classify_task(task: str) -> str:
    """Classify a task into a category based on keyword matching.

    Returns one of: coding, research, reasoning, long_context, multimodal,
    quick, background, mcp_action.
    """
    task_lower = task.lower()
    scores: dict[str, int] = {}

    for category, patterns in PATTERNS.items():
        score = 0
        for pattern in patterns:
            if re.search(pattern, task_lower):
                score += 1
        if score > 0:
            scores[category] = score

    if not scores:
        return "coding"  # default — Claude Code handles most things well

    # Hard-constraint categories win ties: if long_context or multimodal
    # matched at all, they take priority since not all systems can handle them.
    priority_overrides = ["long_context", "multimodal", "background"]
    top_score = max(scores.values())
    tied = [cat for cat, s in scores.items() if s == top_score]
    if len(tied) > 1:
        for override in priority_overrides:
            if override in tied:
                return override

    return max(scores, key=scores.get)


# Routing tables: category -> ordered list of systems to try
ROUTING: dict[str, list[str]] = {
    "coding": ["claude-code", "gemini", "codex"],
    "research": ["perplexity-browser", "perplexity-mcp", "gemini", "perplexity-api"],
    "reasoning": ["codex", "gemini", "claude-code"],
    "long_context": ["gemini", "claude-code", "codex"],
    "multimodal": ["gemini", "openclaw", "claude-code"],
    "quick": ["openclaw", "gemini"],
    "background": ["openclaw"],
    "mcp_action": ["claude-code", "openclaw"],
}

CATEGORY_LABELS = {
    "coding": "coding task",
    "research": "research task",
    "reasoning": "reasoning task",
    "long_context": "long context task",
    "multimodal": "multimodal task",
    "quick": "quick answer",
    "background": "background task",
    "mcp_action": "MCP action",
}


def route_task(task: str) -> tuple[str, list[str]]:
    """Route a task to the best system.

    Returns (category, ordered_systems) where ordered_systems[0] is the
    primary pick and the rest are fallbacks.
    """
    category = classify_task(task)
    systems = ROUTING.get(category, ["claude-code"])
    return category, list(systems)


# ---------------------------------------------------------------------------
# Execution
# ---------------------------------------------------------------------------


def execute_on_system(system: str, task: str, timeout: int) -> tuple[bool, str, float]:
    """Execute a task on the given system.

    Returns (success, output, duration_seconds).
    """
    start = time.monotonic()

    try:
        if system == "claude-code":
            result = _run_cli(CLI_PATHS["claude-code"], ["-p", task, "--no-input"], timeout)
        elif system == "codex":
            result = _run_cli(CLI_PATHS["codex"], ["-q", task], timeout)
        elif system == "gemini":
            result = _run_cli(CLI_PATHS["gemini"], ["-p", task], timeout)
        elif system == "openclaw":
            result = _call_openclaw(task, timeout)
        elif system == "perplexity-browser":
            result = _run_perplexity_browser(task, timeout)
        elif system == "perplexity-mcp":
            return False, "perplexity-mcp is not directly callable from dispatch", time.monotonic() - start
        elif system == "perplexity-api":
            result = _call_perplexity_api(task, timeout)
        else:
            return False, f"Unknown system: {system}", time.monotonic() - start

        duration = time.monotonic() - start
        return result[0], result[1], duration

    except subprocess.TimeoutExpired:
        duration = time.monotonic() - start
        return False, f"timeout after {timeout}s", duration
    except FileNotFoundError as exc:
        duration = time.monotonic() - start
        return False, f"CLI not found: {exc}", duration
    except Exception as exc:
        duration = time.monotonic() - start
        return False, f"error: {exc}", duration


def _run_cli(cli_path: str, args: list[str], timeout: int) -> tuple[bool, str]:
    """Run a CLI tool and return (success, output)."""
    proc = subprocess.run(
        [cli_path] + args,
        capture_output=True,
        text=True,
        timeout=timeout,
        cwd=str(MESH_DIR.parent),
    )
    output = proc.stdout
    if proc.returncode != 0:
        output = proc.stdout + "\n" + proc.stderr if proc.stderr else proc.stdout
        return False, output.strip()
    return True, output.strip()


def _call_openclaw(task: str, timeout: int) -> tuple[bool, str]:
    """POST a task to the OpenClaw gateway."""
    payload = json.dumps({"task": task}).encode("utf-8")
    req = urllib.request.Request(
        OPENCLAW_URL,
        data=payload,
        headers={"Content-Type": "application/json"},
        method="POST",
    )
    try:
        with urllib.request.urlopen(req, timeout=timeout) as resp:
            body = resp.read().decode("utf-8")
            return True, body.strip()
    except urllib.error.URLError as exc:
        return False, f"OpenClaw unreachable: {exc.reason}"
    except Exception as exc:
        return False, f"OpenClaw error: {exc}"


def _run_perplexity_browser(task: str, timeout: int) -> tuple[bool, str]:
    """Run the Perplexity browser automation script."""
    proc = subprocess.run(
        ["python3", str(PERPLEXITY_BROWSER_SCRIPT), task],
        capture_output=True,
        text=True,
        timeout=timeout,
        cwd=str(MESH_DIR.parent),
    )
    output = proc.stdout
    if proc.returncode != 0:
        output = proc.stdout + "\n" + proc.stderr if proc.stderr else proc.stdout
        return False, output.strip()
    return True, output.strip()


def _call_perplexity_api(task: str, timeout: int) -> tuple[bool, str]:
    """Call the Perplexity API directly (uses PERPLEXITY_API_KEY env var)."""
    api_key = os.environ.get("PERPLEXITY_API_KEY")
    if not api_key:
        return False, "PERPLEXITY_API_KEY not set"

    payload = json.dumps({
        "model": "sonar",
        "messages": [{"role": "user", "content": task}],
    }).encode("utf-8")

    req = urllib.request.Request(
        "https://api.perplexity.ai/chat/completions",
        data=payload,
        headers={
            "Content-Type": "application/json",
            "Authorization": f"Bearer {api_key}",
        },
        method="POST",
    )

    try:
        with urllib.request.urlopen(req, timeout=timeout) as resp:
            body = json.loads(resp.read().decode("utf-8"))
            content = body.get("choices", [{}])[0].get("message", {}).get("content", "")
            return True, content.strip()
    except urllib.error.URLError as exc:
        return False, f"Perplexity API error: {exc.reason}"
    except Exception as exc:
        return False, f"Perplexity API error: {exc}"


# ---------------------------------------------------------------------------
# Logging
# ---------------------------------------------------------------------------


def log_execution(
    task: str,
    category: str,
    system_chosen: str,
    system_used: str,
    duration: float,
    success: bool,
    error: str | None = None,
) -> None:
    """Append an execution record to dispatch-log.json."""
    record = {
        "timestamp": datetime.now(timezone.utc).isoformat(),
        "task": task,
        "category": category,
        "system_chosen": system_chosen,
        "system_used": system_used,
        "duration_seconds": round(duration, 2),
        "success": success,
    }
    if error:
        record["error"] = error

    # Read existing log
    entries: list[dict] = []
    if LOG_FILE.exists():
        try:
            entries = json.loads(LOG_FILE.read_text())
        except (json.JSONDecodeError, OSError):
            entries = []

    entries.append(record)
    LOG_FILE.write_text(json.dumps(entries, indent=2) + "\n")


# ---------------------------------------------------------------------------
# Main
# ---------------------------------------------------------------------------


def main() -> int:
    parser = argparse.ArgumentParser(
        description="AI Mesh Dispatch — route tasks to the best system",
        usage="python3 mesh/dispatch.py [OPTIONS] 'task description'",
    )
    parser.add_argument("task", help="Task description to dispatch")
    parser.add_argument(
        "--dry-run",
        action="store_true",
        help="Show routing decision without executing",
    )
    parser.add_argument(
        "--system",
        choices=SYSTEM_NAMES,
        help="Force a specific system (override routing)",
    )
    parser.add_argument(
        "--timeout",
        type=int,
        default=120,
        help="Execution timeout in seconds (default: 120)",
    )
    args = parser.parse_args()

    task = args.task
    category, systems = route_task(task)
    category_label = CATEGORY_LABELS.get(category, category)

    # If --system is specified, use that system as the sole option
    if args.system:
        systems = [args.system]
        category_label = f"forced to {args.system}"

    primary = systems[0]
    cost = COST_LABELS.get(primary, "unknown")

    # Truncate task for display
    display_task = task if len(task) <= 60 else task[:57] + "..."
    print(f"[dispatch] Routing: '{display_task}' -> {primary} ({category_label}, {cost})")

    if args.dry_run:
        print(f"[dispatch] Dry run — would execute on: {primary}")
        if len(systems) > 1:
            print(f"[dispatch] Fallback chain: {' -> '.join(systems[1:])}")
        if primary == "perplexity-mcp":
            print("[dispatch] Note: perplexity-mcp is not directly callable from dispatch")
        return 0

    # Execute with fallback
    last_error = None
    for i, system in enumerate(systems):
        # Skip perplexity-mcp (not callable from dispatch)
        if system == "perplexity-mcp":
            print(f"[dispatch] Skipping {system} (not directly callable from dispatch)")
            continue

        is_fallback = i > 0
        if is_fallback:
            print(f"[dispatch] Falling back to {system}...")

        print(f"[dispatch] Executing on {system}...")

        success, output, duration = execute_on_system(system, task, args.timeout)

        if success:
            fallback_note = f" (fallback from {systems[0]})" if is_fallback else ""
            print(f"[dispatch] Completed in {duration:.1f}s{fallback_note}")
            print(f"[dispatch] Result logged to mesh/dispatch-log.json")

            log_execution(
                task=task,
                category=category,
                system_chosen=systems[0],
                system_used=system,
                duration=duration,
                success=True,
            )

            print("---")
            print(output)
            return 0
        else:
            print(f"[dispatch] Failed: {output}")
            last_error = output

    # All systems failed
    print(f"[dispatch] All systems failed. Last error: {last_error}")

    log_execution(
        task=task,
        category=category,
        system_chosen=systems[0],
        system_used=systems[-1],
        duration=0,
        success=False,
        error=last_error,
    )

    return 1


if __name__ == "__main__":
    sys.exit(main())
