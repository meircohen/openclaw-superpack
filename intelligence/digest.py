#!/usr/bin/env python3
"""
OpenClaw Intelligence Digest — v1
Reads hot.json and synthesized items, formats daily digest.md + injects weekly summary into MEMORY.md.

Usage:
    python3 digest.py           # generate today's digest
    python3 digest.py --weekly  # also update MEMORY.md (run on Sundays)
    python3 digest.py --stdout  # print to stdout without writing files
"""

import argparse
from collections import Counter
import json
import logging
import sys
from datetime import datetime, timezone
from pathlib import Path

logging.basicConfig(level=logging.INFO, format="%(asctime)s [digest] %(levelname)s %(message)s", datefmt="%H:%M:%S")
log = logging.getLogger("digest")

# ── Paths ──────────────────────────────────────────────────────────────────────
BASE = Path(__file__).parent
HOT_FILE = BASE / "hot.json"
ITEMS_DIR = BASE / "items"
DIGEST_FILE = BASE / "digest.md"
MEMORY_FILE = BASE.parent / "MEMORY.md"  # ~/.openclaw/workspace/MEMORY.md
LAST_RUN_FILE = BASE / "actions" / "last_run.json"
LEARNINGS_FILE = Path.home() / ".openclaw" / "workspace" / "memory" / "intel" / "learnings.md"


def load_hot_items() -> list[dict]:
    if not HOT_FILE.exists():
        return []
    try:
        return json.loads(HOT_FILE.read_text())
    except Exception:
        return []


def format_actionability_emoji(act: str) -> str:
    return {"act_now": "🔴", "evaluate": "🟡", "monitor": "🟢", "none": "⚪"}.get(act, "⚪")


def format_item_block(item: dict) -> str:
    classification = item.get("classification") or {}
    synthesis = item.get("synthesis") or {}

    title = item.get("title", "Untitled")[:80]
    url = item.get("url", "")
    source = item.get("source", "unknown")
    rel_score = classification.get("relevance_score", 0)
    actionability = classification.get("actionability", "none")
    oc_rel = classification.get("openclaw_relevance", False)
    tags = classification.get("tags", [])
    category = classification.get("category", "other")
    threat_opp = classification.get("threat_opportunity", "neutral")

    headline = synthesis.get("headline", title)
    why = synthesis.get("why_it_matters", "")
    action = synthesis.get("action", "")

    act_emoji = format_actionability_emoji(actionability)
    oc_badge = " 🦞" if oc_rel else ""
    threat_badge = " ⚠️" if threat_opp == "threat" else (" 💡" if threat_opp == "opportunity" else "")

    lines = [
        f"### {act_emoji} {headline}{oc_badge}{threat_badge}",
        f"**Source:** {source} | **Relevance:** {rel_score}/10 | **Category:** {category}",
        f"**Tags:** {', '.join(tags) if tags else 'none'}",
        f"**URL:** {url}",
    ]
    if why:
        lines.append(f"\n> {why}")
    if action and action != "No action needed":
        lines.append(f"\n**→ Action:** {action}")
    lines.append("")
    return "\n".join(lines)


def generate_digest(items: list[dict], weekly: bool = False) -> str:
    now = datetime.now(timezone.utc)
    date_str = now.strftime("%A, %B %d %Y")

    act_now = [i for i in items if i.get("classification", {}).get("actionability") == "act_now"]
    evaluate = [i for i in items if i.get("classification", {}).get("actionability") == "evaluate"]
    monitor = [i for i in items if i.get("classification", {}).get("actionability") == "monitor"]
    oc_items = [i for i in items if i.get("classification", {}).get("openclaw_relevance")]

    lines = [
        f"# 🧠 Intelligence Digest — {date_str}",
        f"*Generated at {now.strftime('%H:%M')} UTC | {len(items)} high-signal items*",
        "",
    ]

    # Summary stats
    lines += [
        "## Summary",
        f"| Priority | Count |",
        f"|----------|-------|",
        f"| 🔴 Act Now | {len(act_now)} |",
        f"| 🟡 Evaluate | {len(evaluate)} |",
        f"| 🟢 Monitor | {len(monitor)} |",
        f"| 🦞 OpenClaw-specific | {len(oc_items)} |",
        "",
    ]

    if act_now:
        lines.append("---\n## 🔴 Act Now\n")
        for item in act_now:
            lines.append(format_item_block(item))

    if evaluate:
        lines.append("---\n## 🟡 Evaluate\n")
        for item in evaluate:
            lines.append(format_item_block(item))

    if monitor:
        lines.append("---\n## 🟢 Monitor\n")
        for item in monitor[:10]:  # cap at 10 for readability
            lines.append(format_item_block(item))

    lines += [
        "---",
        f"*Next collection: ~6h | To recalibrate: `python3 review.py`*",
        "",
    ]

    return "\n".join(lines)


