#!/usr/bin/env python3
"""
Hook System for AI Mesh
Adapted from ECC cursor/kiro hooks framework.

Event-driven automation for mesh operations:
- Pre/post dispatch hooks (intercept before sending to systems)
- Pre/post tool hooks (quality gates before/after tool execution)
- Session hooks (start/end lifecycle)
- File hooks (auto-format, auto-lint on edit)
- Security hooks (secret scanning, dangerous command blocking)

Hooks are non-blocking by default (warn, don't block).
Exit code 2 = hard block.

Usage:
    python3 mesh/hooks.py register --event pre-dispatch --command "python3 mesh/intercept.py"
    python3 mesh/hooks.py register --event post-dispatch --command "python3 mesh/learn.py record"
    python3 mesh/hooks.py register --event pre-commit --command "python3 mesh/security_scan.py --pre-commit"
    python3 mesh/hooks.py fire pre-dispatch --context '{"task": "...", "system": "..."}'
    python3 mesh/hooks.py list
    python3 mesh/hooks.py disable --id hook-001
    python3 mesh/hooks.py enable --id hook-001
    python3 mesh/hooks.py profiles
"""

import argparse
import json
import os
import subprocess
import sys
import time
from datetime import datetime
from typing import Any, Dict, List, Optional

MESH_DIR = os.path.dirname(os.path.abspath(__file__))
HOOKS_FILE = os.path.join(MESH_DIR, "hooks.json")
HOOKS_LOG_FILE = os.path.join(MESH_DIR, "hooks-log.json")

# Hook profiles (ECC pattern: minimal/standard/strict)
PROFILES = {
    "minimal": {
        "description": "Only critical safety hooks",
        "events": ["pre-commit", "pre-push"],
    },
    "standard": {
        "description": "Safety + quality hooks",
        "events": ["pre-dispatch", "post-dispatch", "pre-commit", "pre-push",
                    "session-start", "session-end"],
    },
    "strict": {
        "description": "All hooks active, blocking on warnings",
        "events": ["pre-dispatch", "post-dispatch", "pre-commit", "pre-push",
                    "session-start", "session-end", "pre-tool", "post-tool",
                    "file-edit", "checkpoint"],
    },
}

# Available hook events
EVENTS = [
    "pre-dispatch",    # Before routing task to a system
    "post-dispatch",   # After system returns result
    "pre-commit",      # Before git commit
    "pre-push",        # Before git push
    "session-start",   # Session initialization
    "session-end",     # Session shutdown
    "pre-tool",        # Before tool execution (any system)
    "post-tool",       # After tool execution
    "file-edit",       # After file modification
    "checkpoint",      # At checkpoint creation
    "loop-iteration",  # Each loop cycle
    "cost-threshold",  # When cost exceeds threshold
]


def load_hooks():
    # type: () -> Dict[str, Any]
    """Load hooks configuration."""
    if not os.path.exists(HOOKS_FILE):
        return {"hooks": [], "profile": "standard", "disabled": []}
    try:
        with open(HOOKS_FILE) as f:
            return json.load(f)
    except (json.JSONDecodeError, IOError):
        return {"hooks": [], "profile": "standard", "disabled": []}


def save_hooks(config):
    # type: (Dict) -> None
    """Save hooks configuration."""
    with open(HOOKS_FILE, "w") as f:
        json.dump(config, f, indent=2)


def generate_hook_id(event, command):
    # type: (str, str) -> str
    """Generate a short hook ID."""
    import hashlib
    h = hashlib.md5("{}:{}".format(event, command).encode()).hexdigest()[:6]
    return "hook-{}".format(h)


def register_hook(event, command, description="", blocking=False, profile="standard"):
    # type: (str, str, str, bool, str) -> Dict
    """Register a new hook."""
    if event not in EVENTS:
        print("ERROR: Unknown event '{}'. Available: {}".format(event, ", ".join(EVENTS)))
        sys.exit(1)

    config = load_hooks()
    hook_id = generate_hook_id(event, command)

    # Check for duplicates
    for existing in config["hooks"]:
        if existing["id"] == hook_id:
            print("Hook already registered: {}".format(hook_id))
            return existing

    hook = {
        "id": hook_id,
        "event": event,
        "command": command,
        "description": description or "Hook for {} event".format(event),
        "blocking": blocking,  # If True, exit code 2 blocks the operation
        "profile": profile,    # Minimum profile to activate
        "created_at": datetime.now().isoformat(),
    }

    config["hooks"].append(hook)
    save_hooks(config)
    print("Hook registered: {} ({} -> {})".format(hook_id, event, command[:50]))
    return hook


