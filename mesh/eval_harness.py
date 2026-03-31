#!/usr/bin/env python3
"""
Eval Harness for AI Mesh
Adapted from ECC eval-harness skill (pass@k metrics).

Eval-Driven Development (EDD): Measure agent reliability with:
- pass@k: at least 1 success in k trials
- pass^k: ALL k trials succeed (for critical paths)
- Code-based graders (deterministic) > Model-based (probabilistic)
- Baseline snapshots for regression detection

Usage:
    python3 mesh/eval_harness.py create --name "router-accuracy" --type capability
    python3 mesh/eval_harness.py run --name "router-accuracy" --trials 5
    python3 mesh/eval_harness.py run --all --trials 3
    python3 mesh/eval_harness.py report
    python3 mesh/eval_harness.py baseline --name "router-accuracy"
    python3 mesh/eval_harness.py list
"""

import argparse
import json
import math
import os
import subprocess
import sys
import time
from datetime import datetime
from typing import Any, Callable, Dict, List, Optional, Tuple

MESH_DIR = os.path.dirname(os.path.abspath(__file__))
EVAL_DIR = os.path.join(MESH_DIR, "evals")
EVAL_RESULTS_FILE = os.path.join(MESH_DIR, "eval-results.json")
EVAL_BASELINES_FILE = os.path.join(MESH_DIR, "eval-baselines.json")


def ensure_eval_dir():
    os.makedirs(EVAL_DIR, exist_ok=True)


def load_eval(name):
    # type: (str) -> Optional[Dict]
    """Load an eval definition."""
    filepath = os.path.join(EVAL_DIR, "{}.json".format(name))
    if not os.path.exists(filepath):
        return None
    try:
        with open(filepath) as f:
            return json.load(f)
    except (json.JSONDecodeError, IOError):
        return None


def save_eval(eval_def):
    # type: (Dict) -> str
    """Save an eval definition."""
    ensure_eval_dir()
    name = eval_def["name"]
    filepath = os.path.join(EVAL_DIR, "{}.json".format(name))
    with open(filepath, "w") as f:
        json.dump(eval_def, f, indent=2)
    return filepath


def create_eval(
    name,           # type: str
    eval_type,      # type: str
    description,    # type: str
    command,        # type: str
    grader,         # type: str
    expected=None,  # type: Optional[str]
    timeout=60,     # type: int
    tags=None,      # type: Optional[List[str]]
):
    # type: (...) -> Dict
    """Create a new eval definition.

    Args:
        name: Unique eval name
        eval_type: "capability" (new feature) or "regression" (existing behavior)
        description: What this eval tests
        command: Shell command to run
        grader: "exit_code" | "output_contains" | "output_matches" | "custom"
        expected: Expected value for grader comparison
        timeout: Max seconds per trial
        tags: Optional tags for filtering
    """
    eval_def = {
        "schema_version": "1.0",
        "name": name,
        "type": eval_type,
        "description": description,
        "command": command,
        "grader": grader,
        "expected": expected,
        "timeout": timeout,
        "tags": tags or [],
        "created_at": datetime.now().isoformat(),
    }
    filepath = save_eval(eval_def)
    print("Eval created: {} ({})".format(name, filepath))
    return eval_def


def run_trial(eval_def):
    # type: (Dict) -> Dict[str, Any]
    """Run a single trial of an eval."""
    command = eval_def["command"]
    grader = eval_def["grader"]
    expected = eval_def.get("expected")
    timeout = eval_def.get("timeout", 60)

    start = time.time()
    try:
        result = subprocess.run(
            command, shell=True,
            capture_output=True, text=True,
            timeout=timeout, cwd=os.getcwd()
        )
        elapsed = time.time() - start

        # Grade the result
        passed = False
        if grader == "exit_code":
            expected_code = int(expected) if expected is not None else 0
            passed = result.returncode == expected_code
        elif grader == "output_contains":
            passed = expected in result.stdout if expected else True
        elif grader == "output_matches":
            passed = result.stdout.strip() == (expected or "").strip()
        elif grader == "custom":
            # Custom grader: command returns 0 for pass
            passed = result.returncode == 0
        else:
            passed = result.returncode == 0

        return {
            "passed": passed,
            "exit_code": result.returncode,
            "duration_s": round(elapsed, 2),
            "stdout": result.stdout[-500:] if result.stdout else "",
            "stderr": result.stderr[-500:] if result.stderr else "",
        }

    except subprocess.TimeoutExpired:
        return {
            "passed": False,
            "exit_code": -1,
            "duration_s": timeout,
            "error": "timeout",
        }
    except Exception as e:
        return {
            "passed": False,
            "exit_code": -1,
            "duration_s": time.time() - start,
            "error": str(e),
        }


