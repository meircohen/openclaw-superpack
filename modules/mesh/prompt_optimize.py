#!/usr/bin/env python3
"""
Prompt Optimizer for AI Mesh
Adapted from ECC /prompt-optimize command.

Analyzes user prompts and suggests optimal mesh routing:
- Intent detection (feature, bugfix, refactor, research, testing, review)
- Scope assessment (trivial → epic)
- System matching (which mesh system is best)
- Missing context detection
- Optimized prompt generation

Advisory only — does NOT execute.

Usage:
    python3 mesh/prompt_optimize.py "Add user authentication to the API"
    python3 mesh/prompt_optimize.py --json "Fix the race condition in queue.py"
"""

import argparse
import json
import os
import re
import sys
from typing import Any, Dict, List, Optional, Tuple

MESH_DIR = os.path.dirname(os.path.abspath(__file__))

# Intent patterns: (intent, keywords, confidence_boost)
INTENT_PATTERNS = [
    ("feature", ["add", "create", "build", "implement", "new", "introduce", "enable", "support"], 0.8),
    ("bugfix", ["fix", "bug", "broken", "crash", "error", "issue", "wrong", "fail", "regression"], 0.9),
    ("refactor", ["refactor", "clean", "reorganize", "split", "extract", "rename", "move", "simplify"], 0.85),
    ("research", ["research", "compare", "evaluate", "investigate", "find", "explore", "what is", "how does"], 0.8),
    ("testing", ["test", "coverage", "spec", "e2e", "unit test", "integration test", "tdd"], 0.85),
    ("review", ["review", "audit", "check", "inspect", "analyze", "assess", "validate"], 0.8),
    ("docs", ["document", "readme", "docs", "comment", "explain", "describe"], 0.8),
    ("infra", ["deploy", "ci", "cd", "docker", "kubernetes", "terraform", "aws", "gcp", "pipeline"], 0.8),
    ("security", ["security", "vulnerability", "owasp", "injection", "xss", "csrf", "auth", "encrypt"], 0.85),
    ("performance", ["optimize", "slow", "fast", "performance", "latency", "memory", "cpu", "cache"], 0.8),
]

# Scope heuristics
SCOPE_INDICATORS = {
    "trivial": {
        "max_words": 10,
        "patterns": ["typo", "rename", "update version", "bump", "one-liner"],
    },
    "low": {
        "max_words": 20,
        "patterns": ["simple", "small", "quick", "minor", "tweak"],
    },
    "medium": {
        "max_words": 50,
        "patterns": ["feature", "module", "component", "endpoint", "page"],
    },
    "high": {
        "max_words": 100,
        "patterns": ["system", "architecture", "migration", "overhaul", "redesign"],
    },
    "epic": {
        "max_words": 999,
        "patterns": ["rewrite", "from scratch", "entire", "full", "complete redesign", "v2"],
    },
}

# System recommendations by intent
SYSTEM_MATRIX = {
    "feature": [
        ("claude-code", "Interactive implementation with TDD", 0.9),
        ("codex", "Async implementation for large features", 0.7),
    ],
    "bugfix": [
        ("claude-code", "Systematic debugging with root cause analysis", 0.95),
        ("codex", "Async fix for well-understood bugs", 0.5),
    ],
    "refactor": [
        ("claude-code", "Interactive refactoring with verification", 0.9),
        ("codex", "Async refactoring for mechanical changes", 0.6),
    ],
    "research": [
        ("perplexity", "Deep web research with citations", 0.95),
        ("gemini", "Fast research with Google grounding", 0.7),
        ("claude-code", "Codebase research and analysis", 0.6),
    ],
    "testing": [
        ("claude-code", "TDD workflow with test-first", 0.9),
        ("codex", "Bulk test generation", 0.7),
    ],
    "review": [
        ("claude-code", "Interactive code review", 0.9),
        ("codex", "Async code audit", 0.6),
    ],
    "docs": [
        ("claude-code", "Documentation with code context", 0.8),
        ("gemini", "Fast documentation generation", 0.6),
    ],
    "infra": [
        ("claude-code", "Infrastructure setup and debugging", 0.8),
        ("codex", "Async infrastructure changes", 0.6),
    ],
    "security": [
        ("claude-code", "Security audit with mesh/security_scan.py", 0.9),
        ("perplexity", "CVE research and best practices", 0.7),
    ],
    "performance": [
        ("claude-code", "Profiling and optimization", 0.85),
        ("codex", "Async optimization for known patterns", 0.5),
    ],
}


