#!/usr/bin/env python3
"""
Intelligent Task Router — routes tasks to the cheapest capable system.

Hard rule: subscription/free FIRST, API tokens LAST.

Usage:
    python3 mesh/router.py 'build a REST API for watch inventory'
    python3 mesh/router.py --json 'analyze the trade-offs of microservices'
"""

import argparse
import json
import os
import re
import sys
from datetime import datetime, timezone
from pathlib import Path
from typing import NamedTuple


# ---------------------------------------------------------------------------
# Domain types
# ---------------------------------------------------------------------------

class Route(NamedTuple):
    system: str
    reason: str
    cost: str
    alternatives: list  # list of (system, cost_note)


class Classification(NamedTuple):
    category: str
    confidence: float  # 0-1
    matched_keywords: list


# ---------------------------------------------------------------------------
# Keyword tables
# ---------------------------------------------------------------------------

KEYWORDS: dict[str, list[str]] = {
    "coding": [
        "build", "fix", "debug", "refactor", "test", "pr", "code",
        "implement", "function", "class", "api", "endpoint", "css",
        "html", "deploy code", "script", "bug", "lint", "compile",
        "module", "package", "import", "type error", "syntax",
        "commit", "merge", "branch", "pull request", "scaffold",
        "crud", "rest", "graphql", "database schema", "migration",
    ],
    "research": [
        "search", "find", "research", "look up", "news", "trending",
        "compare", "market", "competitor", "price", "latest",
        "who is", "when did", "where is", "current", "recent",
        "benchmark", "survey", "report",
    ],
    "reasoning": [
        "analyze", "reason", "think through", "architecture decision",
        "trade-offs", "evaluate", "design", "weigh options", "pros and cons",
        "strategy", "plan", "compare approaches", "decide between",
        "tradeoff", "trade off", "should i", "which is better",
    ],
    "long_context": [
        "large file", "entire codebase", "full document", "summarize book",
        "100k+", "100k", "200k", "300k", "400k", "500k", "600k", "700k", "800k", "900k",
        "million token", "whole repo", "all files",
        "entire project", "full log", "massive", "huge file",
        "token document", "token file", "long document", "full transcript",
    ],
    "multimodal": [
        "image", "video", "audio", "screenshot", "photo", "diagram",
        "visual", "picture", "pdf", "chart", "graph", "draw",
        "sketch", "ui mockup", "wireframe", "ocr",
        "analyze image", "analyze video", "watch this", "look at this",
        "analyze photo", "analyze screenshot",
    ],
    "embeddings": [
        "embedding", "embeddings", "vectorize", "vector", "encode",
        "vector store", "vector database", "embed text", "embed document",
    ],
    "batch": [
        "10000", "batch", "bulk", "process all", "classify all",
        "categorize all", "10k items", "batch process", "bulk process",
        "mass classify", "mass categorize",
    ],
    "research_reasoning": [
        "compare with data", "analyze market", "research and analyze",
        "latest data analysis", "research and reason", "compare with latest",
        "analyze with current data", "market analysis with data",
    ],
    "quick_answer": [
        "what is", "how to", "status", "check", "quick question",
        "define", "meaning of", "eli5", "tldr", "brief",
        "short answer", "yes or no", "true or false",
    ],
    "background": [
        "monitor", "watch", "alert", "cron", "schedule", "heartbeat",
        "poll", "daemon", "background", "recurring", "periodic",
        "every minute", "every hour", "keep running",
    ],
    "monitoring": [
        "uptime", "health check", "dashboard", "metrics", "logging",
        "observability", "trace", "span", "latency", "error rate",
    ],
}

# ---------------------------------------------------------------------------
# Routing tables — ordered by cost preference (cheapest first)
# ---------------------------------------------------------------------------

