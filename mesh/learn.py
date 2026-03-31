#!/usr/bin/env python3
"""
Learning System — Records task outcomes and adjusts routing weights over time.

After each task, records: system, task type, success, time, tokens, cost.
Monthly analysis updates routing weights. Auto-deprioritizes failing systems.

Usage:
    python3 mesh/learn.py record --system claude-code --task-type coding --success --time 45.2 --tokens 12000 --cost 0
    python3 mesh/learn.py record --system openclaw --task-type research --fail --time 120 --tokens 50000 --cost 0.75
    python3 mesh/learn.py analyze               # Show monthly analysis
    python3 mesh/learn.py analyze --json        # JSON output
    python3 mesh/learn.py weights               # Show current routing weights
"""

from __future__ import annotations

import argparse
import json
import sys
from collections import defaultdict
from datetime import datetime, timezone
from pathlib import Path

MESH_DIR = Path(__file__).resolve().parent
LEARNINGS_FILE = MESH_DIR / "learnings.json"

TASK_TYPES = ["coding", "research", "reasoning", "long_context", "multimodal", "quick_answer", "background", "monitoring"]
SYSTEMS = ["claude-code", "codex", "gemini", "openclaw", "perplexity-browser", "perplexity-mcp", "perplexity-api"]


def load_learnings() -> list[dict]:
    """Load learnings from JSON file."""
    if not LEARNINGS_FILE.exists():
        return []
    try:
        data = json.loads(LEARNINGS_FILE.read_text())
        return data if isinstance(data, list) else []
    except (json.JSONDecodeError, OSError):
        return []


def save_learnings(data: list[dict]) -> None:
    """Save learnings to JSON file."""
    LEARNINGS_FILE.write_text(json.dumps(data, indent=2) + "\n")


def record_learning(
    system: str,
    task_type: str,
    success: bool,
    duration: float,
    tokens: int,
    cost: float,
    task_desc: str = "",
) -> dict:
    """Record a task outcome."""
    entry = {
        "timestamp": datetime.now(timezone.utc).isoformat(),
        "system": system,
        "task_type": task_type,
        "success": success,
        "duration_seconds": round(duration, 2),
        "tokens": tokens,
        "cost": round(cost, 4),
        "task": task_desc,
    }

    data = load_learnings()
    data.append(entry)
    save_learnings(data)
    return entry


def analyze_learnings(period_days: int = 30) -> dict:
    """Analyze learnings and compute routing weight adjustments.

    Returns analysis with:
    - Per-system success rates
    - Per-system average cost & duration
    - Recommended weight adjustments
    - Systems to deprioritize
    """
    data = load_learnings()
    if not data:
        return {"error": "No learnings recorded yet", "entries": 0}

    now = datetime.now(timezone.utc)

    # Filter to period
    filtered = []
    for entry in data:
        try:
            ts = datetime.fromisoformat(entry["timestamp"])
            if ts.tzinfo is None:
                ts = ts.replace(tzinfo=timezone.utc)
            diff = (now - ts).days
            if diff <= period_days:
                filtered.append(entry)
        except (ValueError, KeyError):
            continue

    if not filtered:
        return {"error": f"No learnings in the last {period_days} days", "entries": 0}

    # Aggregate per system
    system_stats: dict[str, dict] = defaultdict(lambda: {
        "total": 0, "successes": 0, "failures": 0,
        "total_cost": 0.0, "total_duration": 0.0, "total_tokens": 0,
        "task_types": defaultdict(int),
    })

    for entry in filtered:
        sys_name = entry.get("system", "unknown")
        stats = system_stats[sys_name]
        stats["total"] += 1
        if entry.get("success"):
            stats["successes"] += 1
        else:
            stats["failures"] += 1
        stats["total_cost"] += entry.get("cost", 0)
        stats["total_duration"] += entry.get("duration_seconds", 0)
        stats["total_tokens"] += entry.get("tokens", 0)
        stats["task_types"][entry.get("task_type", "unknown")] += 1

    # Compute metrics and weight adjustments
    analysis = {
        "period_days": period_days,
        "total_entries": len(filtered),
        "systems": {},
        "weight_adjustments": {},
        "deprioritize": [],
        "recommendations": [],
    }

    for sys_name, stats in system_stats.items():
        total = stats["total"]
        success_rate = (stats["successes"] / total * 100) if total > 0 else 0
        avg_cost = stats["total_cost"] / total if total > 0 else 0
        avg_duration = stats["total_duration"] / total if total > 0 else 0

        analysis["systems"][sys_name] = {
            "total_tasks": total,
            "success_rate": round(success_rate, 1),
            "failures": stats["failures"],
            "avg_cost": round(avg_cost, 4),
            "avg_duration_s": round(avg_duration, 1),
            "total_tokens": stats["total_tokens"],
            "task_types": dict(stats["task_types"]),
        }

        # Weight adjustment logic
        # Below 70% success rate: penalize
        # Above 90% success rate: boost
        # High cost compared to alternatives: penalize
        weight_adj = 0.0
        if success_rate < 50:
            weight_adj = -0.5
            analysis["deprioritize"].append(sys_name)
            analysis["recommendations"].append(
                f"DEPRIORITIZE {sys_name}: {success_rate:.0f}% success rate is critically low"
            )
        elif success_rate < 70:
            weight_adj = -0.2
            analysis["recommendations"].append(
                f"Reduce {sys_name} priority: {success_rate:.0f}% success rate is below threshold"
            )
        elif success_rate > 90 and total >= 5:
            weight_adj = 0.1
            analysis["recommendations"].append(
                f"Boost {sys_name}: {success_rate:.0f}% success rate with {total} tasks"
            )

        # Cost penalty for expensive systems
        if avg_cost > 0.10:
            weight_adj -= 0.1
            analysis["recommendations"].append(
                f"Cost warning: {sys_name} averaging ${avg_cost:.4f}/task"
            )

        if weight_adj != 0:
            analysis["weight_adjustments"][sys_name] = round(weight_adj, 2)

    return analysis


