#!/usr/bin/env python3
"""
Task Queue — Queue tasks for batch processing across the mesh.

Usage:
    python3 mesh/queue.py add 'build a REST API'
    python3 mesh/queue.py add --priority high 'fix critical bug'
    python3 mesh/queue.py list
    python3 mesh/queue.py run                    # Process queue, batch to cheapest system
    python3 mesh/queue.py run --dry-run          # Show what would run
    python3 mesh/queue.py clear                  # Clear completed tasks
    python3 mesh/queue.py remove <task-id>       # Remove a specific task
"""

from __future__ import annotations

import argparse
import json
import sys
import uuid
from collections import defaultdict
from datetime import datetime, timezone
from pathlib import Path

MESH_DIR = Path(__file__).resolve().parent
QUEUE_FILE = MESH_DIR / "task_queue.json"


def load_queue() -> list[dict]:
    if not QUEUE_FILE.exists():
        return []
    try:
        data = json.loads(QUEUE_FILE.read_text())
        return data if isinstance(data, list) else []
    except (json.JSONDecodeError, OSError):
        return []


def save_queue(data: list[dict]) -> None:
    QUEUE_FILE.write_text(json.dumps(data, indent=2) + "\n")


def add_task(description: str, priority: str = "normal") -> dict:
    """Add a task to the queue."""
    # Import router for classification
    sys.path.insert(0, str(MESH_DIR))
    try:
        from router import classify, route
        result = route(description)
        classification = result["classification"]
        recommended = result["recommended"]
    except ImportError:
        classification = "unknown"
        recommended = "claude-code"

    task = {
        "id": str(uuid.uuid4())[:8],
        "description": description,
        "classification": classification,
        "recommended_system": recommended,
        "priority": priority,
        "status": "pending",
        "created_at": datetime.now(timezone.utc).isoformat(),
        "completed_at": None,
    }

    queue = load_queue()
    queue.append(task)
    save_queue(queue)
    return task


def list_tasks(show_all: bool = False) -> list[dict]:
    """List tasks in the queue."""
    queue = load_queue()
    if not show_all:
        return [t for t in queue if t.get("status") == "pending"]
    return queue


def remove_task(task_id: str) -> bool:
    """Remove a task by ID."""
    queue = load_queue()
    new_queue = [t for t in queue if t.get("id") != task_id]
    if len(new_queue) == len(queue):
        return False
    save_queue(new_queue)
    return True


def clear_completed() -> int:
    """Clear completed tasks. Returns count of cleared tasks."""
    queue = load_queue()
    pending = [t for t in queue if t.get("status") == "pending"]
    cleared = len(queue) - len(pending)
    save_queue(pending)
    return cleared


def batch_tasks(tasks: list[dict]) -> dict[str, list[dict]]:
    """Group similar tasks by recommended system for batch processing."""
    batches: dict[str, list[dict]] = defaultdict(list)
    for task in tasks:
        system = task.get("recommended_system", "claude-code")
        batches[system].append(task)
    return dict(batches)


def run_queue(dry_run: bool = False) -> dict:
    """Process the queue, batching similar tasks to the cheapest system.

    Returns a summary of what was/would be processed.
    """
    queue = load_queue()
    pending = [t for t in queue if t.get("status") == "pending"]

    if not pending:
        return {"message": "Queue is empty", "processed": 0}

    # Sort by priority
    priority_order = {"high": 0, "normal": 1, "low": 2}
    pending.sort(key=lambda t: priority_order.get(t.get("priority", "normal"), 1))

    # Batch by system
    batches = batch_tasks(pending)

    result = {
        "total_pending": len(pending),
        "batches": {},
        "dry_run": dry_run,
    }

    for system, tasks in batches.items():
        task_descs = [t["description"] for t in tasks]
        result["batches"][system] = {
            "count": len(tasks),
            "tasks": task_descs,
        }

        if not dry_run:
            # Mark as processing
            for task in tasks:
                task["status"] = "completed"
                task["completed_at"] = datetime.now(timezone.utc).isoformat()

            # Execute via dispatch
            try:
                sys.path.insert(0, str(MESH_DIR))
                from dispatch import execute_on_system
                for task in tasks:
                    success, output, duration = execute_on_system(system, task["description"], 120)
                    task["result"] = "success" if success else "failed"
                    task["duration"] = round(duration, 2)
            except ImportError:
                for task in tasks:
                    task["result"] = "skipped (dispatch unavailable)"

    if not dry_run:
        save_queue(queue)
        result["processed"] = len(pending)
    else:
        result["processed"] = 0

    return result