ROUTES: dict[str, list[Route]] = {
    "coding": [
        Route("claude-code",  "Primary coding agent (subscription — $0 marginal cost)",
              "$0 (subscription)", []),
        Route("codex",        "Subscription coding agent",
              "$0 (subscription)", []),
        Route("gemini-cli",   "Free-tier coding assistant",
              "$0 (free tier)", []),
        Route("openrouter-free", "Free coding models (Qwen Coder, Llama)",
              "$0 (free, rate-limited)", []),
        Route("xai-grok-code", "Grok code-fast-1 — cheap fast coding",
              "$ (pay-per-token, cheap)", []),
        Route("openai-api",   "OpenAI API — prefer Codex CLI instead",
              "$$$ (pay-per-token)", []),
        Route("anthropic-api", "Anthropic API — prefer Claude Code CLI instead",
              "$$$ (pay-per-token)", []),
        Route("openrouter-paid", "OpenRouter paid models (DeepSeek, Mistral)",
              "$$ (pay-per-token, varies)", []),
        # NEVER OpenClaw for coding
    ],
    "research": [
        Route("perplexity-browser", "Free unlimited web search via browser",
              "$0 (free unlimited)", []),
        Route("perplexity-mcp-claude", "Perplexity MCP through Claude Code",
              "$0 (MCP)", []),
        Route("perplexity-mcp-codex", "Perplexity MCP through Codex",
              "$0 (MCP)", []),
        Route("gemini-search", "Gemini search grounding",
              "$0 (free)", []),
        Route("perplexity-api", "Perplexity API — burns credit, LAST RESORT",
              "$$$ (API credits)", []),
    ],
    "reasoning": [
        Route("codex-gpt5.4-xhigh", "GPT-5.4 extended-high reasoning (subscription)",
              "$0 (subscription)", []),
        Route("gemini-pro-thinking", "Gemini Pro with thinking mode",
              "$0 (free)", []),
        Route("claude-code", "Claude Code reasoning",
              "$0 (subscription)", []),
        Route("openrouter-free", "DeepSeek R1 free — decent reasoning at $0",
              "$0 (free, rate-limited)", []),
        Route("xai-grok", "Grok-4 reasoning",
              "$ (pay-per-token)", []),
        Route("openai-api-o3", "o3 reasoning — expensive",
              "$$$ (pay-per-token)", []),
        Route("anthropic-api", "Claude API reasoning — expensive",
              "$$$ (pay-per-token)", []),
        Route("openai-api-o3-pro", "o3-pro — VERY expensive, critical reasoning ONLY",
              "$$$$ (pay-per-token, VERY expensive)", []),
    ],
    "long_context": [
        # Ultra-long context: >1M tokens
        Route("xai-grok-4-fast", "2M context — LARGEST IN MESH",
              "$ (pay-per-token, 2M tokens)", []),
        Route("gemini", "1M context window, free tier",
              "$0 (free, 1M tokens)", []),
        Route("claude-code", "1M context (Opus 4.6, subscription)",
              "$0 (subscription, 1M)", []),
        Route("codex", "200K context (subscription)",
              "$0 (subscription, 200K)", []),
        Route("anthropic-api", "1M context via API — expensive",
              "$$$ (pay-per-token)", []),
    ],
    "quick_answer": [
        Route("openclaw", "Marginal-cost quick answers",
              "~$0 (marginal)", []),
        Route("gemini-flash", "Fastest free model",
              "$0 (free)", []),
        Route("openrouter-free", "Free models for quick answers",
              "$0 (free, rate-limited)", []),
    ],
    "multimodal": [
        Route("gemini", "Native multimodal — images, video, audio analysis (free tier)",
              "$0 (free)", []),
        Route("claude-code", "Multimodal via Claude Code",
              "$0 (subscription)", []),
        Route("openclaw", "Multimodal via OpenClaw",
              "~$0 (marginal)", []),
    ],
    "embeddings": [
        Route("ollama", "Local embeddings — unlimited, $0, fast (nomic-embed-text)",
              "$0 (local)", []),
        Route("gemini", "Free embedding API",
              "$0 (free)", []),
        Route("openai-api", "OpenAI embeddings — good quality, costs money",
              "$$ (pay-per-token)", []),
    ],
    "batch": [
        Route("ollama", "Local batch processing — unlimited, $0 (Llama/Mistral)",
              "$0 (local)", []),
        Route("gemini-flash", "Fast free batch processing",
              "$0 (free)", []),
        Route("claude-code", "Batch via Claude Code (subscription)",
              "$0 (subscription)", []),
    ],
    "research_reasoning": [
        Route("perplexity+codex", "Step 1: Perplexity for research → Step 2: Codex for reasoning",
              "$0 (subscription + MCP)", []),
        Route("perplexity+claude-code", "Step 1: Perplexity for research → Step 2: Claude Code for reasoning",
              "$0 (subscription + MCP)", []),
        Route("perplexity+gemini", "Step 1: Perplexity for research → Step 2: Gemini for reasoning",
              "$0 (free + MCP)", []),
    ],
    "background": [
        Route("codex", "Background task runner (subscription)",
              "$0 (subscription)", []),
        Route("gemini-cli", "Free-tier background capable",
              "$0 (free)", []),
    ],
    "monitoring": [
        Route("codex", "Monitoring and observability tasks",
              "$0 (subscription)", []),
        Route("gemini-cli", "Free-tier monitoring",
              "$0 (free)", []),
    ],
}