def show_weights() -> dict:
    """Show current effective routing weights based on learnings."""
    # Base weights (from router.py priority order)
    base_weights = {
        "coding": {"claude-code": 1.0, "gemini": 0.8, "codex": 0.6},
        "research": {"perplexity-browser": 1.0, "perplexity-mcp": 0.8, "gemini": 0.6, "perplexity-api": 0.2},
        "reasoning": {"codex": 1.0, "gemini": 0.8, "claude-code": 0.6},
        "long_context": {"gemini": 1.0, "claude-code": 0.6, "codex": 0.4},
        "multimodal": {"gemini": 1.0, "openclaw": 0.6, "claude-code": 0.4},
        "quick_answer": {"openclaw": 1.0, "gemini": 0.8},
        "background": {"openclaw": 1.0, "codex": 0.6},
    }

    analysis = analyze_learnings()
    adjustments = analysis.get("weight_adjustments", {})

    # Apply adjustments
    effective = {}
    for task_type, weights in base_weights.items():
        effective[task_type] = {}
        for sys_name, base_w in weights.items():
            adj = adjustments.get(sys_name, 0)
            eff_w = max(0.0, min(1.0, base_w + adj))
            effective[task_type][sys_name] = round(eff_w, 2)

    return {
        "base_weights": base_weights,
        "adjustments": adjustments,
        "effective_weights": effective,
    }


def format_analysis(analysis: dict) -> str:
    """Format analysis for human reading."""
    if "error" in analysis:
        return f"[learn] {analysis['error']}"

    lines = [
        f"=== Learning Analysis (last {analysis['period_days']} days) ===",
        f"Total entries: {analysis['total_entries']}",
        "",
    ]

    for sys_name, stats in sorted(analysis["systems"].items()):
        lines.append(f"  {sys_name}:")
        lines.append(f"    Tasks: {stats['total_tasks']}, Success: {stats['success_rate']}%")
        lines.append(f"    Avg cost: ${stats['avg_cost']:.4f}, Avg time: {stats['avg_duration_s']}s")
        types_str = ", ".join(f"{k}:{v}" for k, v in stats["task_types"].items())
        lines.append(f"    Types: {types_str}")
        lines.append("")

    if analysis["weight_adjustments"]:
        lines.append("Weight Adjustments:")
        for sys_name, adj in analysis["weight_adjustments"].items():
            sign = "+" if adj > 0 else ""
            lines.append(f"  {sys_name}: {sign}{adj}")
        lines.append("")

    if analysis["deprioritize"]:
        lines.append(f"Deprioritize: {', '.join(analysis['deprioritize'])}")
        lines.append("")

    if analysis["recommendations"]:
        lines.append("Recommendations:")
        for rec in analysis["recommendations"]:
            lines.append(f"  - {rec}")

    return "\n".join(lines)


def format_weights(weights: dict) -> str:
    """Format weights for human reading."""
    lines = ["=== Routing Weights ===", ""]

    adjustments = weights.get("adjustments", {})
    if adjustments:
        lines.append("Active adjustments from learnings:")
        for sys_name, adj in adjustments.items():
            sign = "+" if adj > 0 else ""
            lines.append(f"  {sys_name}: {sign}{adj}")
        lines.append("")

    lines.append("Effective weights (base + adjustments):")
    for task_type, sys_weights in weights["effective_weights"].items():
        sorted_sys = sorted(sys_weights.items(), key=lambda kv: kv[1], reverse=True)
        sys_str = ", ".join(f"{s}={w}" for s, w in sorted_sys)
        lines.append(f"  {task_type}: {sys_str}")

    return "\n".join(lines)


# ---------------------------------------------------------------------------
# Instinct Evolution (adapted from ECC /evolve + continuous-learning-v2)
# ---------------------------------------------------------------------------

INSTINCTS_FILE = MESH_DIR / "instincts.json"


