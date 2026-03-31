#!/usr/bin/env python3
"""
Session Save/Resume for AI Mesh
Adapted from ECC /save-session + /resume-session commands.

Persists session state with structured sections:
- What We're Building (context for zero-memory resumption)
- What WORKED (with evidence)
- What Did NOT Work (exact reason — prevents blind retry)
- What Has NOT Been Tried Yet
- Current File State
- Decisions Made
- Blockers & Open Questions
- Exact Next Step

Usage:
    python3 mesh/session.py save --name "auth-refactor" --building "OAuth2 integration"
    python3 mesh/session.py resume                    # most recent
    python3 mesh/session.py resume --date 2026-03-31
    python3 mesh/session.py resume --name "auth-refactor"
    python3 mesh/session.py list
    python3 mesh/session.py list --stale              # >7 days old
"""

import argparse
import json
import os
import re
import sys
from datetime import datetime, timedelta
from typing import Dict, List, Optional

MESH_DIR = os.path.dirname(os.path.abspath(__file__))
SESSION_DIR = os.path.join(MESH_DIR, "sessions")


def ensure_session_dir():
    os.makedirs(SESSION_DIR, exist_ok=True)


def session_filename(name=None, session_id=None):
    # type: (Optional[str], Optional[str]) -> str
    """Generate session filename: YYYY-MM-DD-<name>-session.json"""
    date_str = datetime.now().strftime("%Y-%m-%d")
    tag = name or session_id or "default"
    # Sanitize: only allow alphanumeric, dash, underscore
    tag = re.sub(r"[^a-zA-Z0-9_-]", "-", tag)[:40]
    return "{}-{}-session.json".format(date_str, tag)


def save_session(
    name,           # type: str
    building,       # type: str
    worked,         # type: List[Dict[str, str]]
    not_worked,     # type: List[Dict[str, str]]
    not_tried,      # type: List[str]
    file_states,    # type: List[Dict[str, str]]
    decisions,      # type: List[str]
    blockers,       # type: List[str]
    next_step,      # type: str
    system_used,    # type: str
    metadata=None,  # type: Optional[Dict]
):
    # type: (...) -> str
    """Save session state. Returns filepath."""
    ensure_session_dir()

    session = {
        "schema_version": "1.0",
        "name": name,
        "timestamp": datetime.now().isoformat(),
        "system": system_used,
        "building": building,
        "worked": worked,        # [{"what": "...", "evidence": "..."}]
        "not_worked": not_worked,  # [{"what": "...", "reason": "...", "error": "..."}]
        "not_tried": not_tried,
        "file_states": file_states,  # [{"file": "...", "status": "modified|created|deleted", "notes": "..."}]
        "decisions": decisions,
        "blockers": blockers,
        "next_step": next_step,
        "metadata": metadata or {},
    }

    filename = session_filename(name)
    filepath = os.path.join(SESSION_DIR, filename)

    with open(filepath, "w") as f:
        json.dump(session, f, indent=2)

    return filepath


def load_session(filepath):
    # type: (str) -> Dict
    """Load a session file."""
    with open(filepath) as f:
        return json.load(f)


def find_sessions(name=None, date=None, include_stale=False):
    # type: (Optional[str], Optional[str], bool) -> List[str]
    """Find session files matching criteria."""
    ensure_session_dir()
    files = []
    for f in sorted(os.listdir(SESSION_DIR), reverse=True):
        if not f.endswith("-session.json"):
            continue
        filepath = os.path.join(SESSION_DIR, f)

        if name and name.lower() not in f.lower():
            continue
        if date and not f.startswith(date):
            continue

        if not include_stale:
            try:
                session = load_session(filepath)
                ts = datetime.fromisoformat(session["timestamp"])
                if (datetime.now() - ts) > timedelta(days=7):
                    continue
            except (KeyError, ValueError, json.JSONDecodeError):
                pass

        files.append(filepath)

    return files


