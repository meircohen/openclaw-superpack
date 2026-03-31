#!/usr/bin/env python3
"""
Multi-Agent Orchestration for AI Mesh
Adapted from ECC /orchestrate command + handoff document pattern.

Runs sequential multi-system workflows where each system produces a
handoff document for the next. Supports: feature, bugfix, refactor,
security-audit, research, custom workflows.

Usage:
    python3 mesh/orchestrate.py feature "Add OAuth2 login"
    python3 mesh/orchestrate.py bugfix "Fix race condition in queue"
    python3 mesh/orchestrate.py refactor "Split monolith into services"
    python3 mesh/orchestrate.py security-audit
    python3 mesh/orchestrate.py research "Compare vector DB options"
    python3 mesh/orchestrate.py --dry-run feature "Add caching layer"
    python3 mesh/orchestrate.py --json feature "Add auth"
"""

import argparse
import json
import os
import sys
import time
from datetime import datetime
from typing import Any, Dict, List, Optional, Tuple

MESH_DIR = os.path.dirname(os.path.abspath(__file__))
HANDOFF_DIR = os.path.join(MESH_DIR, "handoffs")
ORCHESTRATION_LOG = os.path.join(MESH_DIR, "orchestration-log.json")

# Workflow definitions: ordered list of (system, role, description)
WORKFLOWS = {
    "feature": [
        ("claude-code", "planner", "Break feature into tasks with acceptance criteria"),
        ("codex", "implementer", "Implement the feature following the plan"),
        ("claude-code", "spec_reviewer", "Review: does implementation match plan EXACTLY? (no over/under-building)"),
        ("claude-code", "quality_reviewer", "Review: code quality, patterns, naming, error handling, tests"),
        ("claude-code", "security", "Security review of new code"),
    ],
    "bugfix": [
        ("claude-code", "debugger", "Investigate root cause with systematic debugging"),
        ("codex", "fixer", "Implement fix following TDD (test first, then fix)"),
        ("claude-code", "spec_reviewer", "Review: does fix address root cause completely?"),
        ("claude-code", "verifier", "Verify fix resolves issue without regressions"),
    ],
    "refactor": [
        ("claude-code", "architect", "Analyze current code and design refactoring plan"),
        ("codex", "implementer", "Execute refactoring following the plan"),
        ("claude-code", "spec_reviewer", "Review: does refactoring match the plan? No scope creep?"),
        ("claude-code", "quality_reviewer", "Review: code quality and pattern consistency"),
        ("claude-code", "tester", "Verify all tests pass and coverage maintained"),
    ],
    "security-audit": [
        ("claude-code", "scanner", "Run security scan and identify vulnerabilities"),
        ("perplexity", "researcher", "Research CVEs and best practices for findings"),
        ("claude-code", "fixer", "Implement security fixes"),
        ("claude-code", "verifier", "Verify fixes and re-scan"),
    ],
    "research": [
        ("perplexity", "researcher", "Deep research on topic with citations"),
        ("gemini", "analyzer", "Analyze findings and identify patterns"),
        ("claude-code", "synthesizer", "Synthesize into actionable recommendations"),
    ],
}


def create_handoff(
    from_system,    # type: str
    from_role,      # type: str
    to_system,      # type: str
    to_role,        # type: str
    context,        # type: str
    findings,       # type: List[str]
    files_modified, # type: List[str]
    open_questions, # type: List[str]
    recommendations,# type: List[str]
    status,         # type: str
):
    # type: (...) -> Dict[str, Any]
    """Create a structured handoff document between systems."""
    return {
        "schema_version": "1.0",
        "timestamp": datetime.now().isoformat(),
        "from": {"system": from_system, "role": from_role},
        "to": {"system": to_system, "role": to_role},
        "context": context,
        "findings": findings,
        "files_modified": files_modified,
        "open_questions": open_questions,
        "recommendations": recommendations,
        "status": status,  # "completed", "partial", "blocked"
    }