def extract_instincts(period_days: int = 30) -> list[dict]:
    """Extract instincts (recurring patterns) from learnings.

    An instinct is a pattern like:
    - "claude-code succeeds 95% on coding tasks"
    - "perplexity-browser is best for research"
    - "codex fails frequently on quick_answer tasks"

    Each instinct has a confidence score (0.0-1.0) based on evidence.
    """
    data = load_learnings()
    if not data:
        return []

    now = datetime.now(timezone.utc)

    # Group by (system, task_type)
    combos: dict[tuple, list[dict]] = defaultdict(list)
    for entry in data:
        try:
            ts = datetime.fromisoformat(entry["timestamp"])
            if ts.tzinfo is None:
                ts = ts.replace(tzinfo=timezone.utc)
            if (now - ts).days > period_days:
                continue
        except (ValueError, KeyError):
            continue

        key = (entry.get("system", "?"), entry.get("task_type", "?"))
        combos[key].append(entry)

    instincts = []
    for (system, task_type), entries in combos.items():
        total = len(entries)
        if total < 2:
            continue  # Need at least 2 samples

        successes = sum(1 for e in entries if e.get("success"))
        success_rate = successes / total
        avg_cost = sum(e.get("cost", 0) for e in entries) / total
        avg_duration = sum(e.get("duration_seconds", 0) for e in entries) / total

        # Confidence based on sample size and consistency
        # More samples = higher confidence, more consistent = higher confidence
        sample_confidence = min(1.0, total / 10)  # Cap at 10 samples
        consistency = 1.0 - abs(success_rate - round(success_rate))  # How close to 0 or 1
        confidence = round(sample_confidence * 0.6 + consistency * 0.4, 2)

        # Determine instinct type
        if success_rate >= 0.9:
            instinct_type = "strong_positive"
            trigger = f"When routing {task_type} tasks"
            action = f"Prefer {system} (high success rate)"
        elif success_rate <= 0.3:
            instinct_type = "strong_negative"
            trigger = f"When routing {task_type} tasks"
            action = f"Avoid {system} (low success rate)"
        elif avg_cost > 0.1:
            instinct_type = "cost_warning"
            trigger = f"When {system} is selected for {task_type}"
            action = f"Consider cheaper alternatives (avg ${avg_cost:.4f}/task)"
        else:
            instinct_type = "neutral"
            trigger = f"When routing {task_type} tasks"
            action = f"{system} has {success_rate:.0%} success rate"

        instincts.append({
            "id": f"instinct-{system}-{task_type}",
            "type": instinct_type,
            "trigger": trigger,
            "action": action,
            "system": system,
            "task_type": task_type,
            "confidence": confidence,
            "evidence": {
                "total_samples": total,
                "success_rate": round(success_rate, 2),
                "avg_cost": round(avg_cost, 4),
                "avg_duration_s": round(avg_duration, 1),
            },
            "extracted_at": now.isoformat(),
        })

    # Sort by confidence descending
    instincts.sort(key=lambda x: x["confidence"], reverse=True)
    return instincts


def cluster_instincts(instincts: list[dict]) -> dict:
    """Cluster instincts into higher-level patterns (ECC /evolve pattern).

    Clusters by system (what's a system good/bad at overall) and by
    task_type (which system is best for each task type).
    """
    by_system: dict[str, list[dict]] = defaultdict(list)
    by_task_type: dict[str, list[dict]] = defaultdict(list)

    for inst in instincts:
        by_system[inst["system"]].append(inst)
        by_task_type[inst["task_type"]].append(inst)

    clusters = {
        "system_profiles": {},
        "task_type_rankings": {},
        "routing_rules": [],
    }

    # System profiles
    for system, system_instincts in by_system.items():
        strengths = [i for i in system_instincts if i["type"] == "strong_positive"]
        weaknesses = [i for i in system_instincts if i["type"] == "strong_negative"]
        clusters["system_profiles"][system] = {
            "strengths": [i["task_type"] for i in strengths],
            "weaknesses": [i["task_type"] for i in weaknesses],
            "total_instincts": len(system_instincts),
            "avg_confidence": round(
                sum(i["confidence"] for i in system_instincts) / len(system_instincts), 2
            ) if system_instincts else 0,
        }

    # Task type rankings (best system for each task type)
    for task_type, type_instincts in by_task_type.items():
        ranked = sorted(
            type_instincts,
            key=lambda i: (i["evidence"]["success_rate"], -i["evidence"]["avg_cost"]),
            reverse=True,
        )
        clusters["task_type_rankings"][task_type] = [
            {
                "system": i["system"],
                "success_rate": i["evidence"]["success_rate"],
                "avg_cost": i["evidence"]["avg_cost"],
                "confidence": i["confidence"],
            }
            for i in ranked
        ]

    # Generate routing rules from strong signals
    for inst in instincts:
        if inst["confidence"] >= 0.6 and inst["type"] in ("strong_positive", "strong_negative"):
            clusters["routing_rules"].append({
                "rule": inst["action"],
                "trigger": inst["trigger"],
                "confidence": inst["confidence"],
                "evidence_samples": inst["evidence"]["total_samples"],
            })

    return clusters


def save_instincts(instincts: list[dict]) -> None:
    """Persist extracted instincts."""
    INSTINCTS_FILE.write_text(json.dumps(instincts, indent=2) + "\n")


def format_instincts(instincts: list[dict]) -> str:
    """Format instincts for human reading."""
    if not instincts:
        return "No instincts extracted yet. Record more learnings first."

    lines = ["=== Extracted Instincts ===", ""]

    for inst in instincts:
        icon = {
            "strong_positive": "+",
            "strong_negative": "X",
            "cost_warning": "$",
            "neutral": "-",
        }.get(inst["type"], "?")

        lines.append(f"  [{icon}] {inst['id']} (confidence: {inst['confidence']:.0%})")
        lines.append(f"      Trigger: {inst['trigger']}")
        lines.append(f"      Action:  {inst['action']}")
        ev = inst["evidence"]
        lines.append(f"      Evidence: {ev['total_samples']} samples, {ev['success_rate']:.0%} success, ${ev['avg_cost']:.4f}/task")
        lines.append("")

    return "\n".join(lines)


