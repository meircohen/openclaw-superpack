#!/usr/bin/env python3
"""
OpenClaw Intelligence Filter — v2 (local Ollama)
Two-pass LLM synthesis: classifier first, full synthesis only for high-signal items.

Pass 1: llama3.1:8b — classify every unprocessed item (relevance, actionability, tags)
Pass 2: llama3.1:8b — full synthesis only if relevance >= 7 OR openclaw_relevance OR act_now

Usage:
    python3 filter.py           # process pending items
    python3 filter.py --dry-run # show what would be processed without calling LLM
    python3 filter.py --force   # reprocess all items (for recalibration)
"""

import argparse
import json
import logging
import sys
import time
from datetime import datetime, timezone
from pathlib import Path

import httpx

# ── Paths ──────────────────────────────────────────────────────────────────────
BASE = Path(__file__).parent
ITEMS_DIR = BASE / "items"
SIGNALS_DIR = BASE / "signals"
ACTIONS_DIR = BASE / "actions"
HOT_FILE = BASE / "hot.json"
USAGE_FILE = BASE / "usage.json"
CONFIG_FILE = BASE / "config.yaml"
OPENCLAW_CONFIG = Path.home() / ".openclaw" / "openclaw.json"
AMPLIFIED_FILE = ACTIONS_DIR / "amplified.json"

SIGNALS_DIR.mkdir(exist_ok=True)
ACTIONS_DIR.mkdir(exist_ok=True)

# ── Logging ────────────────────────────────────────────────────────────────────
logging.basicConfig(
    level=logging.INFO,
    format="%(asctime)s [filter] %(levelname)s %(message)s",
    datefmt="%Y-%m-%dT%H:%M:%S",
)
log = logging.getLogger("filter")

# ── Config ─────────────────────────────────────────────────────────────────────
try:
    import yaml
    with open(CONFIG_FILE) as f:
        CONFIG = yaml.safe_load(f) or {}
except ImportError:
    CONFIG = {}

LLM_CFG = CONFIG.get("llm", {})
OLLAMA_URL = LLM_CFG.get("ollama_url", "http://localhost:11434")
OLLAMA_MODEL = LLM_CFG.get("ollama_model", "llama3.1:8b")
MAX_TOKENS_PER_RUN = LLM_CFG.get("max_tokens_per_run", 50000)
BATCH_MIN_SIZE = LLM_CFG.get("batch_min_size", 5)
BATCH_MAX_AGE_HOURS = LLM_CFG.get("batch_max_age_hours", 2)
PASS2_THRESHOLD = CONFIG.get("scoring", {}).get("pass2_threshold", 7)

# ── OpenClaw config ────────────────────────────────────────────────────────────

def load_openclaw_config() -> dict:
    try:
        return json.loads(OPENCLAW_CONFIG.read_text())
    except Exception as e:
        log.error(f"Could not load OpenClaw config: {e}")
        return {}


def get_gateway_info(oc_cfg: dict) -> tuple[int, str]:
    """Return (port, token) from OpenClaw gateway config."""
    gw = oc_cfg.get("gateway", {})
    port = gw.get("port", 18789)
    token = gw.get("auth", {}).get("token", "")
    return port, token


# ── Usage tracking ─────────────────────────────────────────────────────────────

def load_usage() -> dict:
    if USAGE_FILE.exists():
        try:
            return json.loads(USAGE_FILE.read_text())
        except Exception:
            return {}
    return {"total_input_tokens": 0, "total_output_tokens": 0, "runs": []}


def save_usage(usage: dict) -> None:
    USAGE_FILE.write_text(json.dumps(usage, indent=2))


def record_usage(usage: dict, model: str, input_tokens: int, output_tokens: int) -> None:
    usage["total_input_tokens"] = usage.get("total_input_tokens", 0) + input_tokens
    usage["total_output_tokens"] = usage.get("total_output_tokens", 0) + output_tokens
    usage.setdefault("runs", []).append({
        "timestamp": datetime.now(timezone.utc).isoformat(),
        "model": model,
        "input_tokens": input_tokens,
        "output_tokens": output_tokens,
        "cost": 0,  # local model, no cost
    })
    # Keep only last 100 run records
    usage["runs"] = usage["runs"][-100:]


