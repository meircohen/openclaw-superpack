#!/usr/bin/env python3
"""
Desktop Notification Hook
Adapted from ECC desktop-notify.js

Sends a native desktop notification when Claude finishes responding.
- macOS: uses osascript
- Linux: uses notify-send

Platform detection is done at import time for efficiency.
"""

import os
import platform
import subprocess
import sys
from typing import Optional

TITLE = "Claude Code"
MAX_BODY_LENGTH = 100

# Detect platform at module level
_PLATFORM = platform.system().lower()
IS_MACOS = _PLATFORM == "darwin"
IS_LINUX = _PLATFORM == "linux"


def _notify_macos(title: str, body: str) -> bool:
    """
    Send a macOS notification via osascript.

    AppleScript strings don't support backslash escapes, so we replace
    double quotes with curly quotes and strip backslashes.
    """
    safe_body = body.replace("\\", "").replace('"', "\u201C")
    safe_title = title.replace("\\", "").replace('"', "\u201C")
    script = 'display notification "{}" with title "{}"'.format(safe_body, safe_title)

    try:
        result = subprocess.run(
            ["osascript", "-e", script],
            capture_output=True,
            timeout=5,
        )
        return result.returncode == 0
    except Exception:
        return False


def _notify_linux(title: str, body: str) -> bool:
    """Send a Linux notification via notify-send."""
    try:
        result = subprocess.run(
            ["notify-send", title, body],
            capture_output=True,
            timeout=5,
        )
        return result.returncode == 0
    except FileNotFoundError:
        return False
    except Exception:
        return False


def _extract_summary(message: Optional[str]) -> str:
    """
    Extract a short summary from the last assistant message.
    Takes the first non-empty line and truncates to MAX_BODY_LENGTH chars.
    """
    if not message or not isinstance(message, str):
        return "Done"

    for line in message.split("\n"):
        stripped = line.strip()
        if stripped:
            if len(stripped) > MAX_BODY_LENGTH:
                return stripped[:MAX_BODY_LENGTH] + "..."
            return stripped

    return "Done"


def send_notification(
    message: Optional[str] = None,
    title: str = TITLE,
) -> bool:
    """
    Send a desktop notification.

    Args:
        message: The message body. If None or empty, shows "Done".
        title: Notification title (default: "Claude Code").

    Returns:
        True if notification was sent successfully, False otherwise.
    """
    body = _extract_summary(message)

    if IS_MACOS:
        return _notify_macos(title, body)
    elif IS_LINUX:
        return _notify_linux(title, body)

    # Unsupported platform
    return False


def send_notification_from_input(data: dict) -> bool:
    """Send notification from a hook input dict."""
    message = data.get("last_assistant_message", "")
    return send_notification(message=message)


if __name__ == "__main__":
    import json

    raw = sys.stdin.read(1024 * 1024)
    try:
        data = json.loads(raw) if raw.strip() else {}
        send_notification_from_input(data)
    except Exception:
        pass

    if raw:
        sys.stdout.write(raw)