def format_clusters(clusters: dict) -> str:
    """Format clustered instincts for human reading."""
    lines = ["=== Instinct Clusters ===", ""]

    # System profiles
    lines.append("System Profiles:")
    for system, profile in clusters.get("system_profiles", {}).items():
        strengths = ", ".join(profile["strengths"]) if profile["strengths"] else "none"
        weaknesses = ", ".join(profile["weaknesses"]) if profile["weaknesses"] else "none"
        lines.append(f"  {system}:")
        lines.append(f"    Strengths: {strengths}")
        lines.append(f"    Weaknesses: {weaknesses}")
    lines.append("")

    # Task rankings
    lines.append("Best System per Task Type:")
    for task_type, rankings in clusters.get("task_type_rankings", {}).items():
        if rankings:
            best = rankings[0]
            lines.append(f"  {task_type}: {best['system']} ({best['success_rate']:.0%} success)")
    lines.append("")

    # Routing rules
    rules = clusters.get("routing_rules", [])
    if rules:
        lines.append("Generated Routing Rules:")
        for rule in rules:
            lines.append(f"  [{rule['confidence']:.0%}] {rule['rule']}")
    lines.append("")

    return "\n".join(lines)


# ---------------------------------------------------------------------------
# Per-category analysis (ECC pattern: granular breakdown)
# ---------------------------------------------------------------------------

def analyze_per_category(period_days: int = 30) -> dict:
    """Analyze learnings broken down by system AND task_type.

    ECC pattern: Don't just say 'Claude Code 85% success' — say
    'Claude Code 95% on coding, 40% on research'.
    """
    data = load_learnings()
    if not data:
        return {"error": "No learnings recorded yet"}

    now = datetime.now(timezone.utc)
    matrix: dict[str, dict[str, dict]] = defaultdict(
        lambda: defaultdict(lambda: {"total": 0, "success": 0, "cost": 0.0})
    )

    for entry in data:
        try:
            ts = datetime.fromisoformat(entry["timestamp"])
            if ts.tzinfo is None:
                ts = ts.replace(tzinfo=timezone.utc)
            if (now - ts).days > period_days:
                continue
        except (ValueError, KeyError):
            continue

        system = entry.get("system", "?")
        task_type = entry.get("task_type", "?")
        matrix[system][task_type]["total"] += 1
        if entry.get("success"):
            matrix[system][task_type]["success"] += 1
        matrix[system][task_type]["cost"] += entry.get("cost", 0)

    result = {}
    for system, types in matrix.items():
        result[system] = {}
        for task_type, stats in types.items():
            total = stats["total"]
            result[system][task_type] = {
                "total": total,
                "success_rate": round(stats["success"] / total, 2) if total > 0 else 0,
                "total_cost": round(stats["cost"], 4),
            }

    return result


# ---------------------------------------------------------------------------
# Instinct Export / Import / Status / Evolve
# Adapted from ECC commands: instinct-export, instinct-import, instinct-status, evolve, learn
# ---------------------------------------------------------------------------

INSTINCTS_INHERITED_DIR = MESH_DIR / "instincts" / "inherited"
EVOLVED_DIR = MESH_DIR / "evolved"

import yaml  # type: ignore  # optional; falls back to JSON if unavailable
import urllib.request
import hashlib
import copy


def _yaml_available() -> bool:
    try:
        import yaml as _y  # noqa: F811
        return True
    except ImportError:
        return False


def _load_instincts_from_file() -> list[dict]:
    """Load instincts from the persisted instincts file."""
    if not INSTINCTS_FILE.exists():
        return []
    try:
        return json.loads(INSTINCTS_FILE.read_text())
    except (json.JSONDecodeError, OSError):
        return []


def _load_inherited_instincts() -> list[dict]:
    """Load instincts from the inherited directory."""
    inherited: list[dict] = []
    if not INSTINCTS_INHERITED_DIR.exists():
        return inherited
    for f in sorted(INSTINCTS_INHERITED_DIR.glob("*.json")):
        try:
            data = json.loads(f.read_text())
            if isinstance(data, list):
                inherited.extend(data)
            elif isinstance(data, dict):
                inherited.append(data)
        except (json.JSONDecodeError, OSError):
            continue
    return inherited