# ---------------------------------------------------------------------------
# Full cost priority order (for reference and intercept logic)
# ---------------------------------------------------------------------------

COST_PRIORITY = [
    # Tier 0: Local ($0, unlimited)
    ("ollama",              "$0", "Local models — embeddings, batch, simple text (unlimited)"),
    # Tier 0: Subscription/Free ($0)
    ("claude-code",         "$0", "Anthropic Max subscription"),
    ("codex",               "$0", "OpenAI Pro subscription"),
    ("gemini-cli",          "$0", "Google AI Studio free tier"),
    ("perplexity-browser",  "$0", "Browser automation, unlimited"),
    ("perplexity-mcp",      "$0", "MCP via subscription"),
    ("openrouter-free",     "$0", "Free models, rate-limited"),
    # Tier 1: Cheap pay-per-token
    ("xai-grok",            "$",  "Check pricing — 2M context is killer feature"),
    ("gemini-api",          "$",  "Cheap pay-per-token"),
    # Tier 2: Moderate pay-per-token
    ("openai-api",          "$$", "Pay-per-token"),
    ("anthropic-api",       "$$", "Pay-per-token, expensive"),
    ("perplexity-api",      "$$", "Burns $50/mo credit"),
    ("openrouter-paid",     "$$", "Varies by model"),
    # Tier 3: Very expensive (critical only)
    ("openai-api-o3-pro",   "$$$$", "VERY expensive — critical reasoning ONLY"),
    ("openai-api-o1-pro",   "$$$$", "VERY expensive — critical reasoning ONLY"),
]


# ---------------------------------------------------------------------------
# Classifier
# ---------------------------------------------------------------------------

def classify(task: str) -> Classification:
    """Classify a task description into a category using keyword matching."""
    task_lower = task.lower()
    scores: dict[str, tuple[float, list[str]]] = {}

    for category, keywords in KEYWORDS.items():
        matched = []
        for kw in keywords:
            if kw in task_lower:
                matched.append(kw)
        if matched:
            # Weight by number of matches and keyword specificity (longer = more specific)
            weight = sum(len(kw) for kw in matched) + len(matched)
            scores[category] = (weight, matched)

    # Boost long_context if task mentions large numeric sizes (e.g. 500K, 1M, 1.5M tokens)
    size_match = re.search(r'\b(\d+(?:\.\d+)?)\s*[mM]\b|\b(\d+)[kK]\b|\b(\d+)\s*(?:thousand|million)\s*token', task_lower)
    if size_match:
        val_m = size_match.group(1)  # millions (e.g. 1.5M)
        val_k = size_match.group(2)  # thousands (e.g. 500K)
        val_w = size_match.group(3)  # word form (e.g. 1 million token)
        if val_m:
            size_k = float(val_m) * 1000  # convert M to K
        elif val_k:
            size_k = int(val_k)
        elif val_w:
            size_k = int(val_w)
        else:
            size_k = 0
        if size_k >= 100:  # 100K+ → long context
            bonus = 100 if size_k >= 1000 else 50  # extra boost for 1M+
            if "long_context" in scores:
                w, m = scores["long_context"]
                scores["long_context"] = (w + bonus, m + [size_match.group()])
            else:
                scores["long_context"] = (bonus, [size_match.group()])

    # Boost multimodal when media-specific words are present alongside analysis verbs
    media_words = {"video", "audio", "image", "photo", "picture", "screenshot"}
    if any(w in task_lower for w in media_words):
        if "multimodal" in scores:
            w, m = scores["multimodal"]
            scores["multimodal"] = (w + 60, m)  # strong boost — media content = multimodal
        else:
            matched_media = [w for w in media_words if w in task_lower]
            scores["multimodal"] = (60, matched_media)

    # Boost research_reasoning when BOTH research and reasoning keywords also match
    if "research" in scores and "reasoning" in scores:
        research_kws = scores["research"][1]
        reasoning_kws = scores["reasoning"][1]
        combined = research_kws + reasoning_kws
        if "research_reasoning" in scores:
            w, m = scores["research_reasoning"]
            scores["research_reasoning"] = (w + 80, m + combined)
        else:
            scores["research_reasoning"] = (80, combined)

    if not scores:
        # Default to quick_answer for unclassified tasks
        return Classification("quick_answer", 0.3, [])

    # Pick the highest-scoring category
    best_cat = max(scores, key=lambda c: scores[c][0])
    best_weight, best_matched = scores[best_cat]

    # Normalize confidence (heuristic: more keyword chars matched = higher confidence)
    total_possible = sum(len(kw) for kw in KEYWORDS[best_cat]) + len(KEYWORDS[best_cat])
    confidence = min(1.0, best_weight / (total_possible * 0.3))

    return Classification(best_cat, round(confidence, 2), best_matched)


