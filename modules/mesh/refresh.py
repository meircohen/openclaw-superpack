#!/usr/bin/env python3
"""
Auto-Capability Refresh — Weekly check of all mesh system capabilities.

Tests each system's tools, detects new MCP servers, finds degraded systems,
and auto-updates config YAML files.

Usage:
    python3 mesh/refresh.py              # Run full refresh
    python3 mesh/refresh.py --json       # JSON output
    python3 mesh/refresh.py --quick      # Quick connectivity check only
"""

from __future__ import annotations

import argparse
import json
import os
import re
import subprocess
import sys
from datetime import datetime
from pathlib import Path

MESH_DIR = Path(__file__).resolve().parent
CONFIG_DIR = MESH_DIR / "config"
HEALTH_STATUS_FILE = MESH_DIR / "health-status.json"
HEARTBEAT_FILE = MESH_DIR.parent / "HEARTBEAT.md"

HOME = Path.home()

CLI_PATHS = {
    "claude-code": "$HOME/.nvm/versions/node/v22.22.0/bin/claude",
    "codex": "$HOME/.nvm/versions/node/v22.22.0/bin/codex",
    "gemini": "$HOME/.nvm/versions/node/v22.22.0/bin/gemini",
}

TIMEOUT = 10


def run_cmd(cmd: list[str], timeout: int = TIMEOUT) -> tuple[bool, str]:
    """Run a command and return (success, output)."""
    try:
        result = subprocess.run(cmd, capture_output=True, text=True, timeout=timeout)
        output = (result.stdout or "") + (result.stderr or "")
        return result.returncode == 0, output.strip()
    except FileNotFoundError:
        return False, "binary not found"
    except subprocess.TimeoutExpired:
        return False, "timed out"
    except Exception as e:
        return False, str(e)


def check_cli_version(name: str) -> dict:
    """Check CLI version and availability."""
    path = CLI_PATHS.get(name)
    if not path:
        return {"name": name, "available": False, "error": "no CLI path configured"}

    ok, output = run_cmd([path, "--version"])
    return {
        "name": name,
        "available": ok,
        "version": output.splitlines()[0] if ok and output else None,
        "error": output if not ok else None,
    }


def detect_mcp_servers() -> list[dict]:
    """Detect MCP servers configured in Claude Code settings."""
    servers = []
    settings_path = HOME / ".claude" / "settings.json"
    if settings_path.exists():
        try:
            settings = json.loads(settings_path.read_text())
            mcp_config = settings.get("mcpServers", {})
            for name, config in mcp_config.items():
                servers.append({
                    "name": name,
                    "command": config.get("command", "unknown"),
                    "args": config.get("args", []),
                })
        except (json.JSONDecodeError, OSError):
            pass

    # Also check project-level settings
    for project_settings in HOME.glob(".claude/projects/*/settings.json"):
        try:
            settings = json.loads(project_settings.read_text())
            mcp_config = settings.get("mcpServers", {})
            for name, config in mcp_config.items():
                if not any(s["name"] == name for s in servers):
                    servers.append({
                        "name": name,
                        "command": config.get("command", "unknown"),
                        "args": config.get("args", []),
                        "project_level": True,
                    })
        except (json.JSONDecodeError, OSError):
            continue

    return servers


def check_api_keys() -> dict[str, bool]:
    """Check which API keys are set."""
    keys = ["ANTHROPIC_API_KEY", "GEMINI_API_KEY", "PERPLEXITY_API_KEY", "OPENAI_API_KEY"]
    return {k: bool(os.environ.get(k)) for k in keys}


def check_openclaw() -> dict:
    """Check OpenClaw gateway health."""
    import urllib.request
    import urllib.error

    try:
        req = urllib.request.Request("http://localhost:18789/health", method="GET")
        with urllib.request.urlopen(req, timeout=5) as resp:
            return {"available": True, "status_code": resp.getcode()}
    except Exception as e:
        return {"available": False, "error": str(e)}


def check_perplexity() -> dict:
    """Check Perplexity access methods."""
    result = {
        "browser_script": (MESH_DIR.parent / "scripts" / "perplexity_uc.py").exists(),
        "api_key": bool(os.environ.get("PERPLEXITY_API_KEY")),
        "mcp_available": False,
    }

    # Check if Perplexity MCP is configured
    settings_path = HOME / ".claude" / "settings.json"
    if settings_path.exists():
        try:
            settings = json.loads(settings_path.read_text())
            mcp = settings.get("mcpServers", {})
            result["mcp_available"] = "perplexity" in mcp or any("perplexity" in k.lower() for k in mcp)
        except (json.JSONDecodeError, OSError):
            pass

    return result


def load_previous_state() -> dict | None:
    """Load previous health status for comparison."""
    if HEALTH_STATUS_FILE.exists():
        try:
            return json.loads(HEALTH_STATUS_FILE.read_text())
        except (json.JSONDecodeError, OSError):
            pass
    return None


def detect_changes(current: dict, previous: dict | None) -> list[str]:
    """Detect changes between current and previous state."""
    changes = []
    if not previous:
        return ["First capability refresh — no previous state to compare"]

    prev_systems = {s["name"]: s for s in previous.get("systems", [])}

    for sys_info in current.get("systems", []):
        name = sys_info["name"]
        prev = prev_systems.get(name)
        if not prev:
            changes.append(f"NEW: {name} detected")
            continue
        if sys_info.get("online") and not prev.get("online"):
            changes.append(f"RECOVERED: {name} is back online")
        elif not sys_info.get("online") and prev.get("online"):
            changes.append(f"DEGRADED: {name} went offline")

    # Check for new MCP servers
    prev_mcp = set()
    curr_mcp = set()
    if previous:
        for s in previous.get("mcp_servers", []):
            prev_mcp.add(s.get("name", ""))
    for s in current.get("mcp_servers", []):
        curr_mcp.add(s.get("name", ""))

    new_mcp = curr_mcp - prev_mcp
    removed_mcp = prev_mcp - curr_mcp
    for m in new_mcp:
        changes.append(f"NEW MCP: {m} detected")
    for m in removed_mcp:
        changes.append(f"REMOVED MCP: {m} no longer configured")

    return changes