def instinct_export(
    domain: str | None = None,
    min_confidence: float = 0.0,
    scope: str = "all",
    output_path: str | None = None,
) -> str:
    """Export instincts as portable YAML (or JSON fallback) with filtering.

    Args:
        domain: Filter to a specific domain/task_type (None = all)
        min_confidence: Minimum confidence threshold (0.0 - 1.0)
        scope: "project" | "global" | "all"
        output_path: File path to write (None = return as string)

    Returns:
        The exported content as a string.
    """
    # Gather instincts from different scopes
    project_instincts = _load_instincts_from_file()
    inherited_instincts = _load_inherited_instincts()

    if scope == "project":
        all_instincts = project_instincts
    elif scope == "global":
        all_instincts = inherited_instincts
    else:  # "all"
        # Merge: project takes precedence on ID conflicts
        by_id: dict[str, dict] = {}
        for inst in inherited_instincts:
            by_id[inst.get("id", "")] = inst
        for inst in project_instincts:
            by_id[inst.get("id", "")] = inst
        all_instincts = list(by_id.values())

    # Apply filters
    filtered = []
    for inst in all_instincts:
        if min_confidence > 0 and inst.get("confidence", 0) < min_confidence:
            continue
        if domain and inst.get("task_type", "") != domain and inst.get("domain", "") != domain:
            continue
        filtered.append(inst)

    # Sort by confidence descending
    filtered.sort(key=lambda x: x.get("confidence", 0), reverse=True)

    # Format output
    header = (
        f"# Instincts Export\n"
        f"# Generated: {datetime.now(timezone.utc).strftime('%Y-%m-%d')}\n"
        f"# Scope: {scope}\n"
        f"# Count: {len(filtered)} instincts\n"
    )

    if _yaml_available():
        import yaml as _yaml
        content = header + "\n" + _yaml.dump(filtered, default_flow_style=False, sort_keys=False)
    else:
        content = header + "\n" + json.dumps(filtered, indent=2)

    if output_path:
        Path(output_path).parent.mkdir(parents=True, exist_ok=True)
        Path(output_path).write_text(content)

    return content


def instinct_import(
    source: str,
    dry_run: bool = False,
    force: bool = False,
    min_confidence: float = 0.0,
    scope: str = "project",
) -> dict:
    """Import instincts from a file path or URL with conflict detection.

    Args:
        source: Local file path or HTTP(S) URL
        dry_run: Preview without importing
        force: Skip confirmation / auto-resolve conflicts
        min_confidence: Only import instincts above this threshold
        scope: "project" | "global"

    Returns:
        Summary dict with added, updated, skipped counts and details.
    """
    # Fetch content
    if source.startswith("http://") or source.startswith("https://"):
        resp = urllib.request.urlopen(source)
        raw = resp.read().decode("utf-8")
    else:
        raw = Path(source).read_text()

    # Parse (try YAML first, fall back to JSON)
    incoming: list[dict] = []
    if _yaml_available():
        import yaml as _yaml
        try:
            parsed = _yaml.safe_load(raw)
            if isinstance(parsed, list):
                incoming = parsed
            elif isinstance(parsed, dict):
                incoming = [parsed]
        except Exception:
            pass

    if not incoming:
        try:
            parsed = json.loads(raw)
            if isinstance(parsed, list):
                incoming = parsed
            elif isinstance(parsed, dict):
                incoming = [parsed]
        except json.JSONDecodeError:
            return {"error": f"Could not parse {source} as YAML or JSON"}

    # Filter by min_confidence
    if min_confidence > 0:
        incoming = [i for i in incoming if i.get("confidence", 0) >= min_confidence]

    # Load existing instincts
    existing = _load_instincts_from_file()
    existing_by_id: dict[str, dict] = {i.get("id", ""): i for i in existing}

    added: list[dict] = []
    updated: list[dict] = []
    skipped: list[dict] = []

    for inst in incoming:
        inst_id = inst.get("id", hashlib.md5(json.dumps(inst, sort_keys=True).encode()).hexdigest()[:12])
        inst["id"] = inst_id
        inst["source"] = "inherited"
        inst["imported_from"] = source

        if inst_id in existing_by_id:
            existing_conf = existing_by_id[inst_id].get("confidence", 0)
            incoming_conf = inst.get("confidence", 0)

            if incoming_conf > existing_conf or force:
                updated.append(inst)
                if not dry_run:
                    existing_by_id[inst_id] = inst
            else:
                skipped.append({"id": inst_id, "reason": "existing confidence >= import"})
        else:
            added.append(inst)
            if not dry_run:
                existing_by_id[inst_id] = inst

    # Save
    if not dry_run:
        merged = list(existing_by_id.values())
        save_instincts(merged)

        # Also save to inherited directory for scope tracking
        if scope == "global" or scope == "project":
            target_dir = INSTINCTS_INHERITED_DIR
            target_dir.mkdir(parents=True, exist_ok=True)
            import_slug = hashlib.md5(source.encode()).hexdigest()[:8]
            target_file = target_dir / f"import-{import_slug}.json"
            target_file.write_text(json.dumps(added + updated, indent=2) + "\n")

    return {
        "source": source,
        "dry_run": dry_run,
        "total_in_file": len(incoming),
        "added": len(added),
        "updated": len(updated),
        "skipped": len(skipped),
        "added_ids": [i.get("id") for i in added],
        "updated_ids": [i.get("id") for i in updated],
        "skipped_details": skipped,
    }


