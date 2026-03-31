#!/usr/bin/env python3
"""
Checkpoint System for AI Mesh
Adapted from ECC /checkpoint command.

Lightweight workflow state snapshots using git:
- Create named checkpoints (git stash + SHA recording)
- Verify progress between checkpoints (files changed, test delta)
- List checkpoints with status
- Clear old checkpoints (keep last N)

Usage:
    python3 mesh/checkpoint.py create "feature-start"
    python3 mesh/checkpoint.py create "core-done" --verify
    python3 mesh/checkpoint.py verify "feature-start"
    python3 mesh/checkpoint.py list
    python3 mesh/checkpoint.py clear --keep 5
    python3 mesh/checkpoint.py diff "feature-start" "core-done"
"""

import argparse
import json
import os
import subprocess
import sys
from datetime import datetime
from typing import Dict, List, Optional

MESH_DIR = os.path.dirname(os.path.abspath(__file__))
CHECKPOINT_FILE = os.path.join(MESH_DIR, "checkpoints.json")


def load_checkpoints():
    # type: () -> List[Dict]
    if not os.path.exists(CHECKPOINT_FILE):
        return []
    try:
        with open(CHECKPOINT_FILE) as f:
            return json.load(f)
    except (json.JSONDecodeError, IOError):
        return []


def save_checkpoints(checkpoints):
    # type: (List[Dict]) -> None
    with open(CHECKPOINT_FILE, "w") as f:
        json.dump(checkpoints, f, indent=2)


def get_git_sha(cwd=None):
    # type: (Optional[str]) -> Optional[str]
    try:
        result = subprocess.run(
            ["git", "rev-parse", "HEAD"],
            cwd=cwd or os.getcwd(),
            capture_output=True, text=True, timeout=5
        )
        return result.stdout.strip() if result.returncode == 0 else None
    except Exception:
        return None


def get_git_branch(cwd=None):
    # type: (Optional[str]) -> Optional[str]
    try:
        result = subprocess.run(
            ["git", "branch", "--show-current"],
            cwd=cwd or os.getcwd(),
            capture_output=True, text=True, timeout=5
        )
        return result.stdout.strip() if result.returncode == 0 else None
    except Exception:
        return None


def get_changed_files(since_sha, cwd=None):
    # type: (str, Optional[str]) -> List[str]
    try:
        result = subprocess.run(
            ["git", "diff", "--name-only", since_sha, "HEAD"],
            cwd=cwd or os.getcwd(),
            capture_output=True, text=True, timeout=10
        )
        if result.returncode == 0:
            return [f for f in result.stdout.strip().split("\n") if f.strip()]
    except Exception:
        pass
    return []


def get_diff_stat(since_sha, cwd=None):
    # type: (str, Optional[str]) -> Optional[str]
    try:
        result = subprocess.run(
            ["git", "diff", "--stat", since_sha, "HEAD"],
            cwd=cwd or os.getcwd(),
            capture_output=True, text=True, timeout=10
        )
        return result.stdout.strip() if result.returncode == 0 else None
    except Exception:
        return None


def create_checkpoint(name, path=None, notes=""):
    # type: (str, Optional[str], str) -> Dict
    """Create a named checkpoint."""
    cwd = path or os.getcwd()
    sha = get_git_sha(cwd)
    branch = get_git_branch(cwd)

    if not sha:
        print("ERROR: Not in a git repository or no commits yet.")
        sys.exit(1)

    checkpoints = load_checkpoints()

    # Check for duplicate name
    for cp in checkpoints:
        if cp["name"] == name:
            print("WARNING: Checkpoint '{}' already exists (SHA: {}). Overwriting.".format(
                name, cp["sha"][:8]))
            checkpoints.remove(cp)
            break

    checkpoint = {
        "name": name,
        "sha": sha,
        "branch": branch,
        "timestamp": datetime.now().isoformat(),
        "notes": notes,
    }

    checkpoints.append(checkpoint)
    save_checkpoints(checkpoints)

    print("Checkpoint created: {} (SHA: {})".format(name, sha[:8]))
    if notes:
        print("  Notes: {}".format(notes))
    return checkpoint


def verify_checkpoint(name, path=None):
    # type: (str, Optional[str]) -> None
    """Compare current state vs. a named checkpoint."""
    cwd = path or os.getcwd()
    checkpoints = load_checkpoints()

    target = None
    for cp in checkpoints:
        if cp["name"] == name:
            target = cp
            break

    if not target:
        print("ERROR: Checkpoint '{}' not found.".format(name))
        sys.exit(1)

    current_sha = get_git_sha(cwd)
    checkpoint_sha = target["sha"]

    print("\n" + "=" * 50)
    print("CHECKPOINT VERIFICATION: {}".format(name))
    print("=" * 50)
    print("  Checkpoint: {} ({})".format(checkpoint_sha[:8], target["timestamp"][:16]))
    print("  Current:    {}".format(current_sha[:8] if current_sha else "?"))
    print("")

    if current_sha == checkpoint_sha:
        print("  Status: NO CHANGES since checkpoint")
        print("=" * 50)
        return

    # Files changed
    changed = get_changed_files(checkpoint_sha, cwd)
    print("  Files Changed: {}".format(len(changed)))
    for f in changed[:20]:
        print("    {}".format(f))
    if len(changed) > 20:
        print("    ... and {} more".format(len(changed) - 20))

    # Diff stat
    stat = get_diff_stat(checkpoint_sha, cwd)
    if stat:
        # Print just the summary line
        lines = stat.strip().split("\n")
        if lines:
            print("\n  {}".format(lines[-1]))

    # Commits since
    try:
        result = subprocess.run(
            ["git", "log", "--oneline", "{}..HEAD".format(checkpoint_sha)],
            cwd=cwd, capture_output=True, text=True, timeout=10
        )
        commits = [l for l in result.stdout.strip().split("\n") if l.strip()]
        if commits:
            print("\n  Commits Since Checkpoint: {}".format(len(commits)))
            for c in commits[:10]:
                print("    {}".format(c))
    except Exception:
        pass

    print("=" * 50 + "\n")


