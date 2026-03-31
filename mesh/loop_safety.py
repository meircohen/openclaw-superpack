#!/usr/bin/env python3
"""
Autonomous Loop Safety Manager for AI Mesh
Adapted from ECC loop-operator agent.

Manages autonomous loops with:
- Explicit stop conditions
- Checkpoint-based progress tracking
- Stall detection and escalation
- Cost drift monitoring
- Retry storm prevention

Usage:
    python3 mesh/loop_safety.py start --pattern sequential --task "Process all PRs"
    python3 mesh/loop_safety.py status
    python3 mesh/loop_safety.py checkpoint --name "batch-1-done"
    python3 mesh/loop_safety.py stop --reason "completed"
    python3 mesh/loop_safety.py history
"""

import argparse
import json
import os
import sys
import time
from datetime import datetime, timedelta
from typing import Any, Dict, List, Optional

MESH_DIR = os.path.dirname(os.path.abspath(__file__))
LOOP_STATE_FILE = os.path.join(MESH_DIR, "loop-state.json")
LOOP_HISTORY_FILE = os.path.join(MESH_DIR, "loop-history.json")

# Loop patterns
PATTERNS = {
    "sequential": {
        "description": "Process items one at a time, checkpoint after each",
        "max_iterations": 50,
        "checkpoint_every": 1,
    },
    "continuous-pr": {
        "description": "Continuously process PRs/issues until queue empty",
        "max_iterations": 20,
        "checkpoint_every": 1,
    },
    "batch": {
        "description": "Process items in batches, checkpoint per batch",
        "max_iterations": 10,
        "checkpoint_every": 1,
    },
    "monitoring": {
        "description": "Periodic health/status checks",
        "max_iterations": 100,
        "checkpoint_every": 5,
    },
}

# Escalation thresholds
MAX_CONSECUTIVE_FAILURES = 3
MAX_STALL_CHECKPOINTS = 2
COST_DRIFT_MULTIPLIER = 3.0  # Alert if cost >3x average
DEFAULT_BUDGET_LIMIT = 5.0  # $5 per loop run


def load_state():
    # type: () -> Optional[Dict]
    """Load current loop state."""
    if not os.path.exists(LOOP_STATE_FILE):
        return None
    try:
        with open(LOOP_STATE_FILE) as f:
            return json.load(f)
    except (json.JSONDecodeError, IOError):
        return None


def save_state(state):
    # type: (Dict) -> None
    """Persist loop state."""
    with open(LOOP_STATE_FILE, "w") as f:
        json.dump(state, f, indent=2)


def clear_state():
    if os.path.exists(LOOP_STATE_FILE):
        os.remove(LOOP_STATE_FILE)


def load_history():
    # type: () -> List[Dict]
    if not os.path.exists(LOOP_HISTORY_FILE):
        return []
    try:
        with open(LOOP_HISTORY_FILE) as f:
            return json.load(f)
    except (json.JSONDecodeError, IOError):
        return []


def save_history(history):
    # type: (List[Dict]) -> None
    # Keep last 50
    history = history[-50:]
    with open(LOOP_HISTORY_FILE, "w") as f:
        json.dump(history, f, indent=2)


def start_loop(pattern, task, system="claude-code", budget=None, mode="safe"):
    # type: (str, str, str, Optional[float], str) -> Dict
    """Initialize a new loop run."""
    existing = load_state()
    if existing and existing.get("status") == "running":
        print("ERROR: Loop already running (started {})".format(existing.get("started_at", "?")))
        print("Use 'stop' to end it first, or 'status' to check.")
        sys.exit(1)

    if pattern not in PATTERNS:
        print("ERROR: Unknown pattern '{}'. Available: {}".format(
            pattern, ", ".join(PATTERNS.keys())))
        sys.exit(1)

    pat = PATTERNS[pattern]
    state = {
        "status": "running",
        "pattern": pattern,
        "task": task,
        "system": system,
        "mode": mode,  # "safe" or "fast"
        "started_at": datetime.now().isoformat(),
        "iteration": 0,
        "max_iterations": pat["max_iterations"],
        "checkpoint_every": pat["checkpoint_every"],
        "budget_limit": budget or DEFAULT_BUDGET_LIMIT,
        "estimated_cost": 0.0,
        "checkpoints": [],
        "failures": [],
        "consecutive_failures": 0,
        "stall_count": 0,
        "last_progress_checkpoint": 0,
    }

    save_state(state)
    print("\nLoop started:")
    print("  Pattern:    {} — {}".format(pattern, pat["description"]))
    print("  Task:       {}".format(task))
    print("  System:     {}".format(system))
    print("  Mode:       {} (max {} iterations)".format(mode, pat["max_iterations"]))
    print("  Budget:     ${:.2f}".format(state["budget_limit"]))
    print("")
    return state