def instinct_status() -> dict:
    """Show instincts grouped by domain with confidence scores.

    Returns structured status with project and inherited instincts,
    grouped by domain/task_type.
    """
    project = _load_instincts_from_file()
    inherited = _load_inherited_instincts()

    # Merge with project precedence
    by_id: dict[str, dict] = {}
    for inst in inherited:
        inst_copy = dict(inst)
        inst_copy["_scope"] = "inherited"
        by_id[inst_copy.get("id", "")] = inst_copy
    for inst in project:
        inst_copy = dict(inst)
        inst_copy["_scope"] = "project"
        by_id[inst_copy.get("id", "")] = inst_copy

    all_instincts = list(by_id.values())

    # Group by domain (using task_type as domain)
    by_domain: dict[str, list[dict]] = defaultdict(list)
    for inst in all_instincts:
        domain = inst.get("domain", inst.get("task_type", "general"))
        by_domain[domain].append(inst)

    # Sort each domain by confidence
    for domain in by_domain:
        by_domain[domain].sort(key=lambda x: x.get("confidence", 0), reverse=True)

    project_count = sum(1 for i in all_instincts if i.get("_scope") == "project")
    inherited_count = sum(1 for i in all_instincts if i.get("_scope") == "inherited")

    return {
        "total": len(all_instincts),
        "project_count": project_count,
        "inherited_count": inherited_count,
        "domains": {
            domain: [
                {
                    "id": i.get("id", "?"),
                    "confidence": i.get("confidence", 0),
                    "scope": i.get("_scope", "?"),
                    "trigger": i.get("trigger", ""),
                    "action": i.get("action", ""),
                    "type": i.get("type", "neutral"),
                }
                for i in instincts
            ]
            for domain, instincts in sorted(by_domain.items())
        },
    }


def format_instinct_status(status: dict) -> str:
    """Format instinct_status output for human reading."""
    if not status.get("total"):
        return "No instincts found. Run 'learn.py instincts --save' to extract from learnings."

    lines = [
        "=" * 60,
        "  INSTINCT STATUS - {} total".format(status["total"]),
        "=" * 60,
        "",
        "  Project instincts: {}".format(status["project_count"]),
        "  Inherited instincts: {}".format(status["inherited_count"]),
        "",
    ]

    for domain, instincts in status.get("domains", {}).items():
        lines.append("  ## {} ({})".format(domain.upper(), len(instincts)))
        for inst in instincts:
            conf = inst.get("confidence", 0)
            bar_filled = int(conf * 10)
            bar = "\u2588" * bar_filled + "\u2591" * (10 - bar_filled)
            scope_tag = "[{}]".format(inst.get("scope", "?"))
            lines.append("    {} {:>3.0f}%  {} {}".format(bar, conf * 100, inst["id"], scope_tag))
            if inst.get("trigger"):
                lines.append("              trigger: {}".format(inst["trigger"]))
        lines.append("")

    return "\n".join(lines)


def evolve(
    period_days: int = 30,
    generate: bool = False,
) -> dict:
    """Analyze instincts and generate evolved structures (skills/commands/agents).

    Clusters related instincts and identifies candidates for:
    - Commands: user-invoked repeatable sequences
    - Skills: auto-triggered behavioral patterns
    - Agents: complex multi-step processes

    Args:
        period_days: Analysis period for instinct extraction
        generate: If True, write evolved files to disk

    Returns:
        Analysis dict with skill, command, and agent candidates.
    """
    instincts = extract_instincts(period_days)
    if not instincts:
        return {"error": "No instincts to evolve. Record more learnings first.", "instincts": 0}

    # Cluster by trigger pattern and domain
    by_trigger_prefix: dict[str, list[dict]] = defaultdict(list)
    by_domain: dict[str, list[dict]] = defaultdict(list)

    for inst in instincts:
        trigger = inst.get("trigger", "")
        # Extract trigger prefix (e.g., "When routing X tasks" -> "routing")
        words = trigger.lower().split()
        prefix = words[1] if len(words) > 1 else "general"
        by_trigger_prefix[prefix].append(inst)

        domain = inst.get("task_type", "general")
        by_domain[domain].append(inst)

    high_confidence = [i for i in instincts if i.get("confidence", 0) >= 0.8]

    # Identify skill candidates: clusters of 2+ instincts with similar triggers
    skill_candidates = []
    for prefix, cluster in by_trigger_prefix.items():
        if len(cluster) >= 2:
            avg_conf = sum(i.get("confidence", 0) for i in cluster) / len(cluster)
            domains = list(set(i.get("task_type", "?") for i in cluster))
            skill_candidates.append({
                "name": "{}-optimization".format(prefix),
                "trigger_prefix": prefix,
                "instinct_count": len(cluster),
                "avg_confidence": round(avg_conf, 2),
                "domains": domains,
                "instinct_ids": [i.get("id", "?") for i in cluster],
            })

    # Identify command candidates: high-confidence instincts with actionable triggers
    command_candidates = []
    for inst in high_confidence:
        if inst.get("type") in ("strong_positive", "strong_negative"):
            command_candidates.append({
                "name": "/{}-{}".format(inst.get("task_type", "task"), inst.get("system", "sys")),
                "from_instinct": inst.get("id", "?"),
                "confidence": inst.get("confidence", 0),
                "action": inst.get("action", ""),
            })

    # Identify agent candidates: domains with 3+ instincts
    agent_candidates = []
    for domain, cluster in by_domain.items():
        if len(cluster) >= 3:
            avg_conf = sum(i.get("confidence", 0) for i in cluster) / len(cluster)
            agent_candidates.append({
                "name": "{}-agent".format(domain),
                "domain": domain,
                "instinct_count": len(cluster),
                "avg_confidence": round(avg_conf, 2),
                "covers_instincts": [i.get("id", "?") for i in cluster],
            })

    result = {
        "total_instincts": len(instincts),
        "high_confidence_count": len(high_confidence),
        "skill_candidates": skill_candidates,
        "command_candidates": command_candidates,
        "agent_candidates": agent_candidates,
    }

    # Optionally generate evolved files
    if generate:
        EVOLVED_DIR.mkdir(parents=True, exist_ok=True)
        (EVOLVED_DIR / "skills").mkdir(exist_ok=True)
        (EVOLVED_DIR / "commands").mkdir(exist_ok=True)
        (EVOLVED_DIR / "agents").mkdir(exist_ok=True)

        for skill in skill_candidates:
            skill_file = EVOLVED_DIR / "skills" / "{}.md".format(skill["name"])
            content = "---\nname: {}\ndescription: Auto-evolved from {} instincts\nevolved_from:\n".format(
                skill["name"], skill["instinct_count"])
            for iid in skill["instinct_ids"]:
                content += "  - {}\n".format(iid)
            content += "---\n\n# {} Skill\n\nAvg confidence: {:.0%}\nDomains: {}\n".format(
                skill["name"].title(), skill["avg_confidence"], ", ".join(skill["domains"]))
            skill_file.write_text(content)

        for cmd in command_candidates:
            cmd_file = EVOLVED_DIR / "commands" / "{}.md".format(cmd["name"].strip("/"))
            content = "---\nname: {}\ndescription: {}\nevolved_from:\n  - {}\n---\n\n# {} Command\n\nConfidence: {:.0%}\n".format(
                cmd["name"], cmd["action"], cmd["from_instinct"],
                cmd["name"].title(), cmd["confidence"])
            cmd_file.write_text(content)

        for agent in agent_candidates:
            agent_file = EVOLVED_DIR / "agents" / "{}.md".format(agent["name"])
            content = "---\nname: {}\ndescription: Evolved agent for {} tasks\nevolved_from:\n".format(
                agent["name"], agent["domain"])
            for iid in agent["covers_instincts"]:
                content += "  - {}\n".format(iid)
            content += "---\n\n# {} Agent\n\nCovers {} instincts, avg confidence {:.0%}\n".format(
                agent["name"].title(), agent["instinct_count"], agent["avg_confidence"])
            agent_file.write_text(content)

        result["generated"] = {
            "skills": len(skill_candidates),
            "commands": len(command_candidates),
            "agents": len(agent_candidates),
            "output_dir": str(EVOLVED_DIR),
        }

    return result