def compute_pass_at_k(trials, k):
    # type: (List[Dict], int) -> float
    """Compute pass@k: probability of at least 1 success in k trials."""
    n = len(trials)
    c = sum(1 for t in trials if t["passed"])

    if n < k:
        # Not enough trials, use empirical rate
        return c / n if n > 0 else 0.0

    if c == n:
        return 1.0
    if c == 0:
        return 0.0

    # Exact computation: 1 - C(n-c, k) / C(n, k)
    # Using the identity to avoid large factorials
    result = 1.0
    for i in range(k):
        result *= (1.0 - c / (n - i))
    return 1.0 - result


def compute_pass_power_k(trials, k):
    # type: (List[Dict], int) -> float
    """Compute pass^k: probability ALL k trials succeed."""
    n = len(trials)
    c = sum(1 for t in trials if t["passed"])
    rate = c / n if n > 0 else 0.0
    return rate ** k


def run_eval(name, trials_count=3):
    # type: (str, int) -> Dict[str, Any]
    """Run an eval with multiple trials."""
    eval_def = load_eval(name)
    if not eval_def:
        print("ERROR: Eval '{}' not found.".format(name))
        sys.exit(1)

    print("Running eval: {} ({} trials)".format(name, trials_count))
    trials = []
    for i in range(trials_count):
        trial = run_trial(eval_def)
        trials.append(trial)
        icon = "+" if trial["passed"] else "X"
        print("  Trial {}/{}: [{}] ({:.2f}s)".format(
            i + 1, trials_count, icon, trial["duration_s"]))

    # Compute metrics
    passed = sum(1 for t in trials if t["passed"])
    pass_at_1 = compute_pass_at_k(trials, 1)
    pass_at_3 = compute_pass_at_k(trials, min(3, trials_count))
    pass_power_3 = compute_pass_power_k(trials, min(3, trials_count))
    avg_duration = sum(t["duration_s"] for t in trials) / len(trials) if trials else 0

    result = {
        "name": name,
        "type": eval_def.get("type", "unknown"),
        "timestamp": datetime.now().isoformat(),
        "trials": trials_count,
        "passed": passed,
        "failed": trials_count - passed,
        "pass_rate": round(passed / trials_count, 3) if trials_count > 0 else 0,
        "pass_at_1": round(pass_at_1, 3),
        "pass_at_3": round(pass_at_3, 3),
        "pass_power_3": round(pass_power_3, 3),
        "avg_duration_s": round(avg_duration, 2),
        "trial_details": trials,
    }

    # Save result
    save_result(result)

    # Check against baseline
    baseline = load_baseline(name)
    if baseline:
        regression = check_regression(result, baseline)
        result["regression"] = regression
        if regression:
            print("  !! REGRESSION: {}".format(regression))

    print("  Result: {}/{} passed (pass@1={:.0%}, pass@3={:.0%}, pass^3={:.0%})".format(
        passed, trials_count, pass_at_1, pass_at_3, pass_power_3))

    return result


def save_result(result):
    # type: (Dict) -> None
    """Append result to history."""
    results = []
    if os.path.exists(EVAL_RESULTS_FILE):
        try:
            with open(EVAL_RESULTS_FILE) as f:
                results = json.load(f)
        except (json.JSONDecodeError, IOError):
            results = []

    results.append(result)
    results = results[-500:]  # Keep last 500

    with open(EVAL_RESULTS_FILE, "w") as f:
        json.dump(results, f, indent=2)


def load_baseline(name):
    # type: (str) -> Optional[Dict]
    """Load baseline for an eval."""
    if not os.path.exists(EVAL_BASELINES_FILE):
        return None
    try:
        with open(EVAL_BASELINES_FILE) as f:
            baselines = json.load(f)
        return baselines.get(name)
    except (json.JSONDecodeError, IOError):
        return None


def save_baseline(name, result):
    # type: (str, Dict) -> None
    """Save current result as baseline."""
    baselines = {}
    if os.path.exists(EVAL_BASELINES_FILE):
        try:
            with open(EVAL_BASELINES_FILE) as f:
                baselines = json.load(f)
        except (json.JSONDecodeError, IOError):
            baselines = {}

    baselines[name] = {
        "pass_rate": result["pass_rate"],
        "pass_at_1": result["pass_at_1"],
        "pass_at_3": result["pass_at_3"],
        "avg_duration_s": result["avg_duration_s"],
        "saved_at": datetime.now().isoformat(),
    }

    with open(EVAL_BASELINES_FILE, "w") as f:
        json.dump(baselines, f, indent=2)

    print("Baseline saved for '{}': pass@1={:.0%}".format(name, result["pass_at_1"]))


def check_regression(result, baseline):
    # type: (Dict, Dict) -> Optional[str]
    """Check if result regressed from baseline."""
    if result["pass_at_1"] < baseline.get("pass_at_1", 0) - 0.1:
        return "pass@1 dropped from {:.0%} to {:.0%}".format(
            baseline["pass_at_1"], result["pass_at_1"])
    if result["avg_duration_s"] > baseline.get("avg_duration_s", 999) * 2:
        return "duration doubled from {:.1f}s to {:.1f}s".format(
            baseline["avg_duration_s"], result["avg_duration_s"])
    return None


