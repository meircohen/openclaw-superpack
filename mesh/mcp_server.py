#!/usr/bin/env python3
"""
AI Mesh MCP Server — Exposes mesh tools (router, health, dispatch, intel, whoop)
as an MCP server using FastMCP.

Run standalone:  python3 mesh/mcp_server.py
"""

from __future__ import annotations

import json
import os
import re
import subprocess
import sys
import time
from pathlib import Path

from fastmcp import FastMCP

WORKSPACE = Path(__file__).resolve().parent.parent
MESH_DIR = WORKSPACE / "mesh"

# Ensure mesh/ is importable
if str(MESH_DIR.parent) not in sys.path:
    sys.path.insert(0, str(MESH_DIR.parent))

mcp = FastMCP(
    "AI Mesh",
    instructions="OpenClaw AI Mesh — route, dispatch, and monitor tasks across the multi-agent system",
)

# ---------------------------------------------------------------------------
# Helpers for safe imports with subprocess fallback
# ---------------------------------------------------------------------------

def _import_router():
    try:
        from mesh.router import route
        return route
    except Exception:
        return None


def _import_health():
    try:
        from mesh.health import run_all_checks
        return run_all_checks
    except Exception:
        return None


def _import_dispatch():
    try:
        from mesh.dispatch import route_task, execute_on_system, log_execution
        return route_task, execute_on_system, log_execution
    except Exception:
        return None, None, None


def _run_subprocess(script: str, args: list[str] | None = None, timeout: int = 30) -> str:
    """Run a script as subprocess fallback."""
    cmd = [sys.executable, str(MESH_DIR / script)] + (args or [])
    result = subprocess.run(cmd, capture_output=True, text=True, timeout=timeout,
                            cwd=str(WORKSPACE))
    if result.returncode != 0:
        return json.dumps({"error": result.stderr.strip() or f"exit code {result.returncode}"})
    return result.stdout.strip()


# ---------------------------------------------------------------------------
# Tool 1: mesh_route
# ---------------------------------------------------------------------------

@mcp.tool()
def mesh_route(task: str) -> str:
    """Route a task to the best AI system in the mesh.

    Given a natural-language task description, classifies it and recommends
    the optimal system (Claude Code, Codex, Gemini, Perplexity, OpenClaw)
    based on cost, capability, and task category.

    Returns JSON with: recommended system, category, confidence,
    matched keywords, cost, reason, and alternative systems.
    """
    route_fn = _import_router()
    if route_fn:
        result = route_fn(task)
        return json.dumps(result, indent=2)
    # Fallback to subprocess
    output = _run_subprocess("router.py", ["--json", task])
    return output


# ---------------------------------------------------------------------------
# Tool 2: mesh_health
# ---------------------------------------------------------------------------

@mcp.tool()
def mesh_health() -> str:
    """Check health and status of all AI mesh systems.

    Tests connectivity, authentication, and usage limits for every system
    in the mesh (Claude Code, Codex, Gemini, OpenClaw, Perplexity, APIs).

    Returns JSON with: system statuses (online/offline), tier info,
    config file presence, API key availability, and usage data.
    """
    check_fn = _import_health()
    if check_fn:
        result = check_fn()
        return json.dumps(result, indent=2, default=str)
    output = _run_subprocess("health.py", ["--json"])
    return output


# ---------------------------------------------------------------------------
# Tool 3: mesh_dispatch
# ---------------------------------------------------------------------------

@mcp.tool()
def mesh_dispatch(task: str, system: str | None = None, timeout: int = 120) -> str:
    """Dispatch a task to an AI system for execution.

    Routes the task to the best available system (or a specified override)
    and executes it. Includes automatic fallback if the primary system fails.

    Args:
        task: Natural-language task description to execute.
        system: Optional system override (claude-code, codex, gemini, openclaw,
                perplexity-browser, perplexity-api). If omitted, auto-routes.
        timeout: Execution timeout in seconds (default 120).

    Returns JSON with: success status, output, system used, category, duration.
    """
    route_fn, execute_fn, log_fn = _import_dispatch()
    if route_fn and execute_fn:
        category, systems = route_fn(task)
        if system:
            systems = [system]
        for s in systems:
            if s == "perplexity-mcp":
                continue
            success, output, duration = execute_fn(s, task, timeout)
            result = {
                "success": success,
                "output": output[:2000] if len(output) > 2000 else output,
                "system": s,
                "category": category,
                "duration_seconds": round(duration, 2),
            }
            if log_fn:
                try:
                    log_fn(task=task, category=category, system=s,
                           success=success, duration=duration,
                           output=output[:500], fallback=systems.index(s) > 0)
                except Exception:
                    pass
            if success:
                return json.dumps(result, indent=2)
        # All systems failed — return last result
        return json.dumps(result, indent=2)

    # Fallback to subprocess
    args = [task]
    if system:
        args = ["--system", system] + args
    output = _run_subprocess("dispatch.py", args, timeout=timeout + 10)
    return output


# ---------------------------------------------------------------------------
# Tool 4: intel_query
# ---------------------------------------------------------------------------