def save_handoff(handoff, workflow_id):
    # type: (Dict, str) -> str
    """Persist handoff document."""
    os.makedirs(HANDOFF_DIR, exist_ok=True)
    filename = "{}-{}-to-{}.json".format(
        workflow_id,
        handoff["from"]["role"],
        handoff["to"]["role"],
    )
    filepath = os.path.join(HANDOFF_DIR, filename)
    with open(filepath, "w") as f:
        json.dump(handoff, f, indent=2)
    return filepath


def format_handoff_prompt(handoff, task_description, step_description):
    # type: (Optional[Dict], str, str) -> str
    """Format handoff into a prompt for the next system."""
    lines = []
    lines.append("# Task: {}".format(task_description))
    lines.append("# Your Role: {}".format(step_description))
    lines.append("")

    if handoff:
        lines.append("## Previous Agent Handoff ({} / {})".format(
            handoff["from"]["system"], handoff["from"]["role"]))
        lines.append("")
        lines.append("### Context")
        lines.append(handoff.get("context", "(none)"))
        lines.append("")

        findings = handoff.get("findings", [])
        if findings:
            lines.append("### Findings")
            for f in findings:
                lines.append("- {}".format(f))
            lines.append("")

        files = handoff.get("files_modified", [])
        if files:
            lines.append("### Files Modified")
            for f in files:
                lines.append("- {}".format(f))
            lines.append("")

        questions = handoff.get("open_questions", [])
        if questions:
            lines.append("### Open Questions")
            for q in questions:
                lines.append("- {}".format(q))
            lines.append("")

        recs = handoff.get("recommendations", [])
        if recs:
            lines.append("### Recommendations for You")
            for r in recs:
                lines.append("- {}".format(r))
            lines.append("")

    lines.append("## Instructions")
    lines.append("Complete your role. When done, provide:")
    lines.append("1. Summary of what you did")
    lines.append("2. Files you modified")
    lines.append("3. Any open questions for the next agent")
    lines.append("4. Recommendations for the next step")
    lines.append("")

    return "\n".join(lines)


def generate_orchestration_report(
    workflow_type,  # type: str
    task,           # type: str
    steps,          # type: List[Dict]
    handoffs,       # type: List[Dict]
    total_time,     # type: float
):
    # type: (...) -> Dict[str, Any]
    """Generate final orchestration report."""
    all_files = set()
    all_findings = []
    for h in handoffs:
        all_files.update(h.get("files_modified", []))
        all_findings.extend(h.get("findings", []))

    statuses = [s.get("status", "unknown") for s in steps]
    blocked = any(s == "blocked" for s in statuses)
    partial = any(s == "partial" for s in statuses)

    if blocked:
        verdict = "BLOCKED"
    elif partial:
        verdict = "NEEDS WORK"
    else:
        verdict = "SHIP"

    return {
        "schema_version": "1.0",
        "timestamp": datetime.now().isoformat(),
        "workflow": workflow_type,
        "task": task,
        "verdict": verdict,
        "total_time_s": round(total_time, 1),
        "steps": steps,
        "all_files_modified": sorted(all_files),
        "all_findings": all_findings,
        "handoffs": handoffs,
    }


def print_orchestration_plan(workflow_type, task, steps_def):
    # type: (str, str, List[Tuple]) -> None
    """Print the orchestration plan before execution."""
    print("\n" + "=" * 60)
    print("ORCHESTRATION PLAN")
    print("=" * 60)
    print("Workflow: {}".format(workflow_type))
    print("Task:     {}".format(task))
    print("-" * 60)
    for i, (system, role, desc) in enumerate(steps_def, 1):
        print("  Step {}: {} ({})".format(i, role.upper(), system))
        print("          {}".format(desc))
        if i < len(steps_def):
            print("          |")
            print("          v  [handoff document]")
    print("=" * 60 + "\n")


