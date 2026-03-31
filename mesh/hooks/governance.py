#!/usr/bin/env python3
"""
Governance Event Capture Hook
Adapted from ECC governance-capture.js

Detects governance-relevant events and emits structured logs:
- secret_detected: Hardcoded secrets in tool input/output
- policy_violation: Actions that violate configured policies
- security_finding: Security-relevant tool invocations
- approval_requested: Operations requiring explicit approval
"""

import hashlib
import json
import os
import re
import time
from datetime import datetime
from pathlib import Path
from typing import Any, Dict, List, Optional

GOVERNANCE_LOG = Path.home() / ".openclaw" / "workspace" / "mesh" / "governance-events.jsonl"

# Patterns that indicate potential hardcoded secrets
SECRET_PATTERNS = [
    ("aws_key", re.compile(r"(?:AKIA|ASIA)[A-Z0-9]{16}", re.IGNORECASE)),
    ("generic_secret", re.compile(
        r'(?:secret|password|token|api[_\-]?key)\s*[:=]\s*["\'][^"\']{8,}', re.IGNORECASE
    )),
    ("private_key", re.compile(r"-----BEGIN (?:RSA |EC |DSA )?PRIVATE KEY-----")),
    ("jwt", re.compile(r"eyJ[A-Za-z0-9_-]{10,}\.eyJ[A-Za-z0-9_-]{10,}\.[A-Za-z0-9_-]{10,}")),
    ("github_token", re.compile(r"gh[pousr]_[A-Za-z0-9_]{36,}")),
]

# Tool names that represent security-relevant operations
SECURITY_RELEVANT_TOOLS = {"Bash"}

# Commands that require governance approval
APPROVAL_COMMANDS = [
    re.compile(r"git\s+push\s+.*--force"),
    re.compile(r"git\s+reset\s+--hard"),
    re.compile(r"rm\s+-rf?\s"),
    re.compile(r"DROP\s+(?:TABLE|DATABASE)", re.IGNORECASE),
    re.compile(r"DELETE\s+FROM\s+\w+\s*(?:;|$)", re.IGNORECASE),
]

# File patterns that indicate policy-sensitive paths
SENSITIVE_PATHS = [
    re.compile(r"\.env(?:\.|$)"),
    re.compile(r"credentials", re.IGNORECASE),
    re.compile(r"secrets?\.", re.IGNORECASE),
    re.compile(r"\.pem$"),
    re.compile(r"\.key$"),
    re.compile(r"id_rsa"),
]


def _generate_event_id() -> str:
    """Generate a unique governance event ID."""
    ts = int(time.time() * 1000)
    rand = hashlib.md5(os.urandom(8)).hexdigest()[:8]
    return "gov-{}-{}".format(ts, rand)


def detect_secrets(text: str) -> List[Dict[str, str]]:
    """Scan text for hardcoded secrets. Returns list of findings."""
    if not text or not isinstance(text, str):
        return []

    findings = []
    for name, pattern in SECRET_PATTERNS:
        if pattern.search(text):
            findings.append({"name": name})
    return findings


def detect_approval_required(command: str) -> List[Dict[str, str]]:
    """Check if a command requires governance approval."""
    if not command or not isinstance(command, str):
        return []

    findings = []
    for pattern in APPROVAL_COMMANDS:
        if pattern.search(command):
            findings.append({"pattern": pattern.pattern})
    return findings


def detect_sensitive_path(file_path: str) -> bool:
    """Check if a file path is policy-sensitive."""
    if not file_path or not isinstance(file_path, str):
        return False
    return any(p.search(file_path) for p in SENSITIVE_PATHS)


def _emit_event(event: Dict[str, Any]) -> None:
    """Write a governance event to the log file."""
    try:
        GOVERNANCE_LOG.parent.mkdir(parents=True, exist_ok=True)
        with open(GOVERNANCE_LOG, "a") as f:
            f.write(json.dumps(event) + "\n")
    except OSError:
        pass


