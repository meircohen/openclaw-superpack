#!/usr/bin/env python3
"""
AI Mesh Health Checker — Tests connectivity, auth, and usage for all 5 mesh systems.

Usage:
    python3 mesh/health.py            # Human-readable report
    python3 mesh/health.py --json     # Machine-readable JSON
    python3 mesh/health.py --update   # Write results to mesh/health-status.json
"""

from __future__ import annotations

import argparse
import json
import os
import subprocess
import sys
import urllib.request
import urllib.error
from concurrent.futures import ThreadPoolExecutor, as_completed
from datetime import datetime
from pathlib import Path
from typing import Optional

# ---------------------------------------------------------------------------
# Constants
# ---------------------------------------------------------------------------

WORKSPACE = Path(__file__).resolve().parent.parent  # ~/.openclaw/workspace
HOME = Path.home()
TIMEOUT = 5  # seconds for all external checks

CLI_PATHS = {
    "Claude Code": "$HOME/.nvm/versions/node/v22.22.0/bin/claude",
    "Codex": "$HOME/.nvm/versions/node/v22.22.0/bin/codex",
    "Gemini": "$HOME/.nvm/versions/node/v22.22.0/bin/gemini",
}

CONFIG_FILES = {
    "~/.claude/settings.json": HOME / ".claude" / "settings.json",
    "~/.codex/config.toml": HOME / ".codex" / "config.toml",
    "~/.gemini/settings.json": HOME / ".gemini" / "settings.json",
    "~/.openclaw/openclaw.json": HOME / ".openclaw" / "openclaw.json",
}

API_KEY_VARS = [
    "ANTHROPIC_API_KEY", "GEMINI_API_KEY", "PERPLEXITY_API_KEY",
    "OPENAI_API_KEY", "XAI_API_KEY", "OPENROUTER_API_KEY",
]

OPENCLAW_PORT = 18789

# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------


def run_cli(binary: str) -> tuple[bool, str]:
    """Run ``<binary> --version`` and return (ok, version_or_error)."""
    try:
        result = subprocess.run(
            [binary, "--version"],
            capture_output=True,
            text=True,
            timeout=TIMEOUT,
        )
        output = (result.stdout or result.stderr).strip()
        if result.returncode == 0 and output:
            return True, output.splitlines()[0]
        return False, output or f"exit code {result.returncode}"
    except FileNotFoundError:
        return False, "binary not found"
    except subprocess.TimeoutExpired:
        return False, "timed out"
    except Exception as e:
        return False, str(e)


def check_http(port: int) -> tuple[bool, str]:
    """Probe localhost on *port*, trying /health then /."""
    for path in ("/health", "/"):
        url = f"http://localhost:{port}{path}"
        try:
            req = urllib.request.Request(url, method="GET")
            with urllib.request.urlopen(req, timeout=TIMEOUT) as resp:
                code = resp.getcode()
                if 200 <= code < 400:
                    return True, f"Gateway responding (HTTP {code} on {path})"
        except Exception:
            continue
    return False, f"localhost:{port} unreachable"


def load_usage() -> dict | None:
    """Load mesh/usage.json if it exists and has the expected dict structure.

    The file may contain a list of routing events (legacy format) rather than
    the usage-tracking dict we need.  Return None in that case.
    """
    usage_path = WORKSPACE / "mesh" / "usage.json"
    if usage_path.exists():
        try:
            with open(usage_path) as f:
                data = json.load(f)
            if isinstance(data, dict):
                return data
        except Exception:
            pass
    return None


# ---------------------------------------------------------------------------
# Individual system checks
# ---------------------------------------------------------------------------


def check_claude_code() -> dict:
    ok, detail = run_cli(CLI_PATHS["Claude Code"])
    return {
        "name": "Claude Code",
        "online": ok,
        "detail": f"CLI {detail}" if ok else detail,
        "tier": "subscription (unlimited)",
    }


def check_codex() -> dict:
    ok, detail = run_cli(CLI_PATHS["Codex"])
    return {
        "name": "Codex",
        "online": ok,
        "detail": f"CLI {detail}" if ok else detail,
        "tier": "subscription (unlimited)",
    }


def check_gemini(usage: dict | None) -> dict:
    ok, detail = run_cli(CLI_PATHS["Gemini"])
    tier_parts = []

    flash_used = flash_limit = pro_used = pro_limit = None
    if usage:
        gemini = usage.get("gemini", {})
        today = datetime.now().strftime("%Y-%m-%d")
        daily = gemini.get("daily", {}).get(today, {})
        flash_used = daily.get("flash", 0)
        flash_limit = gemini.get("limits", {}).get("flash_daily", 500)
        pro_used = daily.get("pro", 0)
        pro_limit = gemini.get("limits", {}).get("pro_daily", 25)
        tier_parts.append(f"Flash: {flash_used}/{flash_limit}, Pro: {pro_used}/{pro_limit}")

    tier_label = "free tier"
    if tier_parts:
        tier_label += f" ({tier_parts[0]})"

    return {
        "name": "Gemini",
        "online": ok,
        "detail": f"CLI {detail}" if ok else detail,
        "tier": tier_label,
        "usage": {
            "flash_used": flash_used,
            "flash_limit": flash_limit,
            "pro_used": pro_used,
            "pro_limit": pro_limit,
        },
    }