def list_evals():
    # type: () -> None
    """List all eval definitions."""
    ensure_eval_dir()
    evals = []
    for fname in sorted(os.listdir(EVAL_DIR)):
        if fname.endswith(".json"):
            eval_def = load_eval(fname[:-5])
            if eval_def:
                evals.append(eval_def)

    if not evals:
        print("No evals defined. Create one with: python3 mesh/eval_harness.py create ...")
        return

    print("\nEvals:")
    print("-" * 70)
    for e in evals:
        baseline = load_baseline(e["name"])
        bl_str = "pass@1={:.0%}".format(baseline["pass_at_1"]) if baseline else "no baseline"
        print("  {} [{}] — {} ({})".format(
            e["name"], e.get("type", "?"), e.get("description", ""), bl_str))
    print("")


def show_report():
    # type: () -> None
    """Show summary of recent eval results."""
    if not os.path.exists(EVAL_RESULTS_FILE):
        print("No eval results yet.")
        return

    try:
        with open(EVAL_RESULTS_FILE) as f:
            results = json.load(f)
    except (json.JSONDecodeError, IOError):
        print("Error reading results.")
        return

    # Group by name, take most recent
    latest = {}  # type: Dict[str, Dict]
    for r in results:
        latest[r["name"]] = r

    print("\n" + "=" * 60)
    print("EVAL REPORT")
    print("=" * 60)

    for name, r in sorted(latest.items()):
        status = "PASS" if r["pass_rate"] >= 0.9 else ("WARN" if r["pass_rate"] >= 0.5 else "FAIL")
        icon = {"PASS": "+", "WARN": "~", "FAIL": "X"}.get(status, "?")
        print("  [{}] {} — {}/{} (pass@1={:.0%}, pass@3={:.0%}, pass^3={:.0%}, {:.1f}s avg)".format(
            icon, name, r["passed"], r["trials"],
            r["pass_at_1"], r["pass_at_3"], r["pass_power_3"],
            r["avg_duration_s"]))
        if r.get("regression"):
            print("      !! {}".format(r["regression"]))

    print("=" * 60 + "\n")


def main():
    parser = argparse.ArgumentParser(description="Mesh Eval Harness")
    sub = parser.add_subparsers(dest="command")

    # Create
    create_p = sub.add_parser("create", help="Create an eval")
    create_p.add_argument("--name", required=True)
    create_p.add_argument("--type", choices=["capability", "regression"], default="capability")
    create_p.add_argument("--description", default="")
    create_p.add_argument("--command", required=True, help="Shell command to evaluate")
    create_p.add_argument("--grader", choices=["exit_code", "output_contains", "output_matches", "custom"],
                          default="exit_code")
    create_p.add_argument("--expected", help="Expected value for grader")
    create_p.add_argument("--timeout", type=int, default=60)
    create_p.add_argument("--tags", nargs="*", default=[])

    # Run
    run_p = sub.add_parser("run", help="Run an eval")
    run_p.add_argument("--name", help="Eval name")
    run_p.add_argument("--all", action="store_true", help="Run all evals")
    run_p.add_argument("--trials", type=int, default=3)

    # Baseline
    bl_p = sub.add_parser("baseline", help="Set baseline from latest result")
    bl_p.add_argument("--name", required=True)

    # List
    sub.add_parser("list", help="List evals")

    # Report
    sub.add_parser("report", help="Show eval report")

    args = parser.parse_args()

    if args.command == "create":
        create_eval(
            name=args.name, eval_type=args.type,
            description=args.description, command=args.command,
            grader=args.grader, expected=args.expected,
            timeout=args.timeout, tags=args.tags,
        )
    elif args.command == "run":
        if args.all:
            ensure_eval_dir()
            for fname in sorted(os.listdir(EVAL_DIR)):
                if fname.endswith(".json"):
                    run_eval(fname[:-5], trials_count=args.trials)
        elif args.name:
            run_eval(args.name, trials_count=args.trials)
        else:
            print("Specify --name or --all")
    elif args.command == "baseline":
        # Use latest result
        if os.path.exists(EVAL_RESULTS_FILE):
            with open(EVAL_RESULTS_FILE) as f:
                results = json.load(f)
            for r in reversed(results):
                if r["name"] == args.name:
                    save_baseline(args.name, r)
                    break
            else:
                print("No results found for '{}'. Run it first.".format(args.name))
        else:
            print("No results yet.")
    elif args.command == "list":
        list_evals()
    elif args.command == "report":
        show_report()
    else:
        parser.print_help()


if __name__ == "__main__":
    main()