def format_list(tasks: list[dict]) -> str:
    """Format task list for display."""
    if not tasks:
        return "[queue] No pending tasks."

    lines = [f"[queue] {len(tasks)} pending task(s):", ""]

    # Sort by priority
    priority_order = {"high": 0, "normal": 1, "low": 2}
    tasks.sort(key=lambda t: priority_order.get(t.get("priority", "normal"), 1))

    for t in tasks:
        pri = t.get("priority", "normal")
        pri_marker = "!!!" if pri == "high" else "   " if pri == "low" else " ! "
        desc = t["description"]
        if len(desc) > 60:
            desc = desc[:57] + "..."
        lines.append(
            f"  [{t['id']}] {pri_marker} {desc}"
            f"  -> {t.get('recommended_system', '?')} ({t.get('classification', '?')})"
        )

    return "\n".join(lines)


def format_run_result(result: dict) -> str:
    """Format run result for display."""
    if result.get("message"):
        return f"[queue] {result['message']}"

    mode = "DRY RUN" if result["dry_run"] else "EXECUTED"
    lines = [f"[queue] {mode} — {result['total_pending']} tasks", ""]

    for system, batch in result["batches"].items():
        lines.append(f"  {system} ({batch['count']} tasks):")
        for task in batch["tasks"]:
            desc = task if len(task) <= 55 else task[:52] + "..."
            lines.append(f"    - {desc}")
        lines.append("")

    if not result["dry_run"]:
        lines.append(f"Processed: {result['processed']} tasks")

    return "\n".join(lines)


def main() -> int:
    parser = argparse.ArgumentParser(description="AI Mesh Task Queue")
    sub = parser.add_subparsers(dest="command")

    # add
    add_p = sub.add_parser("add", help="Add a task to the queue")
    add_p.add_argument("description", help="Task description")
    add_p.add_argument("--priority", choices=["high", "normal", "low"], default="normal")

    # list
    list_p = sub.add_parser("list", help="List pending tasks")
    list_p.add_argument("--all", action="store_true", help="Show all tasks including completed")

    # run
    run_p = sub.add_parser("run", help="Process the queue")
    run_p.add_argument("--dry-run", action="store_true", help="Show plan without executing")

    # clear
    sub.add_parser("clear", help="Clear completed tasks")

    # remove
    rem_p = sub.add_parser("remove", help="Remove a specific task")
    rem_p.add_argument("task_id", help="Task ID to remove")

    args = parser.parse_args()

    if args.command == "add":
        task = add_task(args.description, args.priority)
        print(f"[queue] Added: [{task['id']}] {task['description']}")
        print(f"        Route: {task['recommended_system']} ({task['classification']})")
        return 0

    elif args.command == "list":
        tasks = list_tasks(show_all=getattr(args, "all", False))
        print(format_list(tasks))
        return 0

    elif args.command == "run":
        result = run_queue(dry_run=args.dry_run)
        print(format_run_result(result))
        return 0

    elif args.command == "clear":
        count = clear_completed()
        print(f"[queue] Cleared {count} completed task(s)")
        return 0

    elif args.command == "remove":
        if remove_task(args.task_id):
            print(f"[queue] Removed task {args.task_id}")
        else:
            print(f"[queue] Task {args.task_id} not found")
            return 1
        return 0

    else:
        parser.print_help()
        return 1


if __name__ == "__main__":
    sys.exit(main())