def add_checkpoint(name, success=True, cost=0.0, notes=""):
    # type: (str, bool, float, str) -> Dict
    """Record a checkpoint in the loop."""
    state = load_state()
    if not state or state.get("status") != "running":
        print("ERROR: No active loop.")
        sys.exit(1)

    state["iteration"] += 1
    state["estimated_cost"] += cost

    checkpoint = {
        "name": name,
        "iteration": state["iteration"],
        "timestamp": datetime.now().isoformat(),
        "success": success,
        "cost": cost,
        "notes": notes,
    }
    state["checkpoints"].append(checkpoint)

    # Track failures
    if not success:
        state["consecutive_failures"] += 1
        state["failures"].append({
            "iteration": state["iteration"],
            "name": name,
            "notes": notes,
        })
    else:
        state["consecutive_failures"] = 0
        state["last_progress_checkpoint"] = state["iteration"]

    # Check escalation conditions
    alerts = check_escalations(state)

    save_state(state)

    icon = "+" if success else "X"
    print("  [{}] Checkpoint #{}: {} {}".format(
        icon, state["iteration"], name,
        "(${:.3f})".format(cost) if cost > 0 else ""))
    if notes:
        print("      {}".format(notes))

    for alert in alerts:
        print("  !! ALERT: {}".format(alert))

    return state


def check_escalations(state):
    # type: (Dict) -> List[str]
    """Check for conditions that should trigger escalation."""
    alerts = []

    # Retry storm: too many consecutive failures
    if state["consecutive_failures"] >= MAX_CONSECUTIVE_FAILURES:
        alerts.append(
            "RETRY STORM: {} consecutive failures. Loop should be paused.".format(
                state["consecutive_failures"]))
        state["status"] = "paused"
        state["pause_reason"] = "retry_storm"

    # Stall: no progress for too long
    stall_gap = state["iteration"] - state["last_progress_checkpoint"]
    if stall_gap >= MAX_STALL_CHECKPOINTS and state["iteration"] > MAX_STALL_CHECKPOINTS:
        alerts.append(
            "STALL DETECTED: No progress for {} checkpoints.".format(stall_gap))
        state["stall_count"] += 1
        if state["stall_count"] >= 2:
            state["status"] = "paused"
            state["pause_reason"] = "stall"

    # Cost drift
    if state["estimated_cost"] > state["budget_limit"]:
        alerts.append(
            "BUDGET EXCEEDED: ${:.2f} > ${:.2f} limit.".format(
                state["estimated_cost"], state["budget_limit"]))
        state["status"] = "paused"
        state["pause_reason"] = "budget_exceeded"

    # Cost per checkpoint spike
    checkpoints = state.get("checkpoints", [])
    if len(checkpoints) >= 3:
        costs = [c.get("cost", 0) for c in checkpoints]
        avg_cost = sum(costs[:-1]) / len(costs[:-1]) if len(costs) > 1 else 0
        latest_cost = costs[-1]
        if avg_cost > 0 and latest_cost > avg_cost * COST_DRIFT_MULTIPLIER:
            alerts.append(
                "COST SPIKE: ${:.3f} is {:.1f}x the average ${:.3f}.".format(
                    latest_cost, latest_cost / avg_cost, avg_cost))

    # Max iterations
    if state["iteration"] >= state["max_iterations"]:
        alerts.append("MAX ITERATIONS reached ({}).".format(state["max_iterations"]))
        state["status"] = "completed"
        state["stop_reason"] = "max_iterations"

    return alerts


def get_status():
    # type: () -> None
    """Print current loop status."""
    state = load_state()
    if not state:
        print("No active or recent loop.")
        return

    print("\n" + "=" * 50)
    print("LOOP STATUS")
    print("=" * 50)
    print("  Status:     {}".format(state.get("status", "?")))
    print("  Pattern:    {}".format(state.get("pattern", "?")))
    print("  Task:       {}".format(state.get("task", "?")))
    print("  System:     {}".format(state.get("system", "?")))
    print("  Started:    {}".format(state.get("started_at", "?")))
    print("  Iteration:  {} / {}".format(
        state.get("iteration", 0), state.get("max_iterations", "?")))
    print("  Cost:       ${:.3f} / ${:.2f}".format(
        state.get("estimated_cost", 0), state.get("budget_limit", 0)))

    checkpoints = state.get("checkpoints", [])
    if checkpoints:
        passed = sum(1 for c in checkpoints if c.get("success"))
        failed = len(checkpoints) - passed
        print("  Checkpoints: {} passed, {} failed".format(passed, failed))

        last = checkpoints[-1]
        print("  Last:       {} ({})".format(
            last.get("name", "?"),
            "PASS" if last.get("success") else "FAIL"))

    if state.get("pause_reason"):
        print("  PAUSED:     {}".format(state["pause_reason"]))

    failures = state.get("failures", [])
    if failures:
        print("\n  Recent Failures:")
        for f in failures[-3:]:
            print("    #{}: {} — {}".format(
                f.get("iteration"), f.get("name"), f.get("notes", "")))

    # Recommendation
    status = state.get("status", "")
    if status == "running":
        consec = state.get("consecutive_failures", 0)
        if consec > 0:
            print("\n  Recommendation: CAUTION ({} consecutive failures)".format(consec))
        else:
            print("\n  Recommendation: CONTINUE")
    elif status == "paused":
        print("\n  Recommendation: INVESTIGATE ({})".format(state.get("pause_reason", "?")))
    elif status == "completed":
        print("\n  Recommendation: REVIEW RESULTS")

    print("=" * 50 + "\n")


