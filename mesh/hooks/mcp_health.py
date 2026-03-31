#!/usr/bin/env python3
"""
MCP Health Check Hook
Adapted from ECC mcp-health-check.js

Probes MCP server health before tool execution.
Features:
- Cached health state with TTL
- Exponential backoff on failures
- Fail-open mode for unavailable servers
- HTTP and command-based server probes
"""

import json
import os
import subprocess
import time
import urllib.request
import urllib.error
from pathlib import Path
from typing import Any, Dict, Optional, Tuple

DEFAULT_TTL_S = 120  # 2 minutes
DEFAULT_TIMEOUT_S = 5
DEFAULT_BACKOFF_S = 30
MAX_BACKOFF_S = 600  # 10 minutes

HEALTHY_HTTP_CODES = {200, 201, 202, 204, 301, 302, 303, 304, 307, 308, 405}

STATE_FILE = Path.home() / ".openclaw" / "workspace" / "mesh" / "mcp-health-cache.json"


def _load_state(state_file: Optional[Path] = None) -> Dict[str, Any]:
    """Load health state from disk."""
    path = state_file or STATE_FILE
    try:
        with open(path) as f:
            data = json.load(f)
            if isinstance(data, dict) and "servers" in data:
                return data
    except (json.JSONDecodeError, OSError):
        pass
    return {"version": 1, "servers": {}}


def _save_state(state: Dict[str, Any], state_file: Optional[Path] = None) -> None:
    """Save health state to disk."""
    path = state_file or STATE_FILE
    try:
        path.parent.mkdir(parents=True, exist_ok=True)
        with open(path, "w") as f:
            json.dump(state, f, indent=2)
    except OSError:
        pass


def _mark_healthy(
    state: Dict[str, Any],
    server_name: str,
    now: float,
    ttl_s: int = DEFAULT_TTL_S,
    details: Optional[Dict] = None,
) -> None:
    """Mark a server as healthy in the state."""
    entry = {
        "status": "healthy",
        "checked_at": now,
        "expires_at": now + ttl_s,
        "failure_count": 0,
        "last_error": None,
        "next_retry_at": now,
    }
    if details:
        entry.update(details)
    state["servers"][server_name] = entry


def _mark_unhealthy(
    state: Dict[str, Any],
    server_name: str,
    now: float,
    error_message: str = "",
    backoff_s: int = DEFAULT_BACKOFF_S,
) -> None:
    """Mark a server as unhealthy with exponential backoff."""
    previous = state["servers"].get(server_name, {})
    failure_count = int(previous.get("failure_count", 0)) + 1
    delay = min(backoff_s * (2 ** max(failure_count - 1, 0)), MAX_BACKOFF_S)

    state["servers"][server_name] = {
        "status": "unhealthy",
        "checked_at": now,
        "expires_at": now,
        "failure_count": failure_count,
        "last_error": error_message[:500] if error_message else None,
        "next_retry_at": now + delay,
    }


def _probe_http(url: str, timeout_s: int = DEFAULT_TIMEOUT_S) -> Tuple[bool, str]:
    """Probe an HTTP server. Returns (ok, reason)."""
    try:
        req = urllib.request.Request(url, method="GET")
        resp = urllib.request.urlopen(req, timeout=timeout_s)
        code = resp.getcode()
        if code in HEALTHY_HTTP_CODES:
            return True, "HTTP {}".format(code)
        return False, "HTTP {}".format(code)
    except urllib.error.HTTPError as e:
        code = e.code
        if code in HEALTHY_HTTP_CODES:
            return True, "HTTP {}".format(code)
        return False, "HTTP {}".format(code)
    except urllib.error.URLError as e:
        return False, str(e.reason)
    except Exception as e:
        return False, str(e)


def _probe_command(
    command: str,
    args: Optional[list] = None,
    env: Optional[Dict[str, str]] = None,
    timeout_s: int = DEFAULT_TIMEOUT_S,
) -> Tuple[bool, str]:
    """
    Probe a command-based MCP server.
    If the process starts and survives the timeout, it's considered healthy
    (stdio servers stay alive waiting for input).
    """
    merged_env = os.environ.copy()
    if env:
        merged_env.update(env)

    cmd = [command] + (args or [])

    try:
        proc = subprocess.Popen(
            cmd,
            stdin=subprocess.PIPE,
            stdout=subprocess.DEVNULL,
            stderr=subprocess.PIPE,
            env=merged_env,
        )

        try:
            _, stderr = proc.communicate(timeout=timeout_s)
            # Process exited before timeout - likely an error
            return False, (stderr.decode("utf-8", errors="replace").strip()[:500]
                           or "process exited with code {}".format(proc.returncode))
        except subprocess.TimeoutExpired:
            # Process is still running - healthy (stdio server)
            proc.kill()
            proc.wait()
            return True, "server accepted stdio connection"

    except FileNotFoundError:
        return False, "command not found: {}".format(command)
    except Exception as e:
        return False, str(e)