@mcp.tool()
def intel_query(query: str) -> str:
    """Search the intelligence digest and hot items for matching intel.

    Searches across intelligence/digest.md (curated daily digest) and
    intelligence/hot.json (scored raw items) for items matching the query.

    Args:
        query: Search terms (e.g. 'MCP adoption', 'Claude', 'security').

    Returns JSON array of top 5 matches with title, source, relevance,
    actionability, tags, and URL.
    """
    query_lower = query.lower()
    terms = query_lower.split()
    matches = []

    # Search hot.json
    hot_path = WORKSPACE / "intelligence" / "hot.json"
    if hot_path.exists():
        try:
            items = json.loads(hot_path.read_text())
            for item in items:
                score = 0
                searchable = f"{item.get('title', '')} {item.get('classification', {}).get('reason', '')} {' '.join(item.get('keywords_matched', []))} {' '.join(item.get('classification', {}).get('tags', []))}".lower()
                for term in terms:
                    if term in searchable:
                        score += 1
                if score > 0:
                    cls = item.get("classification", {})
                    matches.append({
                        "title": item.get("title", ""),
                        "source": item.get("source", ""),
                        "url": item.get("url", ""),
                        "relevance_score": cls.get("relevance_score", 0),
                        "actionability": cls.get("actionability", "unknown"),
                        "tags": cls.get("tags", []),
                        "match_score": score,
                        "origin": "hot.json",
                    })
        except Exception:
            pass

    # Search digest.md — extract sections
    digest_path = WORKSPACE / "intelligence" / "digest.md"
    if digest_path.exists():
        try:
            text = digest_path.read_text()
            # Split by item headers (### or numbered items)
            sections = re.split(r'\n(?=###?\s|\d+\.\s\*\*)', text)
            for section in sections:
                section_lower = section.lower()
                score = sum(1 for term in terms if term in section_lower)
                if score > 0:
                    # Extract title from first line
                    first_line = section.strip().split('\n')[0]
                    title = re.sub(r'^[#\d.\s*]+', '', first_line).strip()
                    # Extract URL if present
                    url_match = re.search(r'https?://\S+', section)
                    url = url_match.group(0).rstrip(')>') if url_match else ""
                    matches.append({
                        "title": title[:120],
                        "source": "digest",
                        "url": url,
                        "relevance_score": 0,
                        "actionability": "see digest",
                        "tags": [],
                        "match_score": score,
                        "origin": "digest.md",
                    })
        except Exception:
            pass

    # Sort by match_score descending, then relevance_score
    matches.sort(key=lambda m: (m["match_score"], m["relevance_score"]), reverse=True)
    top = matches[:5]

    # Clean up internal scoring
    for m in top:
        del m["match_score"]

    return json.dumps(top, indent=2)


# ---------------------------------------------------------------------------
# Tool 5: whoop_data
# ---------------------------------------------------------------------------

@mcp.tool()
def whoop_data(date: str | None = None) -> str:
    """Get WHOOP health and recovery data.

    Fetches the latest WHOOP metrics including recovery score, HRV,
    sleep performance, and strain from the WHOOP API.

    Args:
        date: Optional date string (YYYY-MM-DD). Defaults to today.

    Returns JSON with: recovery score, HRV, sleep performance, strain,
    and any available body metrics.
    """
    whoop_script = WORKSPACE / "scripts" / "whoop.sh"
    if not whoop_script.exists():
        return json.dumps({"error": "scripts/whoop.sh not found"})

    try:
        args = ["bash", str(whoop_script), "summary"]
        result = subprocess.run(args, capture_output=True, text=True, timeout=30,
                                cwd=str(WORKSPACE))
        output = result.stdout.strip()
        if result.returncode != 0:
            return json.dumps({
                "error": result.stderr.strip() or f"whoop.sh exited {result.returncode}",
                "raw_output": output,
            })

        # Try to parse structured data from output
        data = {"raw_output": output}
        for line in output.split('\n'):
            line_lower = line.lower()
            if 'recovery' in line_lower:
                num = re.search(r'(\d+)', line)
                if num:
                    data["recovery_score"] = int(num.group(1))
            elif 'hrv' in line_lower:
                num = re.search(r'([\d.]+)', line)
                if num:
                    data["hrv_ms"] = float(num.group(1))
            elif 'sleep' in line_lower and ('score' in line_lower or 'performance' in line_lower):
                num = re.search(r'(\d+)', line)
                if num:
                    data["sleep_performance"] = int(num.group(1))
            elif 'strain' in line_lower:
                num = re.search(r'([\d.]+)', line)
                if num:
                    data["strain"] = float(num.group(1))

        return json.dumps(data, indent=2)
    except subprocess.TimeoutExpired:
        return json.dumps({"error": "whoop.sh timed out after 30s"})
    except Exception as e:
        return json.dumps({"error": str(e)})


# ---------------------------------------------------------------------------
# Main
# ---------------------------------------------------------------------------

if __name__ == "__main__":
    mcp.run()
