#!/usr/bin/env python3
"""
OpenClaw Intelligence Trends — weekly topic frequency analysis.

Reads all items from items/ directory, groups by tags, compares this week vs last week,
and outputs rising/falling topics.

Usage:
    python3 trends.py              # generate weekly trend report
    python3 trends.py --dry-run    # print to stdout without writing files
"""

import argparse
import json
import logging
import sys
from collections import Counter
from datetime import datetime, timezone, timedelta, date
from pathlib import Path
from typing import Optional

# ── Paths ──────────────────────────────────────────────────────────────────────
BASE = Path(__file__).parent
ITEMS_DIR = BASE / "items"
TRENDS_DIR = BASE / "trends"
MEMORY_TRENDS_DIR = Path.home() / ".openclaw" / "workspace" / "memory" / "intel" / "trends"

TRENDS_DIR.mkdir(parents=True, exist_ok=True)
MEMORY_TRENDS_DIR.mkdir(parents=True, exist_ok=True)

TODAY = date.today()

# ── Logging ────────────────────────────────────────────────────────────────────
logging.basicConfig(
    level=logging.INFO,
    format="%(asctime)s [trends] %(levelname)s %(message)s",
    datefmt="%H:%M:%S",
)
log = logging.getLogger("trends")


# ── Core ───────────────────────────────────────────────────────────────────────

def load_all_items() -> list[dict]:
    """Load all items from items/ directory."""
    items = []
    if not ITEMS_DIR.exists():
        return items
    for path in ITEMS_DIR.glob("*.json"):
        try:
            item = json.loads(path.read_text())
            items.append(item)
        except Exception:
            continue
    return items


def parse_item_date(item: dict) -> Optional[date]:
    """Extract date from item's fetched_at or published_at."""
    for field in ("fetched_at", "published_at"):
        ts = item.get(field, "")
        if not ts:
            continue
        try:
            dt = datetime.fromisoformat(ts.replace("Z", "+00:00"))
            return dt.date()
        except Exception:
            continue
    return None


def get_week_range(ref_date: date, weeks_ago: int = 0) -> tuple[date, date]:
    """Return (start, end) of the ISO week containing ref_date - weeks_ago weeks."""
    target = ref_date - timedelta(weeks=weeks_ago)
    # Monday of that week
    start = target - timedelta(days=target.weekday())
    end = start + timedelta(days=6)
    return start, end


def count_tags_in_range(items: list[dict], start: date, end: date) -> Counter:
    """Count tag frequency for items within a date range."""
    counter = Counter()
    for item in items:
        item_date = parse_item_date(item)
        if item_date is None or item_date < start or item_date > end:
            continue
        classification = item.get("classification")
        if not classification:
            continue
        tags = classification.get("tags", [])
        for tag in tags:
            counter[tag.lower()] += 1
    return counter


def compute_trends(this_week: Counter, last_week: Counter) -> tuple[list, list, list]:
    """Compare two weeks. Returns (rising, falling, new) topic lists."""
    all_tags = set(this_week.keys()) | set(last_week.keys())

    rising = []
    falling = []
    new_topics = []

    for tag in all_tags:
        curr = this_week.get(tag, 0)
        prev = last_week.get(tag, 0)

        if prev == 0 and curr > 0:
            new_topics.append((tag, curr))
        elif curr > prev and prev > 0:
            pct = ((curr - prev) / prev) * 100
            rising.append((tag, curr, prev, pct))
        elif curr < prev and prev > 0:
            pct = ((prev - curr) / prev) * 100
            falling.append((tag, curr, prev, pct))

    rising.sort(key=lambda x: x[3], reverse=True)
    falling.sort(key=lambda x: x[3], reverse=True)
    new_topics.sort(key=lambda x: x[1], reverse=True)

    return rising, falling, new_topics


def format_trend_report(
    this_week_range: tuple[date, date],
    last_week_range: tuple[date, date],
    this_week: Counter,
    last_week: Counter,
    rising: list,
    falling: list,
    new_topics: list,
) -> str:
    """Format the full weekly trend report as markdown."""
    lines = [
        f"# Weekly Trends — {this_week_range[0]} to {this_week_range[1]}",
        "",
        f"Compared against: {last_week_range[0]} to {last_week_range[1]}",
        f"Total tagged items this week: {sum(this_week.values())}",
        f"Total tagged items last week: {sum(last_week.values())}",
        "",
    ]

    # Top tags this week
    lines.append("## Top Tags This Week")
    for tag, count in this_week.most_common(15):
        lines.append(f"- **{tag}**: {count}")
    lines.append("")

    # Rising
    lines.append("## Rising Topics")
    if rising:
        for tag, curr, prev, pct in rising[:10]:
            lines.append(f"- **{tag}**: {prev} -> {curr} (+{pct:.0f}%)")
    else:
        lines.append("- No rising topics detected.")
    lines.append("")

    # New this week
    lines.append("## New This Week")
    if new_topics:
        for tag, count in new_topics[:10]:
            lines.append(f"- **{tag}**: {count} mentions (new)")
    else:
        lines.append("- No new topics.")
    lines.append("")

    # Falling
    lines.append("## Falling Topics")
    if falling:
        for tag, curr, prev, pct in falling[:10]:
            lines.append(f"- **{tag}**: {prev} -> {curr} (-{pct:.0f}%)")
    else:
        lines.append("- No falling topics detected.")
    lines.append("")

    return "\n".join(lines)


