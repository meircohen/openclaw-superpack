#!/usr/bin/env python3
"""
Strategic Compact Suggester Hook
Adapted from ECC suggest-compact.js

Tracks tool call count and suggests manual compaction at logical intervals.

Why manual over auto-compact:
- Auto-compact happens at arbitrary points, often mid-task
- Strategic compacting preserves context through logical phases
- Compact after exploration, before execution
- Compact after completing a milestone, before starting next
"""

import os
import tempfile
from pathlib import Path
from typing import Optional

DEFAULT_THRESHOLD = 50
INTERVAL_AFTER_THRESHOLD = 25


def _get_counter_file(session_id: str = "default") -> Path:
    """Get path to the session-specific counter file."""
    # Sanitize session ID for filename
    safe_id = "".join(c for c in session_id if c.isalnum() or c in "-_") or "default"
    return Path(tempfile.gettempdir()) / "mesh-tool-count-{}".format(safe_id)


def check_compact_suggestion(
    session_id: Optional[str] = None,
    threshold: Optional[int] = None,
) -> Optional[str]:
    """
    Increment the tool call counter and return a suggestion message
    when compaction might be beneficial.

    Args:
        session_id: Session identifier. Falls back to CLAUDE_SESSION_ID env var.
        threshold: Number of tool calls before first suggestion. Defaults to 50.

    Returns:
        A suggestion message string, or None if no suggestion is needed.
    """
    if session_id is None:
        session_id = os.environ.get("CLAUDE_SESSION_ID", "default")

    if threshold is None:
        raw = os.environ.get("COMPACT_THRESHOLD", str(DEFAULT_THRESHOLD))
        try:
            threshold = int(raw)
            if threshold <= 0 or threshold > 10000:
                threshold = DEFAULT_THRESHOLD
        except ValueError:
            threshold = DEFAULT_THRESHOLD

    counter_file = _get_counter_file(session_id)
    count = 1

    try:
        if counter_file.exists():
            raw_count = counter_file.read_text().strip()
            parsed = int(raw_count)
            if 0 < parsed <= 1_000_000:
                count = parsed + 1
            else:
                count = 1
    except (ValueError, OSError):
        count = 1

    try:
        counter_file.write_text(str(count))
    except OSError:
        pass

    # Suggest at threshold
    if count == threshold:
        return (
            "[StrategicCompact] {} tool calls reached - "
            "consider /compact if transitioning phases"
        ).format(threshold)

    # Suggest at regular intervals after threshold
    if count > threshold and (count - threshold) % INTERVAL_AFTER_THRESHOLD == 0:
        return (
            "[StrategicCompact] {} tool calls - "
            "good checkpoint for /compact if context is stale"
        ).format(count)

    return None


def get_tool_count(session_id: Optional[str] = None) -> int:
    """Get the current tool call count without incrementing."""
    if session_id is None:
        session_id = os.environ.get("CLAUDE_SESSION_ID", "default")

    counter_file = _get_counter_file(session_id)
    try:
        if counter_file.exists():
            raw = counter_file.read_text().strip()
            parsed = int(raw)
            return parsed if 0 < parsed <= 1_000_000 else 0
    except (ValueError, OSError):
        pass
    return 0


def reset_counter(session_id: Optional[str] = None) -> None:
    """Reset the tool call counter for a session."""
    if session_id is None:
        session_id = os.environ.get("CLAUDE_SESSION_ID", "default")

    counter_file = _get_counter_file(session_id)
    try:
        if counter_file.exists():
            counter_file.unlink()
    except OSError:
        pass


if __name__ == "__main__":
    msg = check_compact_suggestion()
    if msg:
        import sys
        sys.stderr.write(msg + "\n")