def fire_hooks(event, context=None, profile=None):
    # type: (str, Optional[Dict], Optional[str]) -> List[Dict[str, Any]]
    """Fire all hooks for an event. Returns results."""
    config = load_hooks()
    active_profile = profile or config.get("profile", "standard")
    disabled = set(config.get("disabled", []))

    # Get hooks for this event
    applicable = []
    for hook in config["hooks"]:
        if hook["event"] != event:
            continue
        if hook["id"] in disabled:
            continue
        # Check profile level
        profile_order = ["minimal", "standard", "strict"]
        hook_profile = hook.get("profile", "standard")
        if profile_order.index(active_profile) < profile_order.index(hook_profile):
            continue
        applicable.append(hook)

    results = []
    for hook in applicable:
        result = execute_hook(hook, context)
        results.append(result)

        # Log execution
        log_hook_execution(hook, result)

        # Check for hard block
        if result.get("exit_code") == 2 and hook.get("blocking", False):
            print("BLOCKED by hook {}: {}".format(hook["id"], hook["description"]))
            break

    return results


def execute_hook(hook, context=None):
    # type: (Dict, Optional[Dict]) -> Dict[str, Any]
    """Execute a single hook."""
    command = hook["command"]

    # Pass context as environment variable
    env = os.environ.copy()
    if context:
        env["MESH_HOOK_CONTEXT"] = json.dumps(context)
    env["MESH_HOOK_EVENT"] = hook["event"]
    env["MESH_HOOK_ID"] = hook["id"]

    start = time.time()
    try:
        result = subprocess.run(
            command, shell=True,
            capture_output=True, text=True,
            timeout=15, env=env
        )
        elapsed = time.time() - start

        return {
            "hook_id": hook["id"],
            "event": hook["event"],
            "exit_code": result.returncode,
            "duration_s": round(elapsed, 2),
            "stdout": result.stdout[-500:] if result.stdout else "",
            "stderr": result.stderr[-500:] if result.stderr else "",
            "blocked": result.returncode == 2 and hook.get("blocking", False),
        }

    except subprocess.TimeoutExpired:
        return {
            "hook_id": hook["id"],
            "event": hook["event"],
            "exit_code": -1,
            "duration_s": 15,
            "error": "timeout",
            "blocked": False,
        }
    except Exception as e:
        return {
            "hook_id": hook["id"],
            "event": hook["event"],
            "exit_code": -1,
            "error": str(e),
            "blocked": False,
        }


def log_hook_execution(hook, result):
    # type: (Dict, Dict) -> None
    """Log hook execution for observability."""
    log = []
    if os.path.exists(HOOKS_LOG_FILE):
        try:
            with open(HOOKS_LOG_FILE) as f:
                log = json.load(f)
        except (json.JSONDecodeError, IOError):
            log = []

    log.append({
        "timestamp": datetime.now().isoformat(),
        "hook_id": hook["id"],
        "event": hook["event"],
        "exit_code": result.get("exit_code", -1),
        "duration_s": result.get("duration_s", 0),
        "blocked": result.get("blocked", False),
    })

    # Keep last 200
    log = log[-200:]

    with open(HOOKS_LOG_FILE, "w") as f:
        json.dump(log, f, indent=2)


def list_hooks():
    # type: () -> None
    """List all registered hooks."""
    config = load_hooks()
    hooks = config.get("hooks", [])
    disabled = set(config.get("disabled", []))
    profile = config.get("profile", "standard")

    print("\nRegistered Hooks (profile: {}):".format(profile))
    print("-" * 70)

    if not hooks:
        print("  No hooks registered.")
        print("  Register with: python3 mesh/hooks.py register --event <event> --command <cmd>")
        print("")
        return

    for hook in hooks:
        is_disabled = hook["id"] in disabled
        status = "DISABLED" if is_disabled else "active"
        block_str = " [BLOCKING]" if hook.get("blocking") else ""
        print("  {} | {} | {} | {}{}".format(
            hook["id"], hook["event"], status,
            hook.get("description", "")[:40], block_str))
    print("")