def format_briefing(session):
    # type: (Dict) -> str
    """Format session as structured briefing for agent resumption."""
    lines = []
    lines.append("=" * 60)
    lines.append("SESSION BRIEFING")
    lines.append("=" * 60)
    lines.append("")
    lines.append("Name:    {}".format(session.get("name", "unknown")))
    lines.append("System:  {}".format(session.get("system", "unknown")))
    lines.append("Saved:   {}".format(session.get("timestamp", "unknown")))
    lines.append("")

    lines.append("## WHAT WE'RE BUILDING")
    lines.append(session.get("building", "(not specified)"))
    lines.append("")

    # What worked
    worked = session.get("worked", [])
    if worked:
        lines.append("## WHAT WORKED (verified)")
        for item in worked:
            lines.append("  + {} — Evidence: {}".format(
                item.get("what", "?"), item.get("evidence", "none")))
        lines.append("")

    # CRITICAL: What did NOT work
    not_worked = session.get("not_worked", [])
    if not_worked:
        lines.append("## WHAT NOT TO RETRY (failed approaches)")
        for item in not_worked:
            lines.append("  X {} — Reason: {}".format(
                item.get("what", "?"), item.get("reason", "unknown")))
            if item.get("error"):
                lines.append("    Error: {}".format(item["error"]))
        lines.append("")

    # Not tried
    not_tried = session.get("not_tried", [])
    if not_tried:
        lines.append("## UNTRIED APPROACHES")
        for item in not_tried:
            lines.append("  ? {}".format(item))
        lines.append("")

    # File states
    file_states = session.get("file_states", [])
    if file_states:
        lines.append("## FILE STATE")
        for fs in file_states:
            lines.append("  {} [{}] {}".format(
                fs.get("file", "?"), fs.get("status", "?"), fs.get("notes", "")))
        lines.append("")

    # Decisions
    decisions = session.get("decisions", [])
    if decisions:
        lines.append("## DECISIONS MADE")
        for d in decisions:
            lines.append("  - {}".format(d))
        lines.append("")

    # Blockers
    blockers = session.get("blockers", [])
    if blockers:
        lines.append("## BLOCKERS & OPEN QUESTIONS")
        for b in blockers:
            lines.append("  ! {}".format(b))
        lines.append("")

    # Next step
    next_step = session.get("next_step", "")
    if next_step:
        lines.append("## EXACT NEXT STEP")
        lines.append("  >>> {}".format(next_step))
        lines.append("")

    lines.append("=" * 60)
    return "\n".join(lines)


def list_sessions(include_stale=False):
    # type: (bool) -> None
    """Print all available sessions."""
    sessions = find_sessions(include_stale=include_stale)
    if not sessions:
        print("No sessions found." + (" (use --stale to include old sessions)" if not include_stale else ""))
        return

    print("\nAvailable Sessions:")
    print("-" * 70)
    for filepath in sessions:
        try:
            session = load_session(filepath)
            name = session.get("name", "?")
            ts = session.get("timestamp", "?")[:19]
            system = session.get("system", "?")
            building = session.get("building", "?")[:40]
            print("  {} | {} | {} | {}".format(ts, system, name, building))
        except (json.JSONDecodeError, IOError):
            print("  [corrupt] {}".format(os.path.basename(filepath)))
    print("")


def main():
    parser = argparse.ArgumentParser(description="Mesh Session Save/Resume")
    sub = parser.add_subparsers(dest="command")

    # Save
    save_p = sub.add_parser("save", help="Save current session state")
    save_p.add_argument("--name", required=True, help="Session name")
    save_p.add_argument("--building", required=True, help="What we're building")
    save_p.add_argument("--system", default="claude-code", help="System used")
    save_p.add_argument("--next-step", default="", help="Exact next step")
    save_p.add_argument("--json-data", help="Full session data as JSON string")

    # Resume
    resume_p = sub.add_parser("resume", help="Resume a session")
    resume_p.add_argument("--name", help="Session name filter")
    resume_p.add_argument("--date", help="Date filter (YYYY-MM-DD)")
    resume_p.add_argument("--path", help="Explicit session file path")
    resume_p.add_argument("--json", action="store_true", help="JSON output")

    # List
    list_p = sub.add_parser("list", help="List available sessions")
    list_p.add_argument("--stale", action="store_true", help="Include >7 day old sessions")

    args = parser.parse_args()

    if args.command == "save":
        if args.json_data:
            data = json.loads(args.json_data)
        else:
            data = {
                "worked": [],
                "not_worked": [],
                "not_tried": [],
                "file_states": [],
                "decisions": [],
                "blockers": [],
            }

        filepath = save_session(
            name=args.name,
            building=args.building,
            worked=data.get("worked", []),
            not_worked=data.get("not_worked", []),
            not_tried=data.get("not_tried", []),
            file_states=data.get("file_states", []),
            decisions=data.get("decisions", []),
            blockers=data.get("blockers", []),
            next_step=args.next_step,
            system_used=args.system,
        )
        print("Session saved: {}".format(filepath))

    elif args.command == "resume":
        if args.path:
            filepath = args.path
        else:
            sessions = find_sessions(name=args.name, date=args.date, include_stale=True)
            if not sessions:
                print("No matching sessions found.")
                sys.exit(1)
            filepath = sessions[0]  # Most recent

        session = load_session(filepath)
        if args.json:
            print(json.dumps(session, indent=2))
        else:
            print(format_briefing(session))

    elif args.command == "list":
        list_sessions(include_stale=args.stale)

    else:
        parser.print_help()


if __name__ == "__main__":
    main()
