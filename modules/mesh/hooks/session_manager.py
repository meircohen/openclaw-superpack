#!/usr/bin/env python3
"""
Session Manager Hook
Adapted from ECC session-start.js, session-end.js, session-end-marker.js, pre-compact.js

Manages session lifecycle:
- on_session_start(): Load previous session context
- on_session_end(): Save session summary with what worked, what didn't, what's left
- on_pre_compact(): Save current state before context compaction

Session files are stored as JSON in ~/.openclaw/workspace/mesh/sessions/
"""

import json
import os
import subprocess
from datetime import datetime
from pathlib import Path
from typing import Any, Dict, List, Optional

SESSIONS_DIR = Path.home() / ".openclaw" / "workspace" / "mesh" / "sessions"
MAX_AGE_DAYS = 7


def _ensure_dir(dir_path: Path) -> None:
    """Create directory if it doesn't exist."""
    dir_path.mkdir(parents=True, exist_ok=True)


def _get_session_id() -> str:
    """Get session ID from environment or generate a short one."""
    sid = os.environ.get("CLAUDE_SESSION_ID", "")
    if sid:
        return sid[:12]
    return datetime.now().strftime("%H%M%S")


def _get_date_string() -> str:
    """Get current date as YYYY-MM-DD."""
    return datetime.now().strftime("%Y-%m-%d")


def _get_project_name() -> str:
    """Get project name from git or cwd."""
    try:
        result = subprocess.run(
            ["git", "rev-parse", "--show-toplevel"],
            capture_output=True, text=True, timeout=5,
        )
        if result.returncode == 0:
            return os.path.basename(result.stdout.strip())
    except Exception:
        pass
    return os.path.basename(os.getcwd())


def _get_branch() -> str:
    """Get current git branch."""
    try:
        result = subprocess.run(
            ["git", "rev-parse", "--abbrev-ref", "HEAD"],
            capture_output=True, text=True, timeout=5,
        )
        if result.returncode == 0:
            return result.stdout.strip()
    except Exception:
        pass
    return "unknown"


def _find_recent_sessions(max_age_days: int = MAX_AGE_DAYS) -> List[Path]:
    """Find session files from the last N days, sorted newest first."""
    if not SESSIONS_DIR.exists():
        return []

    import time
    cutoff = time.time() - (max_age_days * 86400)
    sessions = []

    for f in SESSIONS_DIR.glob("*-session.json"):
        try:
            if f.stat().st_mtime >= cutoff:
                sessions.append(f)
        except OSError:
            continue

    sessions.sort(key=lambda p: p.stat().st_mtime, reverse=True)
    return sessions


def on_session_start(session_id: Optional[str] = None) -> Dict[str, Any]:
    """
    Load previous session context on new session start.

    Returns a dict with:
    - previous_session: contents of the most recent session file, or None
    - session_count: number of recent sessions found
    - session_file: path to the current session file
    """
    _ensure_dir(SESSIONS_DIR)

    if session_id is None:
        session_id = _get_session_id()

    today = _get_date_string()
    session_file = SESSIONS_DIR / "{}-{}-session.json".format(today, session_id)

    recent = _find_recent_sessions()
    previous_session = None

    if recent:
        latest = recent[0]
        try:
            with open(latest) as f:
                previous_session = json.load(f)
        except (json.JSONDecodeError, OSError):
            pass

    # Create initial session file
    session_data = {
        "session_id": session_id,
        "started_at": datetime.now().isoformat(),
        "last_updated": datetime.now().isoformat(),
        "project": _get_project_name(),
        "branch": _get_branch(),
        "worktree": os.getcwd(),
        "files_modified": [],
        "tools_used": [],
        "user_messages": [],
        "summary": "",
        "status": "active",
    }

    try:
        with open(session_file, "w") as f:
            json.dump(session_data, f, indent=2)
    except OSError:
        pass

    return {
        "previous_session": previous_session,
        "session_count": len(recent),
        "session_file": str(session_file),
    }