# ── LLM calls ─────────────────────────────────────────────────────────────────

PASS1_PROMPT = """You are an AI signal classifier for a developer using OpenClaw — a personal AI agent platform on macOS.

Classify this item and respond with ONLY valid JSON (no markdown, no explanation):

{{
  "category": "tooling|model_release|ecosystem|research|competitive|other",
  "relevance_score": <0-10 integer, how relevant to AI agents/tools/OpenClaw>,
  "openclaw_relevance": <true if directly about MCP, OpenClaw, or AI agent infrastructure>,
  "actionability": "none|monitor|evaluate|act_now",
  "time_sensitivity": "days|weeks|months|none",
  "threat_opportunity": "threat|opportunity|neutral|none",
  "tags": [<up to 5 short tags>],
  "reason": "<one sentence why this score>"
}}

Scoring guide:
- 9-10: Breaking change or new capability directly affecting OpenClaw/MCP ecosystem
- 7-8: Important development in AI agents, tool use, or competing platforms
- 5-6: Useful background signal, worth monitoring
- 3-4: Tangentially related, low priority
- 1-2: Noise, only loosely AI-related
- 0: Irrelevant

Item:
Title: {title}
Source: {source}
URL: {url}
Raw score: {raw_score}
Keywords matched: {keywords}
Summary: {summary}"""

PASS2_PROMPT = """You are an intelligence analyst for a developer using OpenClaw — a personal AI agent platform on macOS.

Write a concise actionable intelligence report for this item. Respond with ONLY valid JSON:

{{
  "headline": "<10 words max, what happened>",
  "why_it_matters": "<one sentence: why this is significant for AI agent developers>",
  "action": "<one sentence: what the user should consider doing, or 'No action needed'>",
  "confidence": <0.0-1.0 float>,
  "related_topics": [<up to 3 related areas to watch>]
}}

Item:
Title: {title}
Source: {source}
URL: {url}
Classification: {classification}
Summary: {summary}"""


def call_ollama(prompt: str) -> tuple:
    """Call Ollama API. Returns (parsed_json, input_tokens, output_tokens)."""
    try:
        with httpx.Client(timeout=60) as client:
            resp = client.post(
                f"{OLLAMA_URL}/api/generate",
                json={
                    "model": OLLAMA_MODEL,
                    "prompt": prompt,
                    "stream": False,
                    "options": {
                        "temperature": 0.1,
                    },
                },
            )
            resp.raise_for_status()
            data = resp.json()
            content = data.get("response", "").strip()
            # Ollama reports token counts
            input_tokens = data.get("prompt_eval_count", 0)
            output_tokens = data.get("eval_count", 0)
            # Strip markdown fences if present
            if content.startswith("```"):
                content = content.split("\n", 1)[1].rsplit("```", 1)[0].strip()
            return json.loads(content), input_tokens, output_tokens
    except json.JSONDecodeError as e:
        log.error(f"JSON parse error from LLM: {e}")
        return None, 0, 0
    except Exception as e:
        log.error(f"Ollama API call failed: {e}")
        return None, 0, 0


# ── Notification ───────────────────────────────────────────────────────────────

def notify_hot_item(item: dict, port: int, token: str) -> None:
    """Fire a gateway system event for act_now items via cron wake endpoint."""
    synthesis = item.get("synthesis") or {}
    headline = synthesis.get("headline", item.get("title", "")[:60])
    action = synthesis.get("action", "")
    msg = f"[Intelligence Alert] {headline}"
    if action and action != "No action needed":
        msg += f" — {action}"
    msg += f"\n{item.get('url', '')}"
    try:
        with httpx.Client(timeout=10) as client:
            client.post(
                f"http://localhost:{port}/api/cron/wake",
                json={"text": msg, "mode": "now"},
                headers={"Authorization": f"Bearer {token}"},
            )
        log.info(f"Notified gateway: {headline[:50]}")
    except Exception as e:
        log.warning(f"Gateway notification failed (non-fatal): {e}")


# ── Core pipeline ──────────────────────────────────────────────────────────────