def generate_memory_entry(items: list[dict]) -> str:
    """
    Compact MEMORY.md entry — concept-first format for good memory_search retrieval.
    One entry per high-signal item, max 5 items to avoid token bloat.
    """
    now = datetime.now(timezone.utc)
    week_str = now.strftime("Week of %B %d, %Y")
    top_items = items[:5]

    lines = [
        f"## Intelligence Summary — {week_str}",
        "",
    ]

    for item in top_items:
        classification = item.get("classification") or {}
        synthesis = item.get("synthesis") or {}
        tags = classification.get("tags", [])
        category = classification.get("category", "other")
        rel = classification.get("relevance_score", 0)
        tags_str = ", ".join(tags) if tags else category

        headline = synthesis.get("headline", item.get("title", ""))[:80]
        why = synthesis.get("why_it_matters", "")
        url = item.get("url", "")

        # Concept-first format for semantic retrieval
        lines += [
            f"**{tags_str}: {headline}** | Relevance: {rel}/10 | {now.strftime('%Y-%m-%d')}",
            f"Summary: {why}" if why else f"Summary: {headline}",
            f"Link: {url}",
            "",
        ]

    return "\n".join(lines)


def update_memory_md(memory_path: Path, new_entry: str) -> None:
    """Inject a weekly summary block into MEMORY.md without blowing it up."""
    MARKER_START = "<!-- INTELLIGENCE_START -->"
    MARKER_END = "<!-- INTELLIGENCE_END -->"

    if not memory_path.exists():
        print(f"MEMORY.md not found at {memory_path} — skipping memory update")
        return

    content = memory_path.read_text()

    new_block = f"{MARKER_START}\n{new_entry}\n{MARKER_END}"

    if MARKER_START in content:
        # Replace existing block
        import re
        content = re.sub(
            rf"{re.escape(MARKER_START)}.*?{re.escape(MARKER_END)}",
            new_block,
            content,
            flags=re.DOTALL,
        )
    else:
        # Append to end
        content += f"\n\n{new_block}\n"

    memory_path.write_text(content)
    print(f"Updated MEMORY.md at {memory_path}")


def load_last_run() -> dict:
    if not LAST_RUN_FILE.exists():
        return {}
    try:
        return json.loads(LAST_RUN_FILE.read_text())
    except Exception:
        return {}


def summarize_top_signal(item: dict) -> str:
    synthesis = item.get("synthesis") or {}
    return synthesis.get("headline") or item.get("title", "None")


def summarize_trend(items: list[dict]) -> str:
    counts = Counter()
    for item in items:
        for tag in (item.get("classification") or {}).get("tags", []):
            tag_text = str(tag).strip()
            if tag_text:
                counts[tag_text] += 1
    return counts.most_common(1)[0][0] if counts else "none"


def summarize_action_taken(last_run: dict) -> str:
    actions = last_run.get("actions", {})
    discoveries = last_run.get("discoveries", {})

    parts = []
    for key in ["act_now", "evaluate", "monitor", "skipped"]:
        count = actions.get(key, 0)
        if count:
            parts.append(f"{count} {key}")

    accounts_added = discoveries.get("accounts_added", [])
    if accounts_added:
        parts.append("added Bluesky accounts: " + ", ".join(accounts_added))

    keywords_added = discoveries.get("keywords_added", [])
    if keywords_added:
        parts.append("added keywords: " + ", ".join(keywords_added))

    return "; ".join(parts) if parts else "no act.py changes recorded"


def write_learnings(items: list[dict]) -> None:
    """Append a compact daily summary to learnings.md."""
    now = datetime.now(timezone.utc)
    date_str = now.strftime("%Y-%m-%d")
    top_item = max(
        items,
        key=lambda item: (item.get("classification") or {}).get("relevance_score", 0),
    )
    last_run = load_last_run()
    lines = [
        f"## {date_str}",
        f"- Top signal: {summarize_top_signal(top_item)}",
        f"- Trend: {summarize_trend(items)}",
        f"- Action taken: {summarize_action_taken(last_run)}",
        "",
    ]

    LEARNINGS_FILE.parent.mkdir(parents=True, exist_ok=True)
    with open(LEARNINGS_FILE, "a") as f:
        if f.tell() > 0:
            f.write("\n")
        f.write("\n".join(lines))
    log.info(f"Learnings appended to {LEARNINGS_FILE}")


def main():
    parser = argparse.ArgumentParser(description="OpenClaw Intelligence Digest Generator")
    parser.add_argument("--weekly", action="store_true", help="Also update MEMORY.md")
    parser.add_argument("--stdout", action="store_true", help="Print digest to stdout only")
    args = parser.parse_args()

    items = load_hot_items()

    if not items:
        print("No hot items found. Run collector.py and filter.py first.")
        return

    digest = generate_digest(items, weekly=args.weekly)

    if args.stdout:
        print(digest)
        return

    DIGEST_FILE.write_text(digest)
    print(f"Digest written to {DIGEST_FILE}")
    print(f"  Items: {len(items)} | Act Now: {sum(1 for i in items if i.get('classification', {}).get('actionability') == 'act_now')}")

    # Append daily learnings
    write_learnings(items)

    if args.weekly:
        entry = generate_memory_entry(items)
        update_memory_md(MEMORY_FILE, entry)


if __name__ == "__main__":
    main()