def _should_fail_open() -> bool:
    """Check if fail-open mode is enabled."""
    return os.environ.get("MESH_MCP_HEALTH_FAIL_OPEN", "").lower() in ("1", "true", "yes")


def _extract_mcp_target(tool_name: str) -> Optional[Tuple[str, str]]:
    """
    Extract MCP server name and tool from a tool_name like 'mcp__server__tool'.
    Returns (server_name, tool_name) or None.
    """
    if not tool_name.startswith("mcp__"):
        return None

    segments = tool_name[5:].split("__", 1)
    if len(segments) < 2 or not segments[0]:
        return None

    return segments[0], segments[1]


def check_mcp_health(
    server_name: str,
    server_config: Optional[Dict[str, Any]] = None,
    tool_name: str = "",
    state_file: Optional[Path] = None,
) -> Dict[str, Any]:
    """
    Check health of an MCP server before tool execution.

    Args:
        server_name: Name of the MCP server.
        server_config: Server configuration dict with 'url' or 'command' key.
        tool_name: Name of the tool being invoked.
        state_file: Optional custom state file path.

    Returns:
        Dict with 'healthy' (bool), 'reason' (str), 'action' ('allow' or 'block').
    """
    now = time.time()
    state = _load_state(state_file)
    previous = state["servers"].get(server_name, {})

    # Check cached healthy state
    if previous.get("status") == "healthy" and float(previous.get("expires_at", 0)) > now:
        return {"healthy": True, "reason": "cached healthy", "action": "allow"}

    # Check backoff period
    if previous.get("status") == "unhealthy" and float(previous.get("next_retry_at", 0)) > now:
        action = "allow" if _should_fail_open() else "block"
        return {
            "healthy": False,
            "reason": "unhealthy, in backoff until {}".format(
                time.strftime("%H:%M:%S", time.localtime(previous["next_retry_at"]))
            ),
            "action": action,
        }

    # No config means we can't probe - allow by default
    if not server_config:
        return {"healthy": True, "reason": "no config available, allowing", "action": "allow"}

    # Probe the server
    if server_config.get("url"):
        ok, reason = _probe_http(server_config["url"])
    elif server_config.get("command"):
        ok, reason = _probe_command(
            server_config["command"],
            args=server_config.get("args"),
            env=server_config.get("env"),
        )
    else:
        return {"healthy": True, "reason": "unsupported config type", "action": "allow"}

    if ok:
        _mark_healthy(state, server_name, now)
        _save_state(state, state_file)
        return {"healthy": True, "reason": reason, "action": "allow"}

    _mark_unhealthy(state, server_name, now, error_message=reason)
    _save_state(state, state_file)

    action = "allow" if _should_fail_open() else "block"
    return {"healthy": False, "reason": reason, "action": action}


def get_server_status(
    server_name: str,
    state_file: Optional[Path] = None,
) -> Optional[Dict[str, Any]]:
    """Get cached health status for a server without probing."""
    state = _load_state(state_file)
    return state["servers"].get(server_name)


def clear_health_cache(state_file: Optional[Path] = None) -> None:
    """Clear all cached health state."""
    path = state_file or STATE_FILE
    try:
        if path.exists():
            path.unlink()
    except OSError:
        pass


if __name__ == "__main__":
    import sys

    raw = sys.stdin.read(1024 * 1024)
    try:
        data = json.loads(raw) if raw.strip() else {}
        tool_name = data.get("tool_name", data.get("name", ""))

        target = _extract_mcp_target(tool_name)
        if not target:
            sys.stdout.write(raw)
            sys.exit(0)

        server_name, mcp_tool = target
        result = check_mcp_health(server_name, tool_name=mcp_tool)

        if result["action"] == "block":
            sys.stderr.write(
                "[MCPHealthCheck] {} is unavailable ({}). "
                "Blocking {} so Claude can fall back.\n".format(
                    server_name, result["reason"], mcp_tool
                )
            )
            sys.exit(2)

        sys.stdout.write(raw)
    except Exception:
        sys.stdout.write(raw)