def get_pending_items(force: bool = False) -> list[dict]:
    """Return items that haven't been through Pass 1 yet."""
    pending = []
    for path in sorted(ITEMS_DIR.glob("*.json")):
        try:
            item = json.loads(path.read_text())
            if force or item.get("synthesis") is None and item.get("classification") is None:
                pending.append((path, item))
        except Exception:
            continue
    return pending


def should_trigger_pass2_batch(pending_pass2: list) -> bool:
    """Time-boxed batch trigger: >=5 items OR oldest item > 2 hours."""
    if len(pending_pass2) >= BATCH_MIN_SIZE:
        return True
    if not pending_pass2:
        return False
    oldest = pending_pass2[0].get("fetched_at", "")
    if oldest:
        try:
            dt = datetime.fromisoformat(oldest.replace("Z", "+00:00"))
            age_hours = (datetime.now(timezone.utc) - dt).total_seconds() / 3600
            return age_hours >= BATCH_MAX_AGE_HOURS
        except Exception:
            pass
    return False


def _append_amplified_log(entries: list[dict]) -> None:
    existing = []
    if AMPLIFIED_FILE.exists():
        try:
            existing = json.loads(AMPLIFIED_FILE.read_text())
        except Exception:
            existing = []
    existing.extend(entries)
    AMPLIFIED_FILE.write_text(json.dumps(existing, indent=2) + "\n")


def _normalize_score(score: float):
    rounded = round(score, 1)
    return int(rounded) if rounded.is_integer() else rounded


def _amplify_cross_source(classified_items: list[tuple[Path, dict]], dry_run: bool) -> list[dict]:
    """Boost relevance when the same URL appears from multiple sources."""
    url_groups: dict[str, list[tuple[Path, dict]]] = {}

    for path, item in classified_items:
        if not item.get("classification"):
            continue
        url = (item.get("url") or "").strip()
        if not url:
            continue
        url_groups.setdefault(url, []).append((path, item))

    amplified_entries = []

    for url, group in url_groups.items():
        sources = sorted({item.get("source", "") for _, item in group if item.get("source")})
        if len(sources) < 2:
            continue

        for path, item in group:
            cls = item.get("classification") or {}
            old_score = cls.get("relevance_score", 0)
            try:
                new_score = _normalize_score(min(10.0, float(old_score) * 1.5))
            except (TypeError, ValueError):
                continue

            if new_score == old_score:
                continue

            cls["relevance_score"] = new_score
            cls["cross_source_amplified"] = True
            item["classification"] = cls

            if not dry_run:
                path.write_text(json.dumps(item, indent=2))

            amplified_entries.append({
                "timestamp": datetime.now(timezone.utc).isoformat(),
                "item_id": item.get("id"),
                "title": item.get("title", ""),
                "url": url,
                "sources": sources,
                "base_relevance_score": old_score,
                "amplified_relevance_score": new_score,
            })
            log.info(
                "  Amplified: %s (%s -> %s) from %s",
                item.get("title", "")[:50],
                old_score,
                new_score,
                ", ".join(sources),
            )

    if amplified_entries and not dry_run:
        _append_amplified_log(amplified_entries)
        log.info("Cross-source amplification: %d items boosted", len(amplified_entries))

    return [item for _, item in classified_items if item.get("classification")]