def stop_loop(reason="manual"):
    # type: (str) -> None
    """Stop the current loop and archive to history."""
    state = load_state()
    if not state:
        print("No active loop to stop.")
        return

    state["status"] = "stopped"
    state["stop_reason"] = reason
    state["stopped_at"] = datetime.now().isoformat()

    # Calculate duration
    try:
        started = datetime.fromisoformat(state["started_at"])
        duration = (datetime.now() - started).total_seconds()
        state["duration_s"] = round(duration, 1)
    except (KeyError, ValueError):
        state["duration_s"] = 0

    # Archive to history
    history = load_history()
    history.append({
        "pattern": state.get("pattern"),
        "task": state.get("task"),
        "system": state.get("system"),
        "started_at": state.get("started_at"),
        "stopped_at": state.get("stopped_at"),
        "iterations": state.get("iteration", 0),
        "cost": state.get("estimated_cost", 0),
        "stop_reason": reason,
        "checkpoints_passed": sum(1 for c in state.get("checkpoints", []) if c.get("success")),
        "checkpoints_failed": sum(1 for c in state.get("checkpoints", []) if not c.get("success")),
    })
    save_history(history)

    clear_state()
    print("Loop stopped: {}".format(reason))
    print("  Iterations: {}".format(state.get("iteration", 0)))
    print("  Cost:       ${:.3f}".format(state.get("estimated_cost", 0)))


def show_history():
    # type: () -> None
    """Show loop run history."""
    history = load_history()
    if not history:
        print("No loop history.")
        return

    print("\nLoop History (last 10):")
    print("-" * 70)
    for entry in history[-10:]:
        print("  {} | {} | {} | {} iters | ${:.3f} | {}".format(
            entry.get("started_at", "?")[:16],
            entry.get("pattern", "?"),
            entry.get("system", "?"),
            entry.get("iterations", 0),
            entry.get("cost", 0),
            entry.get("stop_reason", "?"),
        ))
    print("")


def main():
    parser = argparse.ArgumentParser(description="Mesh Loop Safety Manager")
    sub = parser.add_subparsers(dest="command")

    # Start
    start_p = sub.add_parser("start", help="Start a new loop")
    start_p.add_argument("--pattern", required=True, choices=list(PATTERNS.keys()))
    start_p.add_argument("--task", required=True, help="Task description")
    start_p.add_argument("--system", default="claude-code")
    start_p.add_argument("--budget", type=float, help="Budget limit ($)")
    start_p.add_argument("--mode", choices=["safe", "fast"], default="safe")

    # Checkpoint
    cp_p = sub.add_parser("checkpoint", help="Record a checkpoint")
    cp_p.add_argument("--name", required=True, help="Checkpoint name")
    cp_p.add_argument("--fail", action="store_true", help="Mark as failed")
    cp_p.add_argument("--cost", type=float, default=0.0, help="Cost for this step")
    cp_p.add_argument("--notes", default="", help="Notes")

    # Status
    sub.add_parser("status", help="Show loop status")

    # Stop
    stop_p = sub.add_parser("stop", help="Stop the loop")
    stop_p.add_argument("--reason", default="manual", help="Stop reason")

    # History
    sub.add_parser("history", help="Show loop history")

    args = parser.parse_args()

    if args.command == "start":
        start_loop(args.pattern, args.task, args.system, args.budget, args.mode)
    elif args.command == "checkpoint":
        add_checkpoint(args.name, success=not args.fail, cost=args.cost, notes=args.notes)
    elif args.command == "status":
        get_status()
    elif args.command == "stop":
        stop_loop(args.reason)
    elif args.command == "history":
        show_history()
    else:
        parser.print_help()


if __name__ == "__main__":
    main()