def detect_intent(prompt):
    # type: (str) -> List[Tuple[str, float]]
    """Detect task intent from prompt text."""
    lower = prompt.lower()
    scores = []  # type: List[Tuple[str, float]]

    for intent, keywords, base_confidence in INTENT_PATTERNS:
        matches = sum(1 for kw in keywords if kw in lower)
        if matches > 0:
            # More keyword matches = higher confidence
            confidence = min(base_confidence + (matches - 1) * 0.05, 1.0)
            scores.append((intent, round(confidence, 2)))

    scores.sort(key=lambda x: x[1], reverse=True)
    return scores or [("feature", 0.3)]  # Default to feature with low confidence


def assess_scope(prompt):
    # type: (str) -> Tuple[str, float]
    """Assess task scope from prompt."""
    word_count = len(prompt.split())
    lower = prompt.lower()

    for scope in ["epic", "high", "medium", "low", "trivial"]:
        indicators = SCOPE_INDICATORS[scope]
        pattern_match = any(p in lower for p in indicators["patterns"])
        if pattern_match:
            return (scope, 0.8)

    # Fallback to word count heuristic
    if word_count <= 10:
        return ("trivial", 0.5)
    elif word_count <= 20:
        return ("low", 0.5)
    elif word_count <= 50:
        return ("medium", 0.5)
    elif word_count <= 100:
        return ("high", 0.5)
    else:
        return ("epic", 0.5)


def detect_missing_context(prompt, intent):
    # type: (str, str) -> List[str]
    """Detect potentially missing context in the prompt."""
    gaps = []
    lower = prompt.lower()

    # Universal gaps
    if len(prompt.split()) < 15:
        gaps.append("Consider adding more detail about expected behavior")

    # Intent-specific gaps
    if intent == "bugfix":
        if "error" not in lower and "message" not in lower and "stack" not in lower:
            gaps.append("Include the error message or stack trace")
        if "repro" not in lower and "reproduce" not in lower and "steps" not in lower:
            gaps.append("Describe steps to reproduce the bug")
        if "expect" not in lower:
            gaps.append("Describe expected vs. actual behavior")

    if intent == "feature":
        if "accept" not in lower and "criteria" not in lower and "should" not in lower:
            gaps.append("Add acceptance criteria (what 'done' looks like)")
        if "test" not in lower:
            gaps.append("Mention testing requirements")

    if intent == "refactor":
        if "why" not in lower and "reason" not in lower:
            gaps.append("Explain why this refactoring is needed")

    if intent == "security":
        if "scope" not in lower and "file" not in lower and "endpoint" not in lower:
            gaps.append("Specify what code/endpoints to scan")

    return gaps


def recommend_systems(intent, scope):
    # type: (str, str) -> List[Dict[str, Any]]
    """Recommend mesh systems for the task."""
    recs = SYSTEM_MATRIX.get(intent, SYSTEM_MATRIX["feature"])

    # Adjust for scope
    adjusted = []
    for system, reason, confidence in recs:
        adj_conf = confidence
        if scope in ("epic", "high") and system == "codex":
            adj_conf += 0.15  # Codex better for large async tasks
        if scope == "trivial" and system == "gemini":
            adj_conf += 0.1  # Gemini fast for simple tasks
        adjusted.append({
            "system": system,
            "reason": reason,
            "confidence": round(min(adj_conf, 1.0), 2),
        })

    adjusted.sort(key=lambda x: x["confidence"], reverse=True)
    return adjusted


def recommend_workflow(intent, scope):
    # type: (str, str) -> Optional[str]
    """Recommend orchestration workflow."""
    if scope in ("high", "epic"):
        if intent == "feature":
            return "orchestrate feature"
        elif intent == "refactor":
            return "orchestrate refactor"
        elif intent == "security":
            return "orchestrate security-audit"
    if intent == "research":
        return "orchestrate research"
    if intent == "bugfix":
        return "orchestrate bugfix"
    return None