def count_sentiment_in_range(items: list[dict], start: date, end: date) -> dict[str, dict[str, int]]:
    """Count positive (opportunity) vs negative (threat) items per tag in a date range."""
    sentiment: dict[str, dict[str, int]] = {}
    for item in items:
        item_date = parse_item_date(item)
        if item_date is None or item_date < start or item_date > end:
            continue
        classification = item.get("classification")
        if not classification:
            continue
        threat_opp = classification.get("threat_opportunity", "neutral")
        tags = classification.get("tags", [])
        for tag in tags:
            tag_lower = tag.lower()
            if tag_lower not in sentiment:
                sentiment[tag_lower] = {"positive": 0, "negative": 0, "neutral": 0}
            if threat_opp == "opportunity":
                sentiment[tag_lower]["positive"] += 1
            elif threat_opp == "threat":
                sentiment[tag_lower]["negative"] += 1
            else:
                sentiment[tag_lower]["neutral"] += 1
    return sentiment


def format_sentiment_section(this_sentiment: dict, last_sentiment: dict) -> str:
    """Format sentiment shift section for the trend report."""
    lines = ["## Sentiment Tracking", ""]
    if not this_sentiment:
        lines.append("- No sentiment data available.")
        return "\n".join(lines)

    sorted_tags = sorted(
        this_sentiment.items(),
        key=lambda x: x[1]["positive"] + x[1]["negative"] + x[1]["neutral"],
        reverse=True,
    )

    for tag, counts in sorted_tags[:10]:
        pos, neg = counts["positive"], counts["negative"]
        total = pos + neg + counts["neutral"]
        if total == 0:
            continue
        ratio = f"{pos}+ / {neg}-"

        prev = last_sentiment.get(tag, {"positive": 0, "negative": 0, "neutral": 0})
        prev_pos, prev_neg = prev["positive"], prev["negative"]
        shift = ""
        if prev_pos + prev_neg > 0:
            prev_ratio = prev_pos / (prev_pos + prev_neg) if (prev_pos + prev_neg) > 0 else 0.5
            curr_ratio = pos / (pos + neg) if (pos + neg) > 0 else 0.5
            diff = curr_ratio - prev_ratio
            if diff > 0.15:
                shift = " (more positive)"
            elif diff < -0.15:
                shift = " (more negative)"

        lines.append(f"- **{tag}**: {ratio} ({total} items){shift}")

    lines.append("")
    return "\n".join(lines)


def format_summary(rising: list, falling: list, new_topics: list, this_week: Counter) -> str:
    """5-line summary for memory."""
    lines = [f"Intel trends {TODAY}:"]

    top3 = this_week.most_common(3)
    if top3:
        lines.append(f"Top tags: {', '.join(f'{t}({c})' for t, c in top3)}")

    if rising:
        top_rising = rising[:2]
        lines.append(f"Rising: {', '.join(f'{t[0]}(+{t[3]:.0f}%)' for t in top_rising)}")
    else:
        lines.append("Rising: none")

    if new_topics:
        lines.append(f"New: {', '.join(t[0] for t in new_topics[:3])}")
    else:
        lines.append("New topics: none")

    if falling:
        lines.append(f"Falling: {', '.join(f'{t[0]}(-{t[3]:.0f}%)' for t in falling[:2])}")
    else:
        lines.append("Falling: none")

    return "\n".join(lines)


def main():
    parser = argparse.ArgumentParser(description="OpenClaw Intelligence Trends")
    parser.add_argument("--dry-run", action="store_true", help="Print report without writing files")
    args = parser.parse_args()

    items = load_all_items()
    log.info(f"Loaded {len(items)} items from items/")

    if not items:
        log.info("No items to analyze.")
        return

    this_week_range = get_week_range(TODAY, 0)
    last_week_range = get_week_range(TODAY, 1)

    this_week = count_tags_in_range(items, *this_week_range)
    last_week = count_tags_in_range(items, *last_week_range)

    log.info(f"This week ({this_week_range[0]} to {this_week_range[1]}): {sum(this_week.values())} tag mentions")
    log.info(f"Last week ({last_week_range[0]} to {last_week_range[1]}): {sum(last_week.values())} tag mentions")

    rising, falling, new_topics = compute_trends(this_week, last_week)

    # Sentiment tracking
    this_sentiment = count_sentiment_in_range(items, *this_week_range)
    last_sentiment = count_sentiment_in_range(items, *last_week_range)
    sentiment_section = format_sentiment_section(this_sentiment, last_sentiment)

    report = format_trend_report(
        this_week_range, last_week_range,
        this_week, last_week,
        rising, falling, new_topics,
    )
    # Append sentiment section to report
    report += "\n" + sentiment_section

    summary = format_summary(rising, falling, new_topics, this_week)

    if args.dry_run:
        print(report)
        print("\n--- Memory Summary ---")
        print(summary)
    else:
        # Write full report to trends/
        report_path = TRENDS_DIR / f"weekly-{TODAY}.md"
        report_path.write_text(report)
        log.info(f"Trend report written to {report_path}")

        # Write 5-line summary to memory
        memory_path = MEMORY_TRENDS_DIR / f"{TODAY}.md"
        memory_path.write_text(summary)
        log.info(f"Trend summary written to {memory_path}")

    log.info("Trend analysis complete.")


if __name__ == "__main__":
    main()