def diff_checkpoints(name1, name2, path=None):
    # type: (str, str, Optional[str]) -> None
    """Show diff between two named checkpoints."""
    cwd = path or os.getcwd()
    checkpoints = load_checkpoints()

    cp1 = cp2 = None
    for cp in checkpoints:
        if cp["name"] == name1:
            cp1 = cp
        if cp["name"] == name2:
            cp2 = cp

    if not cp1:
        print("ERROR: Checkpoint '{}' not found.".format(name1))
        sys.exit(1)
    if not cp2:
        print("ERROR: Checkpoint '{}' not found.".format(name2))
        sys.exit(1)

    print("\n  Diff: {} ({}) → {} ({})".format(
        name1, cp1["sha"][:8], name2, cp2["sha"][:8]))

    changed = []
    try:
        result = subprocess.run(
            ["git", "diff", "--name-only", cp1["sha"], cp2["sha"]],
            cwd=cwd, capture_output=True, text=True, timeout=10
        )
        changed = [f for f in result.stdout.strip().split("\n") if f.strip()]
    except Exception:
        pass

    print("  Files: {}".format(len(changed)))
    for f in changed[:30]:
        print("    {}".format(f))
    print("")


def list_checkpoints():
    # type: () -> None
    """List all checkpoints."""
    checkpoints = load_checkpoints()
    if not checkpoints:
        print("No checkpoints.")
        return

    current_sha = get_git_sha()

    print("\nCheckpoints:")
    print("-" * 70)
    for cp in checkpoints:
        is_current = current_sha and cp["sha"] == current_sha
        marker = " <<<" if is_current else ""
        print("  {} | {} | {}{}".format(
            cp["timestamp"][:16],
            cp["sha"][:8],
            cp["name"],
            marker,
        ))
        if cp.get("notes"):
            print("  {}| {}".format(" " * 18, cp["notes"]))
    print("")


def clear_checkpoints(keep=5):
    # type: (int) -> None
    """Remove old checkpoints, keeping the last N."""
    checkpoints = load_checkpoints()
    if len(checkpoints) <= keep:
        print("Nothing to clear ({} checkpoints, keeping {}).".format(len(checkpoints), keep))
        return

    removed = len(checkpoints) - keep
    checkpoints = checkpoints[-keep:]
    save_checkpoints(checkpoints)
    print("Cleared {} old checkpoints. {} remaining.".format(removed, keep))


def main():
    parser = argparse.ArgumentParser(description="Mesh Checkpoint System")
    sub = parser.add_subparsers(dest="command")

    # Create
    create_p = sub.add_parser("create", help="Create a checkpoint")
    create_p.add_argument("name", help="Checkpoint name")
    create_p.add_argument("--notes", default="", help="Optional notes")
    create_p.add_argument("--verify", action="store_true", help="Verify against previous checkpoint")
    create_p.add_argument("--path", help="Git repo path")

    # Verify
    verify_p = sub.add_parser("verify", help="Verify against checkpoint")
    verify_p.add_argument("name", help="Checkpoint name")
    verify_p.add_argument("--path", help="Git repo path")

    # Diff
    diff_p = sub.add_parser("diff", help="Diff between two checkpoints")
    diff_p.add_argument("name1", help="First checkpoint")
    diff_p.add_argument("name2", help="Second checkpoint")
    diff_p.add_argument("--path", help="Git repo path")

    # List
    sub.add_parser("list", help="List checkpoints")

    # Clear
    clear_p = sub.add_parser("clear", help="Clear old checkpoints")
    clear_p.add_argument("--keep", type=int, default=5, help="Keep last N")

    args = parser.parse_args()

    if args.command == "create":
        cp = create_checkpoint(args.name, path=args.path, notes=args.notes)
        if args.verify:
            checkpoints = load_checkpoints()
            if len(checkpoints) >= 2:
                prev = checkpoints[-2]
                verify_checkpoint(prev["name"], path=args.path)
    elif args.command == "verify":
        verify_checkpoint(args.name, path=args.path)
    elif args.command == "diff":
        diff_checkpoints(args.name1, args.name2, path=args.path)
    elif args.command == "list":
        list_checkpoints()
    elif args.command == "clear":
        clear_checkpoints(keep=args.keep)
    else:
        parser.print_help()


if __name__ == "__main__":
    main()