def format_evolve(result: dict) -> str:
    """Format evolve output for human reading."""
    if "error" in result:
        return "[evolve] {}".format(result["error"])

    lines = [
        "=" * 60,
        "  EVOLVE ANALYSIS - {} instincts".format(result["total_instincts"]),
        "=" * 60,
        "",
        "High confidence instincts (>=80%): {}".format(result["high_confidence_count"]),
        "",
    ]

    skills = result.get("skill_candidates", [])
    if skills:
        lines.append("## SKILL CANDIDATES ({})".format(len(skills)))
        for i, s in enumerate(skills, 1):
            lines.append("  {}. {} ({} instincts, {:.0%} avg confidence)".format(
                i, s["name"], s["instinct_count"], s["avg_confidence"]))
            lines.append("     Domains: {}".format(", ".join(s["domains"])))
        lines.append("")

    commands = result.get("command_candidates", [])
    if commands:
        lines.append("## COMMAND CANDIDATES ({})".format(len(commands)))
        for cmd in commands:
            lines.append("  {} (from: {}, {:.0%})".format(
                cmd["name"], cmd["from_instinct"], cmd["confidence"]))
        lines.append("")

    agents = result.get("agent_candidates", [])
    if agents:
        lines.append("## AGENT CANDIDATES ({})".format(len(agents)))
        for a in agents:
            lines.append("  {} ({} instincts, {:.0%} avg confidence)".format(
                a["name"], a["instinct_count"], a["avg_confidence"]))
        lines.append("")

    if result.get("generated"):
        gen = result["generated"]
        lines.append("Generated files:")
        lines.append("  Skills:   {}".format(gen["skills"]))
        lines.append("  Commands: {}".format(gen["commands"]))
        lines.append("  Agents:   {}".format(gen["agents"]))
        lines.append("  Output:   {}".format(gen["output_dir"]))

    return "\n".join(lines)