def optimize_prompt(prompt, intent, scope, systems, gaps):
    # type: (str, str, str, List[Dict], List[str]) -> str
    """Generate optimized prompt."""
    lines = []
    primary = systems[0]["system"] if systems else "claude-code"

    lines.append("# Optimized for: {} ({})".format(primary, intent))
    lines.append("")
    lines.append(prompt)

    if gaps:
        lines.append("")
        lines.append("## Suggested additions:")
        for gap in gaps:
            lines.append("- {}".format(gap))

    if intent in ("feature", "bugfix") and scope not in ("trivial", "low"):
        lines.append("")
        lines.append("## Workflow hint:")
        lines.append("- Use TDD: write failing test first, then implement")
        lines.append("- Use verify.py before committing")

    return "\n".join(lines)


def analyze(prompt):
    # type: (str) -> Dict[str, Any]
    """Full prompt analysis."""
    intents = detect_intent(prompt)
    primary_intent = intents[0][0]
    intent_confidence = intents[0][1]

    scope, scope_confidence = assess_scope(prompt)
    gaps = detect_missing_context(prompt, primary_intent)
    systems = recommend_systems(primary_intent, scope)
    workflow = recommend_workflow(primary_intent, scope)
    optimized = optimize_prompt(prompt, primary_intent, scope, systems, gaps)

    return {
        "original_prompt": prompt,
        "intent": {
            "primary": primary_intent,
            "confidence": intent_confidence,
            "alternatives": intents[1:3],
        },
        "scope": {
            "level": scope,
            "confidence": scope_confidence,
        },
        "missing_context": gaps,
        "recommended_systems": systems,
        "recommended_workflow": workflow,
        "optimized_prompt": optimized,
    }


def print_analysis(result):
    # type: (Dict) -> None
    """Print human-readable analysis."""
    print("\n" + "=" * 60)
    print("PROMPT OPTIMIZATION")
    print("=" * 60)
    print("Original: {}".format(result["original_prompt"][:80]))
    print("-" * 60)

    intent = result["intent"]
    print("  Intent:  {} (confidence: {:.0%})".format(
        intent["primary"].upper(), intent["confidence"]))
    if intent["alternatives"]:
        alts = ", ".join("{} ({:.0%})".format(a[0], a[1]) for a in intent["alternatives"])
        print("  Also:    {}".format(alts))

    scope = result["scope"]
    print("  Scope:   {} (confidence: {:.0%})".format(
        scope["level"].upper(), scope["confidence"]))

    print("\n  Recommended Systems:")
    for sys_rec in result["recommended_systems"]:
        print("    {} ({:.0%}) — {}".format(
            sys_rec["system"], sys_rec["confidence"], sys_rec["reason"]))

    if result["recommended_workflow"]:
        print("\n  Workflow: python3 mesh/{}.py".format(
            result["recommended_workflow"].replace(" ", ".py ")))

    gaps = result["missing_context"]
    if gaps:
        print("\n  Missing Context ({} gaps):".format(len(gaps)))
        for gap in gaps:
            print("    ? {}".format(gap))

    print("\n  Optimized Prompt:")
    print("  " + "-" * 40)
    for line in result["optimized_prompt"].split("\n"):
        print("  {}".format(line))
    print("  " + "-" * 40)

    print("=" * 60 + "\n")


def main():
    parser = argparse.ArgumentParser(description="Mesh Prompt Optimizer")
    parser.add_argument("prompt", nargs="?", help="Prompt to optimize")
    parser.add_argument("--json", action="store_true", help="JSON output")
    parser.add_argument("--stdin", action="store_true", help="Read prompt from stdin")
    args = parser.parse_args()

    if args.stdin:
        prompt = sys.stdin.read().strip()
    elif args.prompt:
        prompt = args.prompt
    else:
        parser.print_help()
        sys.exit(1)

    result = analyze(prompt)

    if args.json:
        print(json.dumps(result, indent=2))
    else:
        print_analysis(result)


if __name__ == "__main__":
    main()