def set_profile(profile_name):
    # type: (str) -> None
    """Set active hook profile."""
    if profile_name not in PROFILES:
        print("ERROR: Unknown profile. Available: {}".format(", ".join(PROFILES.keys())))
        sys.exit(1)

    config = load_hooks()
    config["profile"] = profile_name
    save_hooks(config)

    p = PROFILES[profile_name]
    print("Profile set: {} — {}".format(profile_name, p["description"]))
    print("Active events: {}".format(", ".join(p["events"])))


def show_profiles():
    # type: () -> None
    """Show available profiles."""
    config = load_hooks()
    current = config.get("profile", "standard")

    print("\nHook Profiles:")
    print("-" * 50)
    for name, p in PROFILES.items():
        marker = " <<<" if name == current else ""
        print("  {} — {}{}".format(name, p["description"], marker))
        print("    Events: {}".format(", ".join(p["events"])))
    print("")


def setup_default_hooks():
    # type: () -> None
    """Register recommended default hooks."""
    defaults = [
        ("pre-dispatch", "python3 {}/intercept.py".format(MESH_DIR),
         "Cost intercept before dispatch", False, "standard"),
        ("pre-commit", "python3 {}/security_scan.py --pre-commit --path .".format(MESH_DIR),
         "Security scan on staged files", True, "standard"),
        ("post-dispatch", "echo 'dispatch complete'",
         "Log dispatch completion", False, "standard"),
        ("session-start", "python3 {}/health.py --quick 2>/dev/null || true".format(MESH_DIR),
         "Quick health check on session start", False, "strict"),
    ]

    for event, command, desc, blocking, profile in defaults:
        register_hook(event, command, description=desc, blocking=blocking, profile=profile)

    print("\nDefault hooks registered. Use 'list' to see all.")


def main():
    parser = argparse.ArgumentParser(description="Mesh Hook System")
    sub = parser.add_subparsers(dest="command")

    # Register
    reg_p = sub.add_parser("register", help="Register a hook")
    reg_p.add_argument("--event", required=True, choices=EVENTS)
    reg_p.add_argument("--command", required=True, help="Shell command to run")
    reg_p.add_argument("--description", default="")
    reg_p.add_argument("--blocking", action="store_true", help="Exit 2 blocks operation")
    reg_p.add_argument("--profile", default="standard", choices=list(PROFILES.keys()))

    # Fire
    fire_p = sub.add_parser("fire", help="Fire hooks for an event")
    fire_p.add_argument("event", choices=EVENTS)
    fire_p.add_argument("--context", help="JSON context string")
    fire_p.add_argument("--profile", choices=list(PROFILES.keys()))

    # List
    sub.add_parser("list", help="List hooks")

    # Enable/Disable
    dis_p = sub.add_parser("disable", help="Disable a hook")
    dis_p.add_argument("--id", required=True)
    en_p = sub.add_parser("enable", help="Enable a hook")
    en_p.add_argument("--id", required=True)

    # Profile
    prof_p = sub.add_parser("profile", help="Set active profile")
    prof_p.add_argument("name", choices=list(PROFILES.keys()))

    # Profiles
    sub.add_parser("profiles", help="Show profiles")

    # Setup defaults
    sub.add_parser("setup", help="Register default hooks")

    args = parser.parse_args()

    if args.command == "register":
        register_hook(args.event, args.command, args.description, args.blocking, args.profile)
    elif args.command == "fire":
        ctx = json.loads(args.context) if args.context else None
        results = fire_hooks(args.event, context=ctx, profile=args.profile)
        for r in results:
            icon = "+" if r.get("exit_code", -1) == 0 else ("!!" if r.get("blocked") else "X")
            print("  [{}] {} ({:.2f}s)".format(icon, r["hook_id"], r.get("duration_s", 0)))
    elif args.command == "list":
        list_hooks()
    elif args.command == "disable":
        config = load_hooks()
        if args.id not in config.get("disabled", []):
            config.setdefault("disabled", []).append(args.id)
            save_hooks(config)
        print("Hook {} disabled.".format(args.id))
    elif args.command == "enable":
        config = load_hooks()
        disabled = config.get("disabled", [])
        if args.id in disabled:
            disabled.remove(args.id)
            config["disabled"] = disabled
            save_hooks(config)
        print("Hook {} enabled.".format(args.id))
    elif args.command == "profile":
        set_profile(args.name)
    elif args.command == "profiles":
        show_profiles()
    elif args.command == "setup":
        setup_default_hooks()
    else:
        parser.print_help()


if __name__ == "__main__":
    main()