# ---------------------------------------------------------------------------
# Router
# ---------------------------------------------------------------------------

def route(task: str) -> dict:
    """Route a task to the best system. Returns a structured result dict."""
    classification = classify(task)
    category = classification.category

    routes = ROUTES.get(category, ROUTES["quick_answer"])
    primary = routes[0]
    alternatives = [
        {"system": r.system, "cost": r.cost}
        for r in routes[1:]
        if r.system != primary.system
    ]

    result = {
        "task": task,
        "classification": category,
        "confidence": classification.confidence,
        "matched_keywords": classification.matched_keywords,
        "recommended": primary.system,
        "reason": primary.reason,
        "cost": primary.cost,
        "alternatives": alternatives,
    }

    # Hybrid research_reasoning gets a multi-step workflow
    if category == "research_reasoning":
        result["workflow"] = [
            {"step": 1, "action": "research", "system": "perplexity",
             "detail": "Use perplexity_search or perplexity_research to gather data"},
            {"step": 2, "action": "reason", "system": "codex",
             "detail": "Feed research results into Codex/Claude Code for analysis"},
        ]

    return result


# ---------------------------------------------------------------------------
# Usage tracking
# ---------------------------------------------------------------------------

USAGE_FILE = Path(__file__).parent / "usage.json"


def track_decision(result: dict) -> None:
    """Append a routing decision to mesh/usage.json."""
    entry = {
        "timestamp": datetime.now(timezone.utc).isoformat(),
        "task": result["task"],
        "classification": result["classification"],
        "routed_to": result["recommended"],
        "cost": result["cost"],
    }

    data: list = []
    if USAGE_FILE.exists():
        try:
            raw = USAGE_FILE.read_text(encoding="utf-8").strip()
            if raw:
                data = json.loads(raw)
                if not isinstance(data, list):
                    data = [data]
        except (json.JSONDecodeError, OSError):
            # Corrupted file — start fresh but keep a backup
            backup = USAGE_FILE.with_suffix(".json.bak")
            try:
                USAGE_FILE.rename(backup)
            except OSError:
                pass
            data = []

    data.append(entry)

    USAGE_FILE.parent.mkdir(parents=True, exist_ok=True)
    USAGE_FILE.write_text(
        json.dumps(data, indent=2, ensure_ascii=False) + "\n",
        encoding="utf-8",
    )


# ---------------------------------------------------------------------------
# Output formatters
# ---------------------------------------------------------------------------

def format_human(result: dict) -> str:
    """Pretty human-readable output."""
    alts = ", ".join(
        f"{a['system']} ({a['cost']})" for a in result["alternatives"]
    )
    lines = [
        f"Task: {result['task']}",
        f"Classification: {result['classification']}",
        f"Recommended: {result['recommended']}",
        f"Reason: {result['reason']}",
        f"Alternatives: {alts if alts else '(none)'}",
        f"Cost: {result['cost']}",
    ]
    if result["matched_keywords"]:
        lines.append(f"Matched keywords: {', '.join(result['matched_keywords'])}")
    if "workflow" in result:
        lines.append("Workflow:")
        for step in result["workflow"]:
            lines.append(f"  Step {step['step']}: [{step['system']}] {step['detail']}")
    return "\n".join(lines)


