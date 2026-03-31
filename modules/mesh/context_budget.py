#!/usr/bin/env python3
"""
Context Window Budget Analyzer for AI Mesh
Adapted from ECC /context-budget + strategic-compact skill.

Analyzes token consumption across mesh systems:
- Inventories agents, skills, MCP servers, rules, bootstrap files
- Estimates token overhead per component
- Detects context bloat
- Recommends optimizations
- Phase-aware compaction suggestions

Usage:
    python3 mesh/context_budget.py                    # summary view
    python3 mesh/context_budget.py --verbose          # full breakdown
    python3 mesh/context_budget.py --system claude-code  # specific system
    python3 mesh/context_budget.py --json
"""

import argparse
import json
import os
import sys
from typing import Any, Dict, List, Optional, Tuple

MESH_DIR = os.path.dirname(os.path.abspath(__file__))
WORKSPACE = os.path.dirname(MESH_DIR)

# Context window sizes per system
CONTEXT_LIMITS = {
    "claude-code": 1000000,    # 1M tokens (Opus 4.6)
    "codex": 200000,           # 200K tokens
    "gemini": 1000000,         # 1M tokens (Pro)
    "gemini-flash": 1000000,   # 1M tokens
    "openclaw": 200000,        # 200K tokens
    "grok": 2000000,           # 2M tokens (Grok-4-fast)
    "openrouter": 128000,      # Varies, conservative default
    "anthropic-api": 1000000,  # 1M tokens
    "openai-api": 128000,      # GPT-5.4 context
}

# Approximate tokens per character (conservative)
CHARS_PER_TOKEN = 4


def estimate_tokens(text):
    # type: (str) -> int
    """Estimate token count from text length."""
    return len(text) // CHARS_PER_TOKEN


def estimate_file_tokens(filepath):
    # type: (str) -> int
    """Estimate tokens in a file."""
    try:
        with open(filepath) as f:
            content = f.read()
        return estimate_tokens(content)
    except (IOError, OSError):
        return 0


def inventory_claude_code():
    # type: () -> Dict[str, Any]
    """Inventory Claude Code context sources."""
    items = []

    # CLAUDE.md files
    for root, dirs, files in os.walk(WORKSPACE):
        dirs[:] = [d for d in dirs if d not in {".git", "node_modules", "__pycache__", ".venv"}]
        for fname in files:
            if fname == "CLAUDE.md":
                filepath = os.path.join(root, fname)
                tokens = estimate_file_tokens(filepath)
                items.append({
                    "category": "claude_md",
                    "name": os.path.relpath(filepath, WORKSPACE),
                    "tokens": tokens,
                    "loaded": "always",
                })

    # Global CLAUDE.md
    global_claude = os.path.expanduser("~/.claude/CLAUDE.md")
    if os.path.exists(global_claude):
        tokens = estimate_file_tokens(global_claude)
        items.append({
            "category": "claude_md",
            "name": "~/.claude/CLAUDE.md (global)",
            "tokens": tokens,
            "loaded": "always",
        })

    # Settings
    settings_file = os.path.expanduser("~/.claude/settings.json")
    if os.path.exists(settings_file):
        tokens = estimate_file_tokens(settings_file)
        items.append({
            "category": "settings",
            "name": "settings.json",
            "tokens": tokens,
            "loaded": "always",
        })

    # MCP server configs
    try:
        with open(settings_file) as f:
            settings = json.load(f)
        mcps = settings.get("mcpServers", {})
        for name in mcps:
            items.append({
                "category": "mcp",
                "name": "MCP: {}".format(name),
                "tokens": 500,  # Estimated per-server overhead
                "loaded": "on-demand",
            })
    except (IOError, json.JSONDecodeError):
        pass

    # Skills
    skills_dir = os.path.expanduser("~/.openclaw/workspace/superpowers/skills")
    if os.path.exists(skills_dir):
        for skill in os.listdir(skills_dir):
            skill_md = os.path.join(skills_dir, skill, "SKILL.md")
            if os.path.exists(skill_md):
                tokens = estimate_file_tokens(skill_md)
                items.append({
                    "category": "skill",
                    "name": "Skill: {}".format(skill),
                    "tokens": tokens,
                    "loaded": "on-invoke",
                })

    # Memory files
    memory_dir = os.path.expanduser("~/.claude/projects")
    if os.path.exists(memory_dir):
        total_memory_tokens = 0
        memory_count = 0
        for root, dirs, files in os.walk(memory_dir):
            for fname in files:
                if fname.endswith(".md"):
                    tokens = estimate_file_tokens(os.path.join(root, fname))
                    total_memory_tokens += tokens
                    memory_count += 1
        if memory_count > 0:
            items.append({
                "category": "memory",
                "name": "Memory files ({} files)".format(memory_count),
                "tokens": total_memory_tokens,
                "loaded": "always",
            })

    # Bootstrap files for mesh
    bootstrap_dir = os.path.join(MESH_DIR, "bootstrap")
    if os.path.exists(bootstrap_dir):
        for fname in os.listdir(bootstrap_dir):
            filepath = os.path.join(bootstrap_dir, fname)
            if os.path.isfile(filepath):
                tokens = estimate_file_tokens(filepath)
                items.append({
                    "category": "bootstrap",
                    "name": "Bootstrap: {}".format(fname),
                    "tokens": tokens,
                    "loaded": "on-inject",
                })

    return {
        "system": "claude-code",
        "context_limit": CONTEXT_LIMITS["claude-code"],
        "items": items,
    }


