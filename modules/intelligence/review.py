from typing import Optional
#!/usr/bin/env python3
"""
OpenClaw Intelligence Calibration Tool — v1
Manual review CLI for the 3-day calibration window.
Rate items as useful/not useful to empirically tune thresholds.

Usage:
    python3 review.py           # review unrated items
    python3 review.py --stats   # show calibration stats
    python3 review.py --all     # review all items (including already rated)
    python3 review.py --source hn  # review only one source

After 3 days, run --stats to see which sources are earning their keep.
"""

import argparse
import json
import sys
from collections import defaultdict
from datetime import datetime, timezone
from pathlib import Path

BASE = Path(__file__).parent
ITEMS_DIR = BASE / "items"


def load_items(source_filter: str = None, include_rated: bool = False) -> list[tuple[Path, dict]]:
    items = []
    for path in sorted(ITEMS_DIR.glob("*.json"), key=lambda p: p.stat().st_mtime, reverse=True):
        try:
            item = json.loads(path.read_text())
            if not include_rated and item.get("useful") is not None:
                continue
            if source_filter and item.get("source") != source_filter:
                continue
            items.append((path, item))
        except Exception:
            continue
    return items


def display_item(item: dict, idx: int, total: int) -> None:
    classification = item.get("classification") or {}
    synthesis = item.get("synthesis") or {}

    print(f"\n{'─'*60}")
    print(f"Item {idx}/{total} | Source: {item.get('source')} | KW score: {item.get('score', 0)}")
    print(f"Relevance: {classification.get('relevance_score', 'unclassified')} | "
          f"Actionability: {classification.get('actionability', 'unclassified')}")
    print(f"OpenClaw-specific: {classification.get('openclaw_relevance', False)}")
    print(f"\n📰 {item.get('title', 'No title')}")
    print(f"🔗 {item.get('url', '')}")

    if synthesis.get("headline"):
        print(f"\n💡 {synthesis['headline']}")
    if synthesis.get("why_it_matters"):
        print(f"   {synthesis['why_it_matters']}")
    if synthesis.get("action"):
        print(f"→  {synthesis['action']}")


def prompt_rating() -> Optional[str]:
    """Returns 'y', 'n', 's' (skip), or 'q' (quit)."""
    while True:
        try:
            resp = input("\nUseful? [y/n/s=skip/q=quit]: ").strip().lower()
            if resp in ("y", "n", "s", "q"):
                return resp
            print("Enter y, n, s, or q")
        except (KeyboardInterrupt, EOFError):
            return "q"


def show_stats() -> None:
    items = []
    for path in ITEMS_DIR.glob("*.json"):
        try:
            item = json.loads(path.read_text())
            if item.get("useful") is not None:
                items.append(item)
        except Exception:
            continue

    if not items:
        print("No rated items yet. Run review.py to start rating.")
        return

    total = len(items)
    useful = sum(1 for i in items if i.get("useful"))
    print(f"\n{'='*50}")
    print(f"CALIBRATION STATS ({total} rated items)")
    print(f"{'='*50}")
    print(f"Overall useful rate: {useful}/{total} ({100*useful//total}%)")

    # Per-source breakdown
    by_source = defaultdict(lambda: {"total": 0, "useful": 0})
    for item in items:
        src = item.get("source", "unknown")
        by_source[src]["total"] += 1
        if item.get("useful"):
            by_source[src]["useful"] += 1

    print(f"\nBy source:")
    for src, counts in sorted(by_source.items()):
        t, u = counts["total"], counts["useful"]
        pct = 100 * u // t if t else 0
        bar = "█" * (pct // 10) + "░" * (10 - pct // 10)
        print(f"  {src:<20} {bar} {u}/{t} ({pct}%)")

    # Relevance score accuracy
    print(f"\nRelevance score accuracy (did the LLM score match your rating?):")
    score_buckets = defaultdict(lambda: {"total": 0, "useful": 0})
    for item in items:
        cl = item.get("classification") or {}
        rel = cl.get("relevance_score")
        if rel is not None:
            bucket = f"{(rel // 2) * 2}-{(rel // 2) * 2 + 1}"
            score_buckets[bucket]["total"] += 1
            if item.get("useful"):
                score_buckets[bucket]["useful"] += 1

    for bucket in sorted(score_buckets.keys()):
        t, u = score_buckets[bucket]["total"], score_buckets[bucket]["useful"]
        pct = 100 * u // t if t else 0
        print(f"  Score {bucket}: {u}/{t} useful ({pct}%)")

    # Recommendations
    print(f"\n📊 RECOMMENDATIONS:")
    low_signal_sources = [s for s, c in by_source.items()
                          if c["total"] >= 3 and (100 * c["useful"] // c["total"]) < 30]
    if low_signal_sources:
        print(f"  ⚠️  Low-signal sources (consider raising thresholds or disabling):")
        for s in low_signal_sources:
            print(f"      - {s}")
    else:
        print(f"  ✅ All sources showing reasonable signal rate")

    # Threshold recommendation
    rated_with_cl = [i for i in items if i.get("classification")]
    if rated_with_cl:
        useful_scores = [i["classification"]["relevance_score"]
                         for i in rated_with_cl if i.get("useful")]
        useless_scores = [i["classification"]["relevance_score"]
                          for i in rated_with_cl if not i.get("useful")]
        if useful_scores and useless_scores:
            suggested_threshold = min(useful_scores) if min(useful_scores) > 0 else 5
            print(f"\n  Current Pass 2 threshold: 7")
            print(f"  Suggested threshold based on your ratings: {suggested_threshold}")
            print(f"  (Update config.yaml scoring.pass2_threshold to adjust)")


def main():
    parser = argparse.ArgumentParser(description="OpenClaw Intelligence Calibration")
    parser.add_argument("--stats", action="store_true", help="Show calibration statistics")
    parser.add_argument("--all", action="store_true", help="Review all items including already rated")
    parser.add_argument("--source", help="Filter by source")
    args = parser.parse_args()

    if args.stats:
        show_stats()
        return

    items = load_items(source_filter=args.source, include_rated=args.all)

    if not items:
        print("No unrated items found. Run collector.py first, or use --all to re-review.")
        return

    print(f"\n🔍 Intelligence Calibration — {len(items)} items to review")
    print("This is the most important step. Your ratings tune the filter thresholds.")
    print("Aim to review at least 20 items before trusting the automated scores.\n")

    rated = 0
    for idx, (path, item) in enumerate(items, 1):
        display_item(item, idx, len(items))
        resp = prompt_rating()

        if resp == "q":
            break
        if resp == "s":
            continue

        item["useful"] = resp == "y"
        item["rated_at"] = datetime.now(timezone.utc).isoformat()
        path.write_text(json.dumps(item, indent=2))
        rated += 1
        print(f"  {'✅' if item['useful'] else '❌'} Saved")

    print(f"\nRated {rated} items. Run `python3 review.py --stats` to see calibration summary.")


if __name__ == "__main__":
    main()