def print_report(report):
    # type: (Dict) -> None
    """Print human-readable orchestration report."""
    print("\n" + "=" * 60)
    print("ORCHESTRATION REPORT")
    print("=" * 60)
    print("Workflow:  {}".format(report["workflow"]))
    print("Task:      {}".format(report["task"]))
    print("Verdict:   {}".format(report["verdict"]))
    print("Duration:  {:.1f}s".format(report["total_time_s"]))
    print("-" * 60)

    for step in report["steps"]:
        icon = {"completed": "+", "partial": "~", "blocked": "X", "skipped": "-"}.get(
            step.get("status", "?"), "?")
        print("  [{}] {} ({}) — {}".format(
            icon, step["role"].upper(), step["system"], step.get("status", "?")))
        if step.get("summary"):
            print("      {}".format(step["summary"][:80]))

    files = report.get("all_files_modified", [])
    if files:
        print("\nFiles Modified ({})".format(len(files)))
        for f in files[:20]:
            print("  {}".format(f))
        if len(files) > 20:
            print("  ... and {} more".format(len(files) - 20))

    findings = report.get("all_findings", [])
    if findings:
        print("\nFindings ({})".format(len(findings)))
        for f in findings[:10]:
            print("  - {}".format(f))

    print("\nRecommendation: {}".format(report["verdict"]))
    print("=" * 60 + "\n")


def log_orchestration(report):
    # type: (Dict) -> None
    """Append to orchestration log."""
    log = []
    if os.path.exists(ORCHESTRATION_LOG):
        try:
            with open(ORCHESTRATION_LOG) as f:
                log = json.load(f)
        except (json.JSONDecodeError, IOError):
            log = []

    # Keep last 100 entries
    log.append({
        "timestamp": report["timestamp"],
        "workflow": report["workflow"],
        "task": report["task"],
        "verdict": report["verdict"],
        "steps": len(report["steps"]),
        "duration_s": report["total_time_s"],
        "files_modified": len(report.get("all_files_modified", [])),
    })
    log = log[-100:]

    with open(ORCHESTRATION_LOG, "w") as f:
        json.dump(log, f, indent=2)


def main():
    parser = argparse.ArgumentParser(description="Mesh Multi-Agent Orchestration")
    parser.add_argument("workflow", choices=list(WORKFLOWS.keys()),
                        help="Workflow type")
    parser.add_argument("task", nargs="?", default="",
                        help="Task description")
    parser.add_argument("--dry-run", action="store_true",
                        help="Show plan without executing")
    parser.add_argument("--json", action="store_true",
                        help="JSON output")
    args = parser.parse_args()

    steps_def = WORKFLOWS[args.workflow]

    if args.dry_run:
        print_orchestration_plan(args.workflow, args.task, steps_def)
        print("(dry run — no execution)")
        return

    # In dry-run or plan mode, just show the plan
    # Actual execution would dispatch to each system via dispatch.py
    # For now, generate the plan and handoff templates
    print_orchestration_plan(args.workflow, args.task, steps_def)

    print("To execute this workflow, each step should be dispatched to its system")
    print("with the handoff document from the previous step as input.")
    print("")
    print("Handoff template for Step 1:")
    prompt = format_handoff_prompt(None, args.task, steps_def[0][2])
    print(prompt)


# ---------------------------------------------------------------------------
# Worktree Orchestration (adapted from ECC orchestrate-worktrees.js)
# ---------------------------------------------------------------------------
# Provides tmux-based parallel worker coordination using git worktrees.
# Each worker gets an isolated worktree, a task file, and a handoff file.
# Workers run in tmux panes for visibility and can be monitored.

import shutil
import subprocess
import tempfile

WORKTREE_BASE = os.path.join(MESH_DIR, "worktrees")
COORDINATION_DIR = os.path.join(MESH_DIR, "coordination")


def _slug(name):
    # type: (str) -> str
    """Convert a worker name to a filesystem-safe slug."""
    return name.lower().replace(" ", "-").replace("/", "-")[:40]