def update_config_yaml(system: str, status: dict) -> None:
    """Update a system's config YAML with refresh findings."""
    config_file = CONFIG_DIR / f"{system}.yaml"
    if not config_file.exists():
        return

    content = config_file.read_text()

    # Update last_refresh timestamp
    now_str = datetime.now().strftime("%Y-%m-%d %H:%M:%S")
    if "last_refresh:" in content:
        content = re.sub(r"last_refresh:.*", f"last_refresh: \"{now_str}\"", content)
    else:
        # Add before the last line
        content = content.rstrip() + f"\n\nlast_refresh: \"{now_str}\"\n"

    config_file.write_text(content)


def run_refresh(quick: bool = False) -> dict:
    """Run a full capability refresh."""
    result = {
        "timestamp": datetime.now().strftime("%Y-%m-%d %H:%M:%S"),
        "systems": [],
        "mcp_servers": [],
        "api_keys": {},
        "changes": [],
        "degraded": [],
        "recommendations": [],
    }

    # Check CLIs
    for name in ["claude-code", "codex", "gemini"]:
        cli = check_cli_version(name)
        result["systems"].append({
            "name": cli["name"],
            "online": cli["available"],
            "detail": cli.get("version") or cli.get("error", "unknown"),
        })
        if cli["available"]:
            update_config_yaml(name, cli)

    # Check OpenClaw
    oc = check_openclaw()
    result["systems"].append({
        "name": "OpenClaw",
        "online": oc["available"],
        "detail": f"HTTP {oc.get('status_code', 'N/A')}" if oc["available"] else oc.get("error", "offline"),
    })

    # Check Perplexity
    pplx = check_perplexity()
    pplx_online = pplx["browser_script"] or pplx["mcp_available"]
    detail_parts = []
    if pplx["browser_script"]:
        detail_parts.append("Browser \u2713")
    if pplx["mcp_available"]:
        detail_parts.append("MCP \u2713")
    if pplx["api_key"]:
        detail_parts.append("API \u2713")
    result["systems"].append({
        "name": "Perplexity",
        "online": pplx_online,
        "detail": " | ".join(detail_parts) if detail_parts else "No access methods available",
    })

    # MCP servers
    if not quick:
        result["mcp_servers"] = detect_mcp_servers()

    # API keys
    result["api_keys"] = check_api_keys()

    # Detect changes
    previous = load_previous_state()
    result["changes"] = detect_changes(result, previous)

    # Identify degraded systems
    for sys_info in result["systems"]:
        if not sys_info["online"]:
            result["degraded"].append(sys_info["name"])

    # Recommendations
    if result["degraded"]:
        result["recommendations"].append(
            f"Degraded systems: {', '.join(result['degraded'])} — check connectivity/auth"
        )

    expired_keys = [k for k, v in result["api_keys"].items() if not v]
    if expired_keys:
        result["recommendations"].append(
            f"Missing API keys: {', '.join(expired_keys)}"
        )

    # Save as new health status
    HEALTH_STATUS_FILE.write_text(json.dumps(result, indent=2) + "\n")

    return result


def format_human(result: dict) -> str:
    """Format refresh results for human reading."""
    lines = [
        "=== AI Mesh Capability Refresh ===",
        f"Timestamp: {result['timestamp']}",
        "",
        "Systems:",
    ]

    for sys_info in result["systems"]:
        status = "\u2713 ONLINE" if sys_info["online"] else "\u2717 OFFLINE"
        lines.append(f"  {sys_info['name']:<14} [{status}]  {sys_info['detail']}")

    if result.get("mcp_servers"):
        lines.append("")
        lines.append(f"MCP Servers ({len(result['mcp_servers'])}):")
        for srv in result["mcp_servers"]:
            scope = " (project)" if srv.get("project_level") else ""
            lines.append(f"  - {srv['name']}{scope}")

    lines.append("")
    lines.append("API Keys:")
    for key, available in result["api_keys"].items():
        mark = "\u2713" if available else "\u2717"
        lines.append(f"  {key:<24} [{mark}]")

    if result["changes"]:
        lines.append("")
        lines.append("Changes Detected:")
        for change in result["changes"]:
            lines.append(f"  - {change}")

    if result["recommendations"]:
        lines.append("")
        lines.append("Recommendations:")
        for rec in result["recommendations"]:
            lines.append(f"  \u26a0 {rec}")

    online = sum(1 for s in result["systems"] if s["online"])
    total = len(result["systems"])
    lines.append("")
    lines.append(f"Overall: {online}/{total} systems healthy")

    return "\n".join(lines)


def main() -> int:
    parser = argparse.ArgumentParser(description="AI Mesh Auto-Capability Refresh")
    parser.add_argument("--json", action="store_true", dest="json_output", help="JSON output")
    parser.add_argument("--quick", action="store_true", help="Quick connectivity check only")
    args = parser.parse_args()

    result = run_refresh(quick=args.quick)

    if args.json_output:
        print(json.dumps(result, indent=2))
    else:
        print(format_human(result))

    return 0


if __name__ == "__main__":
    sys.exit(main())