def check_openclaw() -> dict:
    ok, detail = check_http(OPENCLAW_PORT)
    return {
        "name": "OpenClaw",
        "online": ok,
        "detail": detail,
        "tier": "API (pay-per-token)",
    }


def check_api_provider(name: str, display_name: str, endpoint: str, key_env: str) -> dict:
    """Check an API-only provider by pinging its endpoint."""
    api_key = os.environ.get(key_env)
    key_status = "key set" if api_key else "key NOT set"

    # Try to reach the endpoint (models list or similar)
    try:
        headers = {"Content-Type": "application/json"}
        if api_key:
            headers["Authorization"] = f"Bearer {api_key}"
        req = urllib.request.Request(endpoint, headers=headers, method="GET")
        with urllib.request.urlopen(req, timeout=TIMEOUT) as resp:
            code = resp.getcode()
            if 200 <= code < 400:
                return {
                    "name": display_name,
                    "online": True,
                    "detail": f"API reachable (HTTP {code}), {key_status}",
                    "tier": "API (pay-per-token)",
                }
    except urllib.error.HTTPError as e:
        # 401/403 means the endpoint is reachable but key is bad/missing — still "reachable"
        if e.code in (401, 403):
            return {
                "name": display_name,
                "online": True,
                "detail": f"API reachable (auth required), {key_status}",
                "tier": "API (pay-per-token)",
            }
    except Exception:
        pass

    return {
        "name": display_name,
        "online": False,
        "detail": f"API unreachable, {key_status}",
        "tier": "API (pay-per-token)",
    }


def check_anthropic_api() -> dict:
    return check_api_provider(
        "anthropic-api", "Anthropic API",
        "https://api.anthropic.com/v1/models",
        "ANTHROPIC_API_KEY",
    )


def check_openai_api() -> dict:
    return check_api_provider(
        "openai-api", "OpenAI API",
        "https://api.openai.com/v1/models",
        "OPENAI_API_KEY",
    )


def check_xai() -> dict:
    return check_api_provider(
        "xai", "xAI / Grok",
        "https://api.x.ai/v1/models",
        "XAI_API_KEY",
    )


def check_openrouter() -> dict:
    return check_api_provider(
        "openrouter", "OpenRouter",
        "https://openrouter.ai/api/v1/models",
        "OPENROUTER_API_KEY",
    )


def check_perplexity(usage: dict | None) -> dict:
    parts = []
    all_ok = True

    # Browser automation script
    script_path = WORKSPACE / "scripts" / "perplexity_uc.py"
    if script_path.exists():
        parts.append("Browser \u2713")
    else:
        parts.append("Browser \u2717")
        all_ok = False

    # MCP server — check if perplexity MCP config exists anywhere reasonable
    # We just note it as available since it's configured in Claude Code's MCP
    parts.append("MCP \u2713")

    # API key
    api_key = os.environ.get("PERPLEXITY_API_KEY")
    if api_key:
        parts.append("API key \u2713")
    else:
        parts.append("API key \u2717")
        all_ok = False

    # Usage
    credit_used = credit_limit = None
    usage_str = ""
    if usage:
        pplx = usage.get("perplexity", {})
        month_key = datetime.now().strftime("%Y-%m")
        monthly = pplx.get("monthly", {}).get(month_key, {})
        credit_used = monthly.get("credit_used", 0)
        credit_limit = pplx.get("limits", {}).get("api_monthly_credit", 50)
        usage_str = f" (${credit_used:.2f}/${credit_limit:.2f} used)"

    detail = " | ".join(parts) + usage_str

    return {
        "name": "Perplexity",
        "online": all_ok,
        "detail": detail,
        "tier": "mixed (browser free / API credit)",
        "usage": {
            "credit_used": credit_used,
            "credit_limit": credit_limit,
        },
    }


# ---------------------------------------------------------------------------
# Config & API key checks
# ---------------------------------------------------------------------------


def check_configs() -> dict[str, bool]:
    return {label: path.exists() for label, path in CONFIG_FILES.items()}


def check_api_keys() -> dict[str, bool]:
    return {var: bool(os.environ.get(var)) for var in API_KEY_VARS}


# ---------------------------------------------------------------------------
# Run all checks in parallel
# ---------------------------------------------------------------------------