def build_worktree_plan(
    session_name,   # type: str
    repo_root,      # type: str
    workers,        # type: List[Dict[str, Any]]
    base_branch="main",  # type: str
):
    # type: (...) -> Dict[str, Any]
    """Build an orchestration plan for parallel worktree workers.

    Each worker dict should have:
        - name: str — human-readable worker name
        - task: str — task description
        - launcher: str — command template with placeholders:
            {worker_name} {worker_slug} {session_name} {repo_root}
            {worktree_path} {branch_name} {task_file} {handoff_file} {status_file}

    Returns a plan dict with workerPlans, tmuxCommands, coordinationDir, etc.
    """
    timestamp = datetime.now().strftime("%Y%m%d-%H%M%S")
    session_slug = _slug(session_name)
    coord_dir = os.path.join(COORDINATION_DIR, "{}-{}".format(session_slug, timestamp))

    worker_plans = []
    for worker in workers:
        w_slug = _slug(worker["name"])
        branch = "worktree/{}-{}-{}".format(session_slug, w_slug, timestamp)
        wt_path = os.path.join(WORKTREE_BASE, "{}-{}".format(session_slug, w_slug))
        task_file = os.path.join(coord_dir, "{}-task.md".format(w_slug))
        handoff_file = os.path.join(coord_dir, "{}-handoff.json".format(w_slug))
        status_file = os.path.join(coord_dir, "{}-status.json".format(w_slug))

        # Build launcher command from template
        launcher = worker.get("launcher", "echo 'No launcher for {worker_name}'")
        launch_cmd = launcher.format(
            worker_name=worker["name"],
            worker_slug=w_slug,
            session_name=session_name,
            repo_root=repo_root,
            worktree_path=wt_path,
            branch_name=branch,
            task_file=task_file,
            handoff_file=handoff_file,
            status_file=status_file,
        )

        worker_plans.append({
            "workerName": worker["name"],
            "workerSlug": w_slug,
            "branchName": branch,
            "worktreePath": wt_path,
            "baseBranch": base_branch,
            "taskFileContent": worker.get("task", ""),
            "taskFilePath": task_file,
            "handoffFilePath": handoff_file,
            "statusFilePath": status_file,
            "launchCommand": launch_cmd,
            "gitCommand": "git worktree add -b {} {} {}".format(branch, wt_path, base_branch),
        })

    # tmux commands to create session and panes
    tmux_commands = []
    for i, wp in enumerate(worker_plans):
        if i == 0:
            tmux_commands.append({
                "cmd": "tmux",
                "args": ["new-session", "-d", "-s", session_name, "-n", "workers",
                         wp["launchCommand"]],
            })
        else:
            tmux_commands.append({
                "cmd": "tmux",
                "args": ["split-window", "-t", "{}:workers".format(session_name),
                         wp["launchCommand"]],
            })

    # Even out the layout
    tmux_commands.append({
        "cmd": "tmux",
        "args": ["select-layout", "-t", "{}:workers".format(session_name), "tiled"],
    })

    return {
        "sessionName": session_name,
        "repoRoot": repo_root,
        "baseBranch": base_branch,
        "coordinationDir": coord_dir,
        "workerPlans": worker_plans,
        "tmuxCommands": tmux_commands,
        "timestamp": timestamp,
    }


def materialize_worktree_plan(plan):
    # type: (Dict[str, Any]) -> None
    """Write coordination files to disk (task files, empty handoff/status).

    Does NOT create worktrees or launch tmux -- call execute_worktree_plan for that.
    """
    coord_dir = plan["coordinationDir"]
    os.makedirs(coord_dir, exist_ok=True)

    for wp in plan["workerPlans"]:
        # Write task file
        with open(wp["taskFilePath"], "w") as f:
            f.write("# Task: {}\n\n".format(wp["workerName"]))
            f.write(wp.get("taskFileContent", ""))

        # Write empty handoff placeholder
        with open(wp["handoffFilePath"], "w") as f:
            json.dump({"status": "pending", "worker": wp["workerName"]}, f, indent=2)

        # Write initial status
        with open(wp["statusFilePath"], "w") as f:
            json.dump({
                "worker": wp["workerName"],
                "status": "pending",
                "started_at": None,
                "completed_at": None,
            }, f, indent=2)