def on_session_end(
    session_id: Optional[str] = None,
    files_modified: Optional[List[str]] = None,
    tools_used: Optional[List[str]] = None,
    user_messages: Optional[List[str]] = None,
    summary: str = "",
    what_worked: str = "",
    what_didnt: str = "",
    whats_left: str = "",
) -> Dict[str, Any]:
    """
    Save session summary at session end.

    Args:
        session_id: Session identifier.
        files_modified: List of files modified during the session.
        tools_used: List of tools used.
        user_messages: List of user messages (last 10 kept).
        summary: Brief summary of work done.
        what_worked: What approaches worked well.
        what_didnt: What approaches failed.
        whats_left: What remains to be done.

    Returns the saved session data dict.
    """
    _ensure_dir(SESSIONS_DIR)

    if session_id is None:
        session_id = _get_session_id()

    today = _get_date_string()
    session_file = SESSIONS_DIR / "{}-{}-session.json".format(today, session_id)

    # Load existing session data if it exists
    session_data = {}
    if session_file.exists():
        try:
            with open(session_file) as f:
                session_data = json.load(f)
        except (json.JSONDecodeError, OSError):
            pass

    # Update session data
    session_data.update({
        "session_id": session_id,
        "last_updated": datetime.now().isoformat(),
        "ended_at": datetime.now().isoformat(),
        "project": session_data.get("project", _get_project_name()),
        "branch": session_data.get("branch", _get_branch()),
        "worktree": session_data.get("worktree", os.getcwd()),
        "files_modified": list(set(
            session_data.get("files_modified", []) + (files_modified or [])
        ))[:30],
        "tools_used": list(set(
            session_data.get("tools_used", []) + (tools_used or [])
        ))[:20],
        "user_messages": (
            session_data.get("user_messages", []) + (user_messages or [])
        )[-10:],
        "summary": summary or session_data.get("summary", ""),
        "what_worked": what_worked,
        "what_didnt": what_didnt,
        "whats_left": whats_left,
        "status": "completed",
    })

    try:
        with open(session_file, "w") as f:
            json.dump(session_data, f, indent=2)
    except OSError:
        pass

    return session_data


def on_pre_compact(session_id: Optional[str] = None) -> Dict[str, Any]:
    """
    Save current state before context compaction.

    Logs the compaction event and appends a marker to the active session file.

    Returns dict with compaction timestamp and session file path.
    """
    _ensure_dir(SESSIONS_DIR)

    if session_id is None:
        session_id = _get_session_id()

    timestamp = datetime.now().isoformat()

    # Log compaction event
    compaction_log = SESSIONS_DIR / "compaction-log.txt"
    try:
        with open(compaction_log, "a") as f:
            f.write("[{}] Context compaction triggered\n".format(timestamp))
    except OSError:
        pass

    # Find and update active session file
    today = _get_date_string()
    session_file = SESSIONS_DIR / "{}-{}-session.json".format(today, session_id)

    if session_file.exists():
        try:
            with open(session_file) as f:
                session_data = json.load(f)

            compactions = session_data.get("compactions", [])
            compactions.append(timestamp)
            session_data["compactions"] = compactions
            session_data["last_updated"] = timestamp

            with open(session_file, "w") as f:
                json.dump(session_data, f, indent=2)
        except (json.JSONDecodeError, OSError):
            pass

    return {
        "timestamp": timestamp,
        "session_file": str(session_file),
    }


if __name__ == "__main__":
    import sys

    action = sys.argv[1] if len(sys.argv) > 1 else "start"
    sid = os.environ.get("CLAUDE_SESSION_ID", None)

    if action == "start":
        result = on_session_start(session_id=sid)
        print(json.dumps(result, indent=2))
    elif action == "end":
        result = on_session_end(session_id=sid)
        print(json.dumps(result, indent=2))
    elif action == "compact":
        result = on_pre_compact(session_id=sid)
        print(json.dumps(result, indent=2))
    else:
        print("Usage: session_manager.py [start|end|compact]")