def analyze_governance(
    tool_name: str = "",
    tool_input: Optional[Dict[str, Any]] = None,
    tool_output: str = "",
    session_id: Optional[str] = None,
    hook_phase: str = "pre",
) -> List[Dict[str, Any]]:
    """
    Analyze a tool invocation for governance-relevant events.

    Args:
        tool_name: Name of the tool being invoked.
        tool_input: Tool input parameters dict.
        tool_output: Tool output string (for post-hook analysis).
        session_id: Session identifier for correlation.
        hook_phase: 'pre' or 'post'.

    Returns:
        List of governance event dicts that were detected and logged.
    """
    if tool_input is None:
        tool_input = {}

    events = []

    # 1. Secret detection in tool input content
    input_text = json.dumps(tool_input) if isinstance(tool_input, dict) else str(tool_input)
    input_secrets = detect_secrets(input_text)
    output_secrets = detect_secrets(tool_output)
    all_secrets = input_secrets + output_secrets

    if all_secrets:
        event = {
            "id": _generate_event_id(),
            "timestamp": datetime.now().isoformat(),
            "session_id": session_id,
            "event_type": "secret_detected",
            "payload": {
                "tool_name": tool_name,
                "hook_phase": hook_phase,
                "secret_types": [s["name"] for s in all_secrets],
                "location": "input" if input_secrets else "output",
                "severity": "critical",
            },
        }
        events.append(event)
        _emit_event(event)

    # 2. Approval-required commands (Bash only)
    if tool_name == "Bash":
        command = tool_input.get("command", "")
        approval_findings = detect_approval_required(command)

        if approval_findings:
            cmd_parts = command.strip().split()
            event = {
                "id": _generate_event_id(),
                "timestamp": datetime.now().isoformat(),
                "session_id": session_id,
                "event_type": "approval_requested",
                "payload": {
                    "tool_name": tool_name,
                    "hook_phase": hook_phase,
                    "command_name": cmd_parts[0] if cmd_parts else None,
                    "matched_patterns": [f["pattern"] for f in approval_findings],
                    "severity": "high",
                },
            }
            events.append(event)
            _emit_event(event)

    # 3. Policy violation: writing to sensitive paths
    file_path = tool_input.get("file_path", tool_input.get("path", ""))
    if file_path and detect_sensitive_path(file_path):
        event = {
            "id": _generate_event_id(),
            "timestamp": datetime.now().isoformat(),
            "session_id": session_id,
            "event_type": "policy_violation",
            "payload": {
                "tool_name": tool_name,
                "hook_phase": hook_phase,
                "file_path": file_path[:200],
                "reason": "sensitive_file_access",
                "severity": "warning",
            },
        }
        events.append(event)
        _emit_event(event)

    # 4. Security-relevant tool usage (post-hook only)
    if tool_name in SECURITY_RELEVANT_TOOLS and hook_phase == "post":
        command = tool_input.get("command", "")
        has_elevated = bool(re.search(r"sudo\s|chmod\s|chown\s", command))

        if has_elevated:
            cmd_parts = command.strip().split()
            event = {
                "id": _generate_event_id(),
                "timestamp": datetime.now().isoformat(),
                "session_id": session_id,
                "event_type": "security_finding",
                "payload": {
                    "tool_name": tool_name,
                    "hook_phase": hook_phase,
                    "command_name": cmd_parts[0] if cmd_parts else None,
                    "reason": "elevated_privilege_command",
                    "severity": "medium",
                },
            }
            events.append(event)
            _emit_event(event)

    return events


def get_recent_events(limit: int = 50) -> List[Dict[str, Any]]:
    """Read recent governance events from the log."""
    events = []
    if not GOVERNANCE_LOG.exists():
        return events

    try:
        with open(GOVERNANCE_LOG) as f:
            for line in f:
                line = line.strip()
                if line:
                    try:
                        events.append(json.loads(line))
                    except json.JSONDecodeError:
                        continue
    except OSError:
        pass

    return events[-limit:]


def get_critical_events(limit: int = 20) -> List[Dict[str, Any]]:
    """Get only critical/high severity governance events."""
    all_events = get_recent_events(limit=200)
    return [
        e for e in all_events
        if e.get("payload", {}).get("severity") in ("critical", "high")
    ][-limit:]


if __name__ == "__main__":
    import sys

    # Gate on feature flag
    if os.environ.get("MESH_GOVERNANCE_CAPTURE", "").lower() != "1":
        raw = sys.stdin.read(1024 * 1024)
        sys.stdout.write(raw)
        sys.exit(0)

    raw = sys.stdin.read(1024 * 1024)
    try:
        data = json.loads(raw) if raw.strip() else {}
        session_id = os.environ.get("MESH_SESSION_ID")
        hook_phase = os.environ.get("CLAUDE_HOOK_EVENT_NAME", "unknown")
        phase = "pre" if hook_phase.startswith("Pre") else "post"

        events = analyze_governance(
            tool_name=data.get("tool_name", ""),
            tool_input=data.get("tool_input", {}),
            tool_output=data.get("tool_output", ""),
            session_id=session_id,
            hook_phase=phase,
        )

        if events:
            for event in events:
                sys.stderr.write("[governance] {}\n".format(json.dumps(event)))
    except Exception:
        pass

    sys.stdout.write(raw)