def format_json(result: dict) -> str:
    """Machine-readable JSON output."""
    return json.dumps(result, indent=2, ensure_ascii=False)


# ---------------------------------------------------------------------------
# CLI
# ---------------------------------------------------------------------------

def apply_learned_weights(result: dict) -> dict:
    """Apply learning-based weight adjustments to routing result.

    ECC Pattern: Instinct-based confidence scoring — learnings from past
    outcomes adjust routing confidence and may reorder recommendations.
    """
    learnings_file = Path(__file__).parent / "learnings.json"
    if not learnings_file.exists():
        return result

    try:
        data = json.loads(learnings_file.read_text())
        if not isinstance(data, list) or not data:
            return result
    except (json.JSONDecodeError, OSError):
        return result

    # Compute per-system success rates for this task category
    now = datetime.now(timezone.utc)
    category = result.get("classification", "")
    system_stats: dict[str, dict] = {}

    for entry in data:
        try:
            ts = datetime.fromisoformat(entry["timestamp"])
            if ts.tzinfo is None:
                ts = ts.replace(tzinfo=timezone.utc)
            if (now - ts).days > 30:
                continue
        except (ValueError, KeyError):
            continue

        if entry.get("task_type") != category:
            continue

        sys_name = entry.get("system", "")
        if sys_name not in system_stats:
            system_stats[sys_name] = {"total": 0, "success": 0}
        system_stats[sys_name]["total"] += 1
        if entry.get("success"):
            system_stats[sys_name]["success"] += 1

    if not system_stats:
        return result

    # Compute confidence adjustments
    learning_insights = []
    recommended = result.get("recommended", "")
    rec_stats = system_stats.get(recommended)

    if rec_stats and rec_stats["total"] >= 3:
        rate = rec_stats["success"] / rec_stats["total"]
        if rate < 0.7:
            # Primary system has low success — warn and suggest alternative
            learning_insights.append(
                f"WARNING: {recommended} has {rate:.0%} success rate for {category} "
                f"tasks ({rec_stats['total']} samples). Consider alternatives."
            )
            # Adjust confidence down
            result["confidence"] = round(result.get("confidence", 0.5) * rate, 2)
        elif rate > 0.9:
            learning_insights.append(
                f"Confirmed: {recommended} has {rate:.0%} success rate for {category} "
                f"({rec_stats['total']} samples)"
            )
            result["confidence"] = round(min(1.0, result.get("confidence", 0.5) * 1.1), 2)

    # Check if any alternative has better success rate
    for sys_name, stats in system_stats.items():
        if sys_name == recommended or stats["total"] < 3:
            continue
        rate = stats["success"] / stats["total"]
        if rec_stats and rec_stats["total"] >= 3:
            rec_rate = rec_stats["success"] / rec_stats["total"]
            if rate > rec_rate + 0.15:  # 15% better
                learning_insights.append(
                    f"ALTERNATIVE: {sys_name} has {rate:.0%} success vs "
                    f"{rec_rate:.0%} for {recommended} — consider switching"
                )

    if learning_insights:
        result["learning_insights"] = learning_insights

    return result


def main() -> int:
    parser = argparse.ArgumentParser(
        description="Intelligent task router — routes to cheapest capable system.",
        usage="python3 mesh/router.py [-h] [--json] task",
    )
    parser.add_argument(
        "task",
        nargs="?",
        help="Task description to route (e.g. 'build a REST API for watch inventory')",
    )
    parser.add_argument(
        "--json",
        action="store_true",
        dest="json_output",
        help="Output in machine-readable JSON format",
    )
    parser.add_argument(
        "--no-learn",
        action="store_true",
        help="Skip learning-based adjustments",
    )

    args = parser.parse_args()

    if not args.task:
        parser.print_help()
        return 1

    result = route(args.task)

    # Apply learning feedback loop (ECC pattern: instinct system)
    if not args.no_learn:
        result = apply_learned_weights(result)

    track_decision(result)

    if args.json_output:
        print(format_json(result))
    else:
        print(format_human(result))
        # Print learning insights if any
        insights = result.get("learning_insights", [])
        if insights:
            print("\nLearning Insights:")
            for insight in insights:
                print(f"  * {insight}")

    return 0


if __name__ == "__main__":
    sys.exit(main())