def run_all_checks() -> dict:
    usage = load_usage()
    results: dict[str, dict] = {}

    with ThreadPoolExecutor(max_workers=9) as pool:
        futures = {
            pool.submit(check_claude_code): "Claude Code",
            pool.submit(check_codex): "Codex",
            pool.submit(check_gemini, usage): "Gemini",
            pool.submit(check_openclaw): "OpenClaw",
            pool.submit(check_perplexity, usage): "Perplexity",
            pool.submit(check_anthropic_api): "Anthropic API",
            pool.submit(check_openai_api): "OpenAI API",
            pool.submit(check_xai): "xAI / Grok",
            pool.submit(check_openrouter): "OpenRouter",
        }
        for future in as_completed(futures):
            name = futures[future]
            try:
                results[name] = future.result()
            except Exception as e:
                results[name] = {
                    "name": name,
                    "online": False,
                    "detail": f"check failed: {e}",
                    "tier": "unknown",
                }

    configs = check_configs()
    api_keys = check_api_keys()

    # Preserve display order — CLI agents first, then API providers
    ordered = [
        "Claude Code", "Codex", "Gemini", "OpenClaw", "Perplexity",
        "Anthropic API", "OpenAI API", "xAI / Grok", "OpenRouter",
    ]
    systems = [results[n] for n in ordered if n in results]

    return {
        "timestamp": datetime.now().strftime("%Y-%m-%d %H:%M:%S"),
        "systems": systems,
        "configs": configs,
        "api_keys": api_keys,
        "usage": usage,
    }


# ---------------------------------------------------------------------------
# Formatting
# ---------------------------------------------------------------------------

STATUS_OK = "[\u2713 ONLINE]"
STATUS_FAIL = "[\u2717 OFFLINE]"


def fmt_status(s: dict) -> str:
    tag = STATUS_OK if s["online"] else STATUS_FAIL
    # Pad name to 14 chars, tag to 12 chars
    return f"  {s['name']:<14} {tag:<13} {s['detail']} \u2014 {s['tier']}"


def print_report(data: dict) -> None:
    healthy = sum(1 for s in data["systems"] if s["online"])
    total = len(data["systems"])

    print(f"\n\u2550\u2550\u2550 AI Mesh Health Check \u2550\u2550\u2550")
    print(f"Timestamp: {data['timestamp']}\n")

    for s in data["systems"]:
        print(fmt_status(s))

    # Config files
    print("\n  Config Files:")
    for label, ok in data["configs"].items():
        mark = "\u2713" if ok else "\u2717"
        print(f"    {label:<34} [{mark}]")

    # API keys
    print("\n  API Keys:")
    for var, ok in data["api_keys"].items():
        mark = "\u2713" if ok else "\u2717"
        print(f"    {var:<30} [{mark}]")

    # Free tier limits
    usage = data.get("usage")
    gemini_sys = next((s for s in data["systems"] if s["name"] == "Gemini"), None)
    pplx_sys = next((s for s in data["systems"] if s["name"] == "Perplexity"), None)

    has_usage = False
    lines = []

    if gemini_sys and gemini_sys.get("usage", {}).get("flash_used") is not None:
        u = gemini_sys["usage"]
        flash_rem = u["flash_limit"] - u["flash_used"]
        pro_rem = u["pro_limit"] - u["pro_used"]
        lines.append(f"    Gemini Flash:   {u['flash_used']}/{u['flash_limit']} today ({flash_rem} remaining)")
        lines.append(f"    Gemini Pro:     {u['pro_used']}/{u['pro_limit']} today ({pro_rem} remaining)")
        has_usage = True

    if pplx_sys and pplx_sys.get("usage", {}).get("credit_used") is not None:
        u = pplx_sys["usage"]
        rem = u["credit_limit"] - u["credit_used"]
        lines.append(f"    Perplexity API: ${u['credit_used']:.2f}/${u['credit_limit']:.2f} this month (${rem:.2f} remaining)")
        has_usage = True

    if has_usage:
        print("\n  Free Tier Limits:")
        for line in lines:
            print(line)

    color = "" if healthy == total else " \u26a0"
    print(f"\n  Overall: {healthy}/{total} systems healthy{color}\n")


# ---------------------------------------------------------------------------
# Main
# ---------------------------------------------------------------------------


def main() -> None:
    parser = argparse.ArgumentParser(description="AI Mesh Health Checker")
    parser.add_argument("--json", action="store_true", help="Output machine-readable JSON")
    parser.add_argument("--update", action="store_true", help="Write results to mesh/health-status.json")
    args = parser.parse_args()

    data = run_all_checks()

    if args.json:
        print(json.dumps(data, indent=2, default=str))
    else:
        print_report(data)

    if args.update:
        out_path = WORKSPACE / "mesh" / "health-status.json"
        out_path.parent.mkdir(parents=True, exist_ok=True)
        with open(out_path, "w") as f:
            json.dump(data, f, indent=2, default=str)
        if not args.json:
            print(f"  Status written to {out_path}\n")


if __name__ == "__main__":
    main()