def run_filter(dry_run: bool = False, force: bool = False) -> None:
    oc_cfg = load_openclaw_config()
    port, gw_token = get_gateway_info(oc_cfg)
    usage = load_usage()
    tokens_used_this_run = 0

    pending = get_pending_items(force)
    log.info(f"Found {len(pending)} items pending classification")

    if not pending:
        log.info("Nothing to process.")
        return

    hot_items = []

    # ── Pass 1: Classify all pending items ────────────────────────────────────
    for path, item in pending:
        if tokens_used_this_run >= MAX_TOKENS_PER_RUN:
            log.warning(f"Token cap reached ({MAX_TOKENS_PER_RUN}). Stopping early.")
            break

        prompt = PASS1_PROMPT.format(
            title=item.get("title", ""),
            source=item.get("source", ""),
            url=item.get("url", ""),
            raw_score=item.get("raw_score", 0),
            keywords=", ".join(item.get("keywords_matched", [])),
            summary=item.get("summary_raw", "")[:300],
        )

        if dry_run:
            log.info(f"[DRY RUN] Would classify: {item['title'][:60]}")
            continue

        classification, in_tok, out_tok = call_ollama(prompt)
        tokens_used_this_run += in_tok + out_tok
        record_usage(usage, OLLAMA_MODEL, in_tok, out_tok)

        if classification is None:
            log.warning(f"Pass 1 failed for {item['id']}")
            continue

        item["classification"] = classification
        log.info(
            f"  Pass1: {item['title'][:50]} → rel={classification.get('relevance_score')}, "
            f"act={classification.get('actionability')}, oc={classification.get('openclaw_relevance')}"
        )

        # Save updated item
        path.write_text(json.dumps(item, indent=2))
        time.sleep(0.3)  # gentle rate limiting

    save_usage(usage)

    # ── Cross-source signal amplification ─────────────────────────────────────
    classified_items = [entry for entry in pending if entry[1].get("classification")]
    if not dry_run:
        _amplify_cross_source(classified_items, dry_run=False)

    pass2_queue = []
    for _path, item in classified_items:
        classification = item.get("classification", {})
        rel = classification.get("relevance_score", 0)
        oc_rel = classification.get("openclaw_relevance", False)
        act = classification.get("actionability", "none")
        if rel >= PASS2_THRESHOLD or oc_rel or act == "act_now":
            pass2_queue.append(item)

    # ── Pass 2: Synthesize high-signal items ──────────────────────────────────
    if not dry_run and should_trigger_pass2_batch(pass2_queue):
        log.info(f"Triggering Pass 2 for {len(pass2_queue)} items")

        for item in pass2_queue:
            if tokens_used_this_run >= MAX_TOKENS_PER_RUN:
                log.warning("Token cap reached during Pass 2. Stopping.")
                break

            item_path = ITEMS_DIR / f"{item['id']}.json"
            classification = item.get("classification", {})

            prompt = PASS2_PROMPT.format(
                title=item.get("title", ""),
                source=item.get("source", ""),
                url=item.get("url", ""),
                classification=json.dumps(classification),
                summary=item.get("summary_raw", "")[:500],
            )

            synthesis, in_tok, out_tok = call_ollama(prompt)
            tokens_used_this_run += in_tok + out_tok
            record_usage(usage, OLLAMA_MODEL, in_tok, out_tok)

            if synthesis is None:
                log.warning(f"Pass 2 failed for {item['id']}")
                continue

            item["synthesis"] = synthesis
            item_path.write_text(json.dumps(item, indent=2))
            hot_items.append(item)

            log.info(f"  Pass2: {synthesis.get('headline', '')[:60]}")

            # Notify for act_now items
            if classification.get("actionability") == "act_now":
                notify_hot_item(item, port, gw_token)

            time.sleep(0.5)

        save_usage(usage)
    else:
        log.info(f"Pass 2 not triggered yet ({len(pass2_queue)} items queued, need {BATCH_MIN_SIZE}+ or {BATCH_MAX_AGE_HOURS}h age)")

    # ── Update hot.json ───────────────────────────────────────────────────────
    if hot_items and not dry_run:
        existing_hot = []
        if HOT_FILE.exists():
            try:
                existing_hot = json.loads(HOT_FILE.read_text())
            except Exception:
                pass
        # Merge, deduplicate, sort by relevance, keep top 20
        all_hot = {i["id"]: i for i in existing_hot + hot_items}
        sorted_hot = sorted(
            all_hot.values(),
            key=lambda x: (
                x.get("classification", {}).get("relevance_score", 0),
                x.get("classification", {}).get("openclaw_relevance", False),
            ),
            reverse=True,
        )[:20]
        HOT_FILE.write_text(json.dumps(sorted_hot, indent=2))
        log.info(f"Updated hot.json with {len(sorted_hot)} items")

    log.info(f"Filter complete. Tokens used this run: {tokens_used_this_run:,} / {MAX_TOKENS_PER_RUN:,} (local, cost=$0)")


def main():
    parser = argparse.ArgumentParser(description="OpenClaw Intelligence Filter")
    parser.add_argument("--dry-run", action="store_true")
    parser.add_argument("--force", action="store_true", help="Reprocess all items")
    args = parser.parse_args()
    run_filter(dry_run=args.dry_run, force=args.force)


if __name__ == "__main__":
    main()