def execute_worktree_plan(plan, dry_run=False):
    # type: (Dict[str, Any], bool) -> Dict[str, Any]
    """Execute the orchestration plan: create worktrees, write files, launch tmux.

    Steps:
    1. Create coordination directory and task files
    2. Create git worktrees for each worker
    3. Launch tmux session with worker panes

    Returns result dict with session name, worker count, coordination dir.
    """
    # Step 1: Materialize files
    materialize_worktree_plan(plan)

    if dry_run:
        return {
            "sessionName": plan["sessionName"],
            "workerCount": len(plan["workerPlans"]),
            "coordinationDir": plan["coordinationDir"],
            "dryRun": True,
            "commands": [wp["gitCommand"] for wp in plan["workerPlans"]],
        }

    # Step 2: Create worktrees
    os.makedirs(WORKTREE_BASE, exist_ok=True)
    for wp in plan["workerPlans"]:
        subprocess.run(
            wp["gitCommand"].split(),
            cwd=plan["repoRoot"],
            check=True,
            capture_output=True,
        )

    # Step 3: Launch tmux
    for tmux_cmd in plan["tmuxCommands"]:
        subprocess.run(
            [tmux_cmd["cmd"]] + tmux_cmd["args"],
            check=True,
            capture_output=True,
        )

    return {
        "sessionName": plan["sessionName"],
        "workerCount": len(plan["workerPlans"]),
        "coordinationDir": plan["coordinationDir"],
        "dryRun": False,
    }


def cleanup_worktrees(plan):
    # type: (Dict[str, Any]) -> List[str]
    """Remove worktrees and branches created by a plan.

    Returns list of cleaned up worktree paths.
    """
    cleaned = []
    for wp in plan["workerPlans"]:
        wt_path = wp["worktreePath"]
        branch = wp["branchName"]

        # Remove worktree
        if os.path.exists(wt_path):
            subprocess.run(
                ["git", "worktree", "remove", "--force", wt_path],
                cwd=plan["repoRoot"],
                capture_output=True,
            )
            cleaned.append(wt_path)

        # Delete branch
        subprocess.run(
            ["git", "branch", "-D", branch],
            cwd=plan["repoRoot"],
            capture_output=True,
        )

    return cleaned


def check_worktree_progress(coordination_dir):
    # type: (str) -> Dict[str, Any]
    """Check progress of all workers by reading their status files.

    Returns summary with per-worker status and overall progress.
    """
    if not os.path.isdir(coordination_dir):
        return {"error": "Coordination directory not found: {}".format(coordination_dir)}

    statuses = []
    for fname in sorted(os.listdir(coordination_dir)):
        if fname.endswith("-status.json"):
            fpath = os.path.join(coordination_dir, fname)
            try:
                with open(fpath) as f:
                    status = json.load(f)
                statuses.append(status)
            except (json.JSONDecodeError, IOError):
                statuses.append({"worker": fname, "status": "unknown", "error": "unreadable"})

    total = len(statuses)
    completed = sum(1 for s in statuses if s.get("status") == "completed")
    failed = sum(1 for s in statuses if s.get("status") == "failed")
    running = sum(1 for s in statuses if s.get("status") == "running")
    pending = total - completed - failed - running

    return {
        "total_workers": total,
        "completed": completed,
        "running": running,
        "pending": pending,
        "failed": failed,
        "all_done": completed + failed == total and total > 0,
        "workers": statuses,
    }


def print_worktree_plan(plan):
    # type: (Dict[str, Any]) -> None
    """Print a human-readable worktree orchestration plan."""
    print("\n" + "=" * 60)
    print("WORKTREE ORCHESTRATION PLAN")
    print("=" * 60)
    print("Session:    {}".format(plan["sessionName"]))
    print("Repo:       {}".format(plan["repoRoot"]))
    print("Base:       {}".format(plan["baseBranch"]))
    print("Coord dir:  {}".format(plan["coordinationDir"]))
    print("-" * 60)

    for i, wp in enumerate(plan["workerPlans"], 1):
        print("  Worker {}: {}".format(i, wp["workerName"]))
        print("    Branch:    {}".format(wp["branchName"]))
        print("    Worktree:  {}".format(wp["worktreePath"]))
        print("    Task file: {}".format(wp["taskFilePath"]))
        print("    Command:   {}".format(wp["launchCommand"][:80]))
        if i < len(plan["workerPlans"]):
            print()

    print("=" * 60)
    print("Attach with: tmux attach -t {}".format(plan["sessionName"]))
    print("=" * 60 + "\n")


if __name__ == "__main__":
    main()