def main() -> int:
    parser = argparse.ArgumentParser(description="AI Mesh Learning System")
    sub = parser.add_subparsers(dest="command")

    # record subcommand
    rec = sub.add_parser("record", help="Record a task outcome")
    rec.add_argument("--system", required=True, choices=SYSTEMS)
    rec.add_argument("--task-type", required=True, choices=TASK_TYPES)
    rec.add_argument("--time", type=float, default=0, help="Duration in seconds")
    rec.add_argument("--tokens", type=int, default=0, help="Tokens used")
    rec.add_argument("--cost", type=float, default=0, help="Cost in USD")
    rec.add_argument("--task", default="", help="Task description")
    success_group = rec.add_mutually_exclusive_group(required=True)
    success_group.add_argument("--success", action="store_true")
    success_group.add_argument("--fail", action="store_true")

    # analyze subcommand
    ana = sub.add_parser("analyze", help="Analyze learnings")
    ana.add_argument("--days", type=int, default=30, help="Analysis period in days")
    ana.add_argument("--json", action="store_true", dest="json_output")
    ana.add_argument("--per-category", action="store_true", help="Break down by system + task_type")

    # weights subcommand
    wt = sub.add_parser("weights", help="Show current routing weights")
    wt.add_argument("--json", action="store_true", dest="json_output")

    # instincts subcommand (ECC: /evolve pattern)
    inst = sub.add_parser("instincts", help="Extract instincts from learnings")
    inst.add_argument("--days", type=int, default=30, help="Analysis period")
    inst.add_argument("--json", action="store_true", dest="json_output")
    inst.add_argument("--save", action="store_true", help="Persist instincts to file")

    # evolve subcommand (ECC: cluster instincts into routing rules + generate evolved structures)
    evo = sub.add_parser("evolve", help="Cluster instincts into routing rules and generate evolved structures")
    evo.add_argument("--days", type=int, default=30, help="Analysis period")
    evo.add_argument("--json", action="store_true", dest="json_output")
    evo.add_argument("--generate", action="store_true", help="Generate evolved files (skills/commands/agents)")

    # instinct-export subcommand
    iexp = sub.add_parser("instinct-export", help="Export instincts as portable YAML/JSON")
    iexp.add_argument("--domain", default=None, help="Filter to specific domain/task_type")
    iexp.add_argument("--min-confidence", type=float, default=0.0, help="Minimum confidence threshold")
    iexp.add_argument("--scope", choices=["project", "global", "all"], default="all")
    iexp.add_argument("--output", default=None, help="Output file path (stdout if omitted)")

    # instinct-import subcommand
    iimp = sub.add_parser("instinct-import", help="Import instincts from file or URL")
    iimp.add_argument("source", help="File path or HTTP(S) URL")
    iimp.add_argument("--dry-run", action="store_true", help="Preview without importing")
    iimp.add_argument("--force", action="store_true", help="Auto-resolve conflicts")
    iimp.add_argument("--min-confidence", type=float, default=0.0, help="Only import above threshold")
    iimp.add_argument("--scope", choices=["project", "global"], default="project")
    iimp.add_argument("--json", action="store_true", dest="json_output")

    # instinct-status subcommand
    ist = sub.add_parser("instinct-status", help="Show instincts grouped by domain")
    ist.add_argument("--json", action="store_true", dest="json_output")

    args = parser.parse_args()

    if args.command == "record":
        entry = record_learning(
            system=args.system,
            task_type=args.task_type,
            success=args.success,
            duration=args.time,
            tokens=args.tokens,
            cost=args.cost,
            task_desc=args.task,
        )
        print(f"[learn] Recorded: {entry['system']} / {entry['task_type']} / {'success' if entry['success'] else 'FAIL'}")
        return 0

    elif args.command == "analyze":
        if hasattr(args, 'per_category') and args.per_category:
            result = analyze_per_category(args.days)
            if args.json_output:
                print(json.dumps(result, indent=2))
            else:
                print("=== Per-Category Analysis ===\n")
                for system, types in sorted(result.items()):
                    print(f"  {system}:")
                    for task_type, stats in sorted(types.items()):
                        print(f"    {task_type}: {stats['success_rate']:.0%} success ({stats['total']} tasks, ${stats['total_cost']:.4f})")
                    print()
        else:
            analysis = analyze_learnings(args.days)
            if args.json_output:
                print(json.dumps(analysis, indent=2))
            else:
                print(format_analysis(analysis))
        return 0

    elif args.command == "weights":
        weights = show_weights()
        if args.json_output:
            print(json.dumps(weights, indent=2))
        else:
            print(format_weights(weights))
        return 0

    elif args.command == "instincts":
        instincts = extract_instincts(args.days)
        if args.save:
            save_instincts(instincts)
            print(f"[learn] Saved {len(instincts)} instincts to {INSTINCTS_FILE}")
        if args.json_output:
            print(json.dumps(instincts, indent=2))
        else:
            print(format_instincts(instincts))
        return 0

    elif args.command == "evolve":
        result = evolve(period_days=args.days, generate=getattr(args, "generate", False))
        if args.json_output:
            print(json.dumps(result, indent=2))
        else:
            print(format_evolve(result))
        return 0

    elif args.command == "instinct-export":
        content = instinct_export(
            domain=args.domain,
            min_confidence=args.min_confidence,
            scope=args.scope,
            output_path=args.output,
        )
        if args.output:
            print(f"[learn] Exported instincts to {args.output}")
        else:
            print(content)
        return 0

    elif args.command == "instinct-import":
        result = instinct_import(
            source=args.source,
            dry_run=args.dry_run,
            force=args.force,
            min_confidence=args.min_confidence,
            scope=args.scope,
        )
        if hasattr(args, "json_output") and args.json_output:
            print(json.dumps(result, indent=2))
        else:
            if result.get("error"):
                print(f"[learn] Error: {result['error']}")
            else:
                prefix = "[dry-run] " if result["dry_run"] else ""
                print(f"[learn] {prefix}Import from {result['source']}:")
                print(f"  Added:   {result['added']}")
                print(f"  Updated: {result['updated']}")
                print(f"  Skipped: {result['skipped']}")
        return 0

    elif args.command == "instinct-status":
        status = instinct_status()
        if args.json_output:
            print(json.dumps(status, indent=2))
        else:
            print(format_instinct_status(status))
        return 0

    else:
        parser.print_help()
        return 1


if __name__ == "__main__":
    sys.exit(main())