def analyze_budget(inventory):
    # type: (Dict[str, Any]) -> Dict[str, Any]
    """Analyze context budget from inventory."""
    items = inventory["items"]
    limit = inventory["context_limit"]

    # Group by category
    by_category = {}  # type: Dict[str, Dict[str, Any]]
    for item in items:
        cat = item["category"]
        if cat not in by_category:
            by_category[cat] = {"items": [], "total_tokens": 0}
        by_category[cat]["items"].append(item)
        by_category[cat]["total_tokens"] += item["tokens"]

    # Always-loaded budget
    always_loaded = sum(
        item["tokens"] for item in items if item.get("loaded") == "always"
    )

    # On-demand budget (potential)
    on_demand = sum(
        item["tokens"] for item in items if item.get("loaded") != "always"
    )

    # Total potential
    total = always_loaded + on_demand

    # Utilization
    always_pct = (always_loaded / limit * 100) if limit > 0 else 0
    total_pct = (total / limit * 100) if limit > 0 else 0

    # Available for work
    work_budget = limit - always_loaded

    # Recommendations
    recommendations = []

    if always_pct > 30:
        recommendations.append({
            "priority": "HIGH",
            "message": "Always-loaded context uses {:.1f}% — consider trimming CLAUDE.md or memory".format(always_pct),
        })

    # Large individual items
    for item in items:
        if item["tokens"] > 10000 and item.get("loaded") == "always":
            recommendations.append({
                "priority": "MEDIUM",
                "message": "'{}' uses ~{:,} tokens — consider splitting or trimming".format(
                    item["name"], item["tokens"]),
            })

    if len(by_category.get("mcp", {}).get("items", [])) > 8:
        recommendations.append({
            "priority": "LOW",
            "message": "{} MCP servers configured — each adds discovery overhead".format(
                len(by_category["mcp"]["items"])),
        })

    # Phase-aware compaction hints
    recommendations.append({
        "priority": "INFO",
        "message": "Compact between phases (Research->Planning->Implementation->Testing), not mid-phase",
    })
    recommendations.append({
        "priority": "INFO",
        "message": "Memory files, CLAUDE.md, and TodoWrite survive compaction; conversation context does not",
    })

    return {
        "system": inventory["system"],
        "context_limit": limit,
        "always_loaded_tokens": always_loaded,
        "on_demand_tokens": on_demand,
        "total_potential_tokens": total,
        "work_budget_tokens": work_budget,
        "always_loaded_pct": round(always_pct, 1),
        "total_potential_pct": round(total_pct, 1),
        "by_category": {
            cat: {
                "count": len(data["items"]),
                "total_tokens": data["total_tokens"],
            }
            for cat, data in by_category.items()
        },
        "items": items,
        "recommendations": recommendations,
    }


def print_report(analysis, verbose=False):
    # type: (Dict, bool) -> None
    """Print human-readable budget report."""
    print("\n" + "=" * 60)
    print("CONTEXT BUDGET REPORT — {}".format(analysis["system"]))
    print("=" * 60)

    limit = analysis["context_limit"]
    always = analysis["always_loaded_tokens"]
    work = analysis["work_budget_tokens"]

    print("  Context Limit:     {:>10,} tokens".format(limit))
    print("  Always Loaded:     {:>10,} tokens ({:.1f}%)".format(always, analysis["always_loaded_pct"]))
    print("  On-Demand:         {:>10,} tokens".format(analysis["on_demand_tokens"]))
    print("  Available for Work:{:>10,} tokens".format(work))
    print("-" * 60)

    # By category
    print("\n  Category Breakdown:")
    for cat, data in sorted(analysis["by_category"].items(),
                            key=lambda x: x[1]["total_tokens"], reverse=True):
        print("    {:<20} {:>6,} tokens ({} items)".format(
            cat, data["total_tokens"], data["count"]))

    if verbose:
        print("\n  All Items:")
        for item in sorted(analysis["items"], key=lambda x: x["tokens"], reverse=True):
            print("    {:>6,} tok | {:<10} | {} [{}]".format(
                item["tokens"], item["category"], item["name"], item.get("loaded", "?")))

    # Recommendations
    recs = analysis.get("recommendations", [])
    if recs:
        print("\n  Recommendations:")
        for rec in recs:
            icon = {"HIGH": "!!", "MEDIUM": "! ", "LOW": "- ", "INFO": "  "}.get(
                rec["priority"], "  ")
            print("    [{}] {}".format(icon, rec["message"]))

    # Budget bar
    pct = analysis["always_loaded_pct"]
    bar_width = 40
    filled = int(pct / 100 * bar_width)
    bar = "#" * filled + "-" * (bar_width - filled)
    print("\n  Budget: [{}] {:.1f}% used".format(bar, pct))

    print("=" * 60 + "\n")


def main():
    parser = argparse.ArgumentParser(description="Mesh Context Budget Analyzer")
    parser.add_argument("--system", default="claude-code",
                        choices=list(CONTEXT_LIMITS.keys()),
                        help="System to analyze")
    parser.add_argument("--verbose", "-v", action="store_true",
                        help="Show all items")
    parser.add_argument("--json", action="store_true", help="JSON output")
    args = parser.parse_args()

    # Currently only Claude Code has full inventory support
    if args.system == "claude-code":
        inventory = inventory_claude_code()
    else:
        # Generic: just show context limit and basic info
        inventory = {
            "system": args.system,
            "context_limit": CONTEXT_LIMITS.get(args.system, 128000),
            "items": [],
        }

    analysis = analyze_budget(inventory)

    if args.json:
        print(json.dumps(analysis, indent=2))
    else:
        print_report(analysis, verbose=args.verbose)


if __name__ == "__main__":
    main()
