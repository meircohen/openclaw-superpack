from typing import Optional
#!/usr/bin/env python3
"""
OpenClaw Intelligence Collector — v1
Collects signals from Tier 1 sources: HN Algolia, Simon Willison RSS, GitHub Trending, arXiv.

Usage:
    python3 collector.py           # run all sources
    python3 collector.py --source hn  # run one source
    python3 collector.py --dry-run    # print items without saving
"""

import argparse
import fcntl
import hashlib
import json
import logging
import os
import re
import sys
import time
from datetime import datetime, timezone, timedelta
from pathlib import Path

import feedparser
import httpx

# ── Paths ──────────────────────────────────────────────────────────────────────
BASE = Path(__file__).parent
ITEMS_DIR = BASE / "items"
RAW_DIR = BASE / "raw"
JOBS_DIR = BASE / "jobs"
LOCKS_DIR = BASE / "jobs" / "locks"
SEEN_FILE = BASE / "seen.json"
STATUS_FILE = BASE / "status.json"
CONFIG_FILE = BASE / "config.yaml"

for d in [ITEMS_DIR, RAW_DIR, JOBS_DIR, LOCKS_DIR]:
    d.mkdir(parents=True, exist_ok=True)

# ── Logging ────────────────────────────────────────────────────────────────────
logging.basicConfig(
    level=logging.INFO,
    format="%(asctime)s [collector] %(levelname)s %(message)s",
    datefmt="%Y-%m-%dT%H:%M:%S",
)
log = logging.getLogger("collector")

# ── Config ─────────────────────────────────────────────────────────────────────
try:
    import yaml
    with open(CONFIG_FILE) as f:
        CONFIG = yaml.safe_load(f)
except ImportError:
    # Fallback: minimal inline config if PyYAML not installed
    CONFIG = {
        "scoring": {
            "keyword_weights": {
                "MCP": 3, "model context protocol": 3, "OpenClaw": 5,
                "tool use": 2, "multi-agent": 2, "agent": 1, "LLM": 1,
                "Claude": 2, "autonomous": 2, "RAG": 1, "embedding": 1,
            },
            "min_hn_points": 50,
            "max_item_age_hours": 72,
        }
    }

KEYWORD_WEIGHTS: dict = CONFIG.get("scoring", {}).get("keyword_weights", {})
MIN_HN_POINTS: int = CONFIG.get("scoring", {}).get("min_hn_points", 50)
MAX_AGE_HOURS: int = CONFIG.get("scoring", {}).get("max_item_age_hours", 72)
REDDIT_USER_AGENT = os.getenv(
    "OPENCLAW_REDDIT_USER_AGENT",
    "python:OpenClaw.Intelligence:v1.1 (by /u/openclaw-intelligence)",
)
AUTH_PROFILES_FILE = Path("~/.openclaw/agents/main/agent/auth-profiles.json").expanduser()


# ── Helpers ────────────────────────────────────────────────────────────────────

def url_hash(url: str) -> str:
    return hashlib.sha256(url.encode()).hexdigest()[:16]


def load_seen() -> dict:
    if SEEN_FILE.exists():
        try:
            return json.loads(SEEN_FILE.read_text())
        except Exception:
            return {}
    return {}


def save_seen(seen: dict) -> None:
    # Prune entries older than 30 days
    cutoff = (datetime.now(timezone.utc) - timedelta(days=30)).isoformat()
    pruned = {k: v for k, v in seen.items() if v >= cutoff}
    SEEN_FILE.write_text(json.dumps(pruned, indent=2))


def score_item(title: str, text: str = "") -> tuple[int, list[str]]:
    """Deterministic keyword scoring. Returns (score, matched_keywords)."""
    combined = (title + " " + text).lower()
    score = 0
    matched = []
    for kw, weight in KEYWORD_WEIGHTS.items():
        if kw.lower() in combined:
            score += weight
            matched.append(kw)
    return score, matched


def is_too_old(published_str: str) -> bool:
    """Return True if item is older than MAX_AGE_HOURS."""
    if not published_str:
        return False
    try:
        # feedparser gives us a time.struct_time
        if isinstance(published_str, str):
            from email.utils import parsedate_to_datetime
            dt = parsedate_to_datetime(published_str)
        else:
            dt = datetime(*published_str[:6], tzinfo=timezone.utc)
        age = datetime.now(timezone.utc) - dt.astimezone(timezone.utc)
        return age.total_seconds() > MAX_AGE_HOURS * 3600
    except Exception:
        return False


def save_item(item: dict, dry_run: bool = False) -> bool:
    """Write item to items/{hash}.json. Returns True if new."""
    item_id = item["id"]
    path = ITEMS_DIR / f"{item_id}.json"
    if path.exists():
        return False  # already have it
    if not dry_run:
        path.write_text(json.dumps(item, indent=2))
        # Also append to today's raw JSONL
        today = datetime.now(timezone.utc).strftime("%Y-%m-%d")
        raw_file = RAW_DIR / f"{today}.jsonl"
        with open(raw_file, "a") as f:
            f.write(json.dumps(item) + "\n")
    return True


def update_status(source: str, status: str, count: int, error: str = "") -> None:
    data = {}
    if STATUS_FILE.exists():
        try:
            data = json.loads(STATUS_FILE.read_text())
        except Exception:
            pass
    data[source] = {
        "last_run": datetime.now(timezone.utc).isoformat(),
        "status": status,
        "items_collected": count,
        "error": error,
        "consecutive_failures": (
            data.get(source, {}).get("consecutive_failures", 0) + 1
            if status == "error"
            else 0
        ),
    }
    # Flag degraded sources
    if data[source]["consecutive_failures"] >= 3:
        data[source]["degraded"] = True
        log.warning(f"Source {source} is DEGRADED (3+ consecutive failures)")
    else:
        data[source]["degraded"] = False
    STATUS_FILE.write_text(json.dumps(data, indent=2))


# ── Sources ────────────────────────────────────────────────────────────────────

def collect_hn(seen: dict, dry_run: bool = False) -> list[dict]:
    """Hacker News Algolia API — free, no auth."""
    log.info("Collecting HN Algolia...")
    items = []
    try:
        queries = ["MCP", "AI agent", "LLM tool", "model context protocol", "autonomous agent"]
        seen_urls = set()
        with httpx.Client(timeout=15) as client:
            for q in queries:
                resp = client.get(
                    "https://hn.algolia.com/api/v1/search",
                    params={"query": q, "tags": "story", "hitsPerPage": 20},
                )
                resp.raise_for_status()
                for hit in resp.json().get("hits", []):
                    url = hit.get("url") or f"https://news.ycombinator.com/item?id={hit['objectID']}"
                    if url in seen_urls:
                        continue
                    seen_urls.add(url)
                    points = hit.get("points", 0) or 0
                    if points < MIN_HN_POINTS:
                        continue
                    item_id = url_hash(url)
                    if item_id in seen:
                        continue
                    title = hit.get("title", "")
                    kw_score, matched = score_item(title)
                    item = {
                        "id": item_id,
                        "source": "hn",
                        "url": url,
                        "title": title,
                        "score": kw_score,
                        "raw_score": points,
                        "keywords_matched": matched,
                        "author": hit.get("author", ""),
                        "fetched_at": datetime.now(timezone.utc).isoformat(),
                        "published_at": hit.get("created_at", ""),
                        "synthesis": None,
                    }
                    if save_item(item, dry_run):
                        seen[item_id] = datetime.now(timezone.utc).isoformat()
                        items.append(item)
                        log.info(f"  + HN: {title[:70]} (pts={points}, kw={kw_score})")
        update_status("hn", "ok", len(items))
    except Exception as e:
        log.error(f"HN collection failed: {e}")
        update_status("hn", "error", 0, str(e))
    return items


def collect_rss(source_name: str, url: str, seen: dict, dry_run: bool = False) -> list[dict]:
    """Generic RSS/Atom collector."""
    log.info(f"Collecting RSS: {source_name}...")
    items = []
    try:
        feed = feedparser.parse(url)
        for entry in feed.entries[:30]:
            link = entry.get("link", "")
            if not link:
                continue
            item_id = url_hash(link)
            if item_id in seen:
                continue
            published = entry.get("published", entry.get("updated", ""))
            if is_too_old(published):
                continue
            title = entry.get("title", "")
            summary = entry.get("summary", "")[:500]
            kw_score, matched = score_item(title, summary)
            item = {
                "id": item_id,
                "source": source_name,
                "url": link,
                "title": title,
                "score": kw_score,
                "raw_score": 0,
                "keywords_matched": matched,
                "summary_raw": summary,
                "fetched_at": datetime.now(timezone.utc).isoformat(),
                "published_at": published,
                "synthesis": None,
            }
            if save_item(item, dry_run):
                seen[item_id] = datetime.now(timezone.utc).isoformat()
                items.append(item)
                log.info(f"  + {source_name}: {title[:70]} (kw={kw_score})")
        update_status(source_name, "ok", len(items))
    except Exception as e:
        log.error(f"{source_name} RSS collection failed: {e}")
        update_status(source_name, "error", 0, str(e))
    return items


def collect_github_trending(seen: dict, dry_run: bool = False) -> list[dict]:
    """GitHub Trending — scrape the trending page (no auth needed)."""
    log.info("Collecting GitHub Trending...")
    import re
    items = []
    try:
        with httpx.Client(timeout=20, follow_redirects=True) as client:
            resp = client.get(
                "https://github.com/trending/python?since=weekly",
                headers={"Accept": "text/html", "User-Agent": "Mozilla/5.0"},
            )
            resp.raise_for_status()
            html = resp.text

            # Split by '<article' tags — each chunk after the first is one repo
            chunks = html.split('<article')[1:]

            for chunk in chunks:
                # Find repo link: first href matching owner/repo pattern, not login
                hrefs = re.findall(r'href="([^"]*)"', chunk)
                repo_path = None
                for href in hrefs:
                    if 'login' in href or 'sponsors' in href:
                        continue
                    if re.match(r'^/[A-Za-z0-9_.-]+/[A-Za-z0-9_.-]+$', href):
                        repo_path = href
                        break
                if not repo_path:
                    continue

                owner_repo = repo_path.lstrip('/')
                url = f"https://github.com/{owner_repo}"
                item_id = url_hash(url)
                if item_id in seen:
                    continue

                # Description from <p> tag with class containing 'col-9'
                description = ""
                desc_match = re.search(r'<p[^>]*class="[^"]*col-9[^"]*"[^>]*>(.*?)</p>', chunk, re.DOTALL)
                if desc_match:
                    description = re.sub(r'<[^>]+>', '', desc_match.group(1)).strip()

                # Star count: text after </svg> before </a> near stargazers link
                stars = 0
                star_match = re.search(
                    r'href="/[^"]+/stargazers"[^>]*>.*?</svg>\s*([0-9][0-9,]*)',
                    chunk, re.DOTALL,
                )
                if star_match:
                    stars = int(star_match.group(1).replace(',', ''))

                kw_score, matched = score_item(
                    owner_repo.replace("-", " ").replace("/", " "), description,
                )
                item = {
                    "id": item_id,
                    "source": "github_trending",
                    "url": url,
                    "title": owner_repo,
                    "score": kw_score,
                    "raw_score": stars,
                    "keywords_matched": matched,
                    "summary_raw": description,
                    "fetched_at": datetime.now(timezone.utc).isoformat(),
                    "published_at": "",
                    "synthesis": None,
                }
                if save_item(item, dry_run):
                    seen[item_id] = datetime.now(timezone.utc).isoformat()
                    items.append(item)
                    log.info(f"  + GitHub: {owner_repo} ★{stars} (kw={kw_score})")
                if len(items) >= 25:
                    break
        update_status("github_trending", "ok", len(items))
    except Exception as e:
        log.error(f"GitHub trending collection failed: {e}")
        update_status("github_trending", "error", 0, str(e))
    return items


# ── Lock management ────────────────────────────────────────────────────────────

def acquire_lock(source: str, timeout_minutes: int = 15) -> Optional[object]:
    """File-based mutex. Returns lock file handle or None if already locked."""
    lock_path = LOCKS_DIR / f"{source}.lock"
    # Clear stale locks
    if lock_path.exists():
        age = time.time() - lock_path.stat().st_mtime
        if age > timeout_minutes * 60:
            log.warning(f"Clearing stale lock for {source} (age={age:.0f}s)")
            lock_path.unlink()
    try:
        fh = open(lock_path, "w")
        fcntl.flock(fh, fcntl.LOCK_EX | fcntl.LOCK_NB)
        fh.write(str(os.getpid()))
        fh.flush()
        return fh
    except BlockingIOError:
        log.warning(f"Source {source} is already running (lock held)")
        return None


def release_lock(fh, source: str) -> None:
    try:
        fcntl.flock(fh, fcntl.LOCK_UN)
        fh.close()
        lock_path = LOCKS_DIR / f"{source}.lock"
        if lock_path.exists():
            lock_path.unlink()
    except Exception:
        pass


# ── Reddit ─────────────────────────────────────────────────────────────────────

def _first_nonempty(*values):
    for value in values:
        if value:
            return value
    return None


def _extract_subreddit(value: str) -> Optional[str]:
    match = re.search(r"/r/([^/]+)/", value or "")
    if match:
        return match.group(1)
    return None


def _reddit_headers(access_token: Optional[str] = None, accept: str = "application/json") -> dict:
    headers = {
        "Accept": accept,
        "User-Agent": REDDIT_USER_AGENT,
    }
    if access_token:
        headers["Authorization"] = f"Bearer {access_token}"
    return headers


def _load_auth_profiles() -> dict:
    if not AUTH_PROFILES_FILE.exists():
        return {}
    try:
        data = json.loads(AUTH_PROFILES_FILE.read_text())
        return data.get("profiles", {})
    except Exception as e:
        log.warning(f"Could not read auth profiles: {e}")
        return {}


def _load_reddit_credentials() -> dict:
    creds = {
        "access_token": os.getenv("REDDIT_ACCESS_TOKEN"),
        "client_id": os.getenv("REDDIT_CLIENT_ID"),
        "client_secret": os.getenv("REDDIT_CLIENT_SECRET"),
        "refresh_token": os.getenv("REDDIT_REFRESH_TOKEN"),
    }

    for profile_name, profile in _load_auth_profiles().items():
        provider = str(profile.get("provider", ""))
        if "reddit" not in profile_name.lower() and "reddit" not in provider.lower():
            continue
        nested = profile.get("credentials", {}) if isinstance(profile.get("credentials"), dict) else {}
        creds["access_token"] = creds["access_token"] or _first_nonempty(
            profile.get("access_token"), profile.get("access"), nested.get("access_token"), nested.get("access")
        )
        creds["client_id"] = creds["client_id"] or _first_nonempty(
            profile.get("client_id"), profile.get("app_id"), nested.get("client_id"), nested.get("app_id")
        )
        creds["client_secret"] = creds["client_secret"] or _first_nonempty(
            profile.get("client_secret"), nested.get("client_secret")
        )
        creds["refresh_token"] = creds["refresh_token"] or _first_nonempty(
            profile.get("refresh_token"), nested.get("refresh_token")
        )
        break

    return {key: value for key, value in creds.items() if value}


def _get_reddit_access_token(client: httpx.Client) -> Optional[str]:
    creds = _load_reddit_credentials()
    if not creds:
        return None
    if creds.get("access_token"):
        return creds["access_token"]

    client_id = creds.get("client_id")
    client_secret = creds.get("client_secret")
    if not client_id or not client_secret:
        return None

    data = {"grant_type": "client_credentials"}
    if creds.get("refresh_token"):
        data = {"grant_type": "refresh_token", "refresh_token": creds["refresh_token"]}

    resp = client.post(
        "https://www.reddit.com/api/v1/access_token",
        auth=(client_id, client_secret),
        data=data,
        headers=_reddit_headers(),
    )
    resp.raise_for_status()
    return resp.json().get("access_token")


def _reddit_item_from_post(source_name: str, post: dict) -> Optional[dict]:
    permalink = post.get("permalink") or ""
    link = f"https://www.reddit.com{permalink}" if permalink else post.get("url", "")
    if not link:
        return None

    created_utc = post.get("created_utc")
    published = ""
    if created_utc:
        try:
            published = datetime.fromtimestamp(float(created_utc), tz=timezone.utc).isoformat()
        except Exception:
            published = ""
    if is_too_old(published):
        return None

    title = post.get("title", "")
    summary = (post.get("selftext") or post.get("selftext_html") or "")[:500]
    score = int(post.get("score") or 0)
    kw_score, matched = score_item(title, summary)
    return {
        "id": url_hash(link),
        "source": source_name,
        "url": link,
        "title": title,
        "score": kw_score,
        "raw_score": score,
        "keywords_matched": matched,
        "summary_raw": summary,
        "fetched_at": datetime.now(timezone.utc).isoformat(),
        "published_at": published,
        "synthesis": None,
    }


def _collect_reddit_from_listing(
    source_name: str,
    listing: dict,
    min_upvotes: int,
    seen: dict,
    dry_run: bool = False,
) -> list[dict]:
    items = []
    children = listing.get("data", {}).get("children", [])
    for child in children[:25]:
        post = child.get("data", child)
        if not isinstance(post, dict):
            continue

        score = int(post.get("score") or 0)
        if score < min_upvotes:
            continue

        item = _reddit_item_from_post(source_name, post)
        if not item or item["id"] in seen:
            continue

        if save_item(item, dry_run):
            seen[item["id"]] = datetime.now(timezone.utc).isoformat()
            items.append(item)
            log.info(f"  + {source_name}: {item['title'][:70]} (pts={score}, kw={item['score']})")
    return items


def _collect_reddit_from_rss(source_name: str, feed_data: bytes, seen: dict, dry_run: bool = False) -> list[dict]:
    items = []
    feed = feedparser.parse(feed_data)
    for entry in feed.entries[:25]:
        link = entry.get("link", "")
        if not link:
            continue

        item_id = url_hash(link)
        if item_id in seen:
            continue

        published = entry.get("published", entry.get("updated", ""))
        if is_too_old(published):
            continue

        title = entry.get("title", "")
        content = entry.get("content", [{}])
        content_text = content[0].get("value", "") if content else ""
        score = 0
        score_match = re.search(r"(\d+)\s+points?", content_text)
        if score_match:
            score = int(score_match.group(1))

        summary = entry.get("summary", "")[:500]
        kw_score, matched = score_item(title, summary)
        item = {
            "id": item_id,
            "source": source_name,
            "url": link,
            "title": title,
            "score": kw_score,
            "raw_score": score,
            "keywords_matched": matched,
            "summary_raw": summary,
            "fetched_at": datetime.now(timezone.utc).isoformat(),
            "published_at": published,
            "synthesis": None,
        }
        if save_item(item, dry_run):
            seen[item_id] = datetime.now(timezone.utc).isoformat()
            items.append(item)
            log.info(f"  + {source_name}: {title[:70]} (kw={kw_score})")
    return items


def _normalize_reddit_config(
    source_name: str,
    config_or_url,
    min_upvotes: Optional[int],
    seen: Optional[dict],
) -> tuple[str, int, dict]:
    source_config = CONFIG.get("sources", {}).get(source_name, {})
    if isinstance(config_or_url, dict):
        config = {**source_config, **config_or_url}
    else:
        config = dict(source_config)
        if config_or_url:
            config["url"] = config_or_url

    subreddit = config.get("subreddit") or _extract_subreddit(config.get("url", ""))
    if not subreddit:
        raise ValueError(f"Reddit source {source_name} is missing a subreddit")

    resolved_min_upvotes = config.get("min_upvotes", min_upvotes if min_upvotes is not None else 0) or 0
    return subreddit, int(resolved_min_upvotes), seen if seen is not None else load_seen()


def collect_reddit(
    source_name: str,
    config_or_url,
    min_upvotes: Optional[int] = None,
    seen: Optional[dict] = None,
    dry_run: bool = False,
) -> list[dict]:
    """Collect Reddit posts with `old.reddit.com` JSON first, then OAuth, then RSS."""
    subreddit, min_upvotes, seen = _normalize_reddit_config(source_name, config_or_url, min_upvotes, seen)
    log.info(f"Collecting Reddit: {source_name} (r/{subreddit})...")

    attempts = []
    try:
        with httpx.Client(timeout=15, follow_redirects=True) as client:
            try:
                resp = client.get(
                    f"https://old.reddit.com/r/{subreddit}/hot/.json",
                    params={"limit": 25, "raw_json": 1},
                    headers=_reddit_headers(),
                )
                resp.raise_for_status()
                items = _collect_reddit_from_listing(source_name, resp.json(), min_upvotes, seen, dry_run)
                update_status(source_name, "ok", len(items))
                return items
            except Exception as e:
                attempts.append(f"old.reddit JSON: {e}")
                log.warning(f"{source_name} old.reddit JSON failed: {e}")

            try:
                access_token = _get_reddit_access_token(client)
                if access_token:
                    resp = client.get(
                        f"https://oauth.reddit.com/r/{subreddit}/hot",
                        params={"limit": 25, "raw_json": 1},
                        headers=_reddit_headers(access_token=access_token),
                    )
                    resp.raise_for_status()
                    items = _collect_reddit_from_listing(source_name, resp.json(), min_upvotes, seen, dry_run)
                    update_status(source_name, "ok", len(items))
                    return items
            except Exception as e:
                attempts.append(f"OAuth JSON: {e}")
                log.warning(f"{source_name} Reddit OAuth failed: {e}")

            try:
                resp = client.get(
                    f"https://www.reddit.com/r/{subreddit}/.rss",
                    headers=_reddit_headers(
                        accept="application/rss+xml, application/atom+xml;q=0.9, application/xml;q=0.8, */*;q=0.1"
                    ),
                )
                resp.raise_for_status()
                items = _collect_reddit_from_rss(source_name, resp.content, seen, dry_run)
                update_status(source_name, "ok", len(items))
                return items
            except Exception as e:
                attempts.append(f"RSS fallback: {e}")
                log.warning(f"{source_name} Reddit RSS fallback failed: {e}")
                raise
    except Exception:
        error = " | ".join(attempts) if attempts else "unknown Reddit collector failure"
        log.error(f"{source_name} Reddit collection failed: {error}")
        update_status(source_name, "error", 0, error)
        return []


# ── Semantic Dedup ─────────────────────────────────────────────────────────────

def _embed_titles(titles: list[str], timeout: float = 10.0) -> list[list[float]]:
    """Embed titles via Ollama nomic-embed-text. Returns list of vectors."""
    try:
        with httpx.Client(timeout=timeout) as client:
            resp = client.post(
                "http://localhost:11434/api/embed",
                json={"model": "nomic-embed-text", "input": titles},
            )
            resp.raise_for_status()
            return resp.json().get("embeddings", [])
    except Exception as e:
        log.warning(f"Embedding failed (non-fatal, skipping dedup): {e}")
        return []


def _cosine_similarity(a: list[float], b: list[float]) -> float:
    """Cosine similarity between two vectors."""
    dot = sum(x * y for x, y in zip(a, b))
    norm_a = sum(x * x for x in a) ** 0.5
    norm_b = sum(x * x for x in b) ** 0.5
    if norm_a == 0 or norm_b == 0:
        return 0.0
    return dot / (norm_a * norm_b)


def _load_recent_embeddings(limit: int = 100) -> list[tuple[str, list[float]]]:
    """Load recent item titles and their embeddings from cache."""
    cache_file = BASE / "embeddings_cache.json"
    if not cache_file.exists():
        return []
    try:
        data = json.loads(cache_file.read_text())
        return [(e["title"], e["vector"]) for e in data[-limit:]]
    except Exception:
        return []


def _save_embeddings_cache(entries: list[tuple[str, list[float]]]) -> None:
    """Save embeddings cache, keeping last 200 entries."""
    cache_file = BASE / "embeddings_cache.json"
    existing = []
    if cache_file.exists():
        try:
            existing = json.loads(cache_file.read_text())
        except Exception:
            pass
    for title, vector in entries:
        existing.append({"title": title, "vector": vector})
    # Keep last 200
    existing = existing[-200:]
    cache_file.write_text(json.dumps(existing))


def semantic_dedup(items: list[dict], threshold: float = 0.9) -> list[dict]:
    """Remove near-duplicate items using embedding similarity. Returns filtered list."""
    if not items:
        return items

    new_titles = [item["title"] for item in items]
    new_vectors = _embed_titles(new_titles)
    if not new_vectors or len(new_vectors) != len(items):
        log.info("Semantic dedup skipped (embedding unavailable)")
        return items

    recent = _load_recent_embeddings(100)

    kept = []
    kept_vectors = []
    for i, item in enumerate(items):
        vec = new_vectors[i]
        is_dup = False

        # Check against recent historical items
        for _, old_vec in recent:
            if _cosine_similarity(vec, old_vec) > threshold:
                is_dup = True
                log.info(f"  ⊘ Dedup (history): {item['title'][:60]}")
                break

        # Check against other items in this batch
        if not is_dup:
            for kept_vec in kept_vectors:
                if _cosine_similarity(vec, kept_vec) > threshold:
                    is_dup = True
                    log.info(f"  ⊘ Dedup (batch): {item['title'][:60]}")
                    break

        if not is_dup:
            kept.append(item)
            kept_vectors.append(vec)

    # Save new embeddings to cache
    new_entries = [(items[i]["title"], new_vectors[i]) for i in range(len(items)) if items[i] in kept]
    _save_embeddings_cache(new_entries)

    if len(kept) < len(items):
        log.info(f"Semantic dedup: {len(items)} → {len(kept)} items ({len(items) - len(kept)} duplicates removed)")

    return kept


# ── Week 2 Sources ────────────────────────────────────────────────────────────

def collect_bluesky(seen: dict, dry_run: bool = False) -> list[dict]:
    """
    Bluesky AT Protocol — no auth needed for public feeds.
    Enable in config.yaml: sources.bluesky.enabled = true
    """
    bsky_cfg = CONFIG.get("sources", {}).get("bluesky", {})
    if not bsky_cfg.get("enabled", False):
        return []

    log.info("Collecting Bluesky...")
    items = []
    accounts = bsky_cfg.get("accounts", [])
    limit = bsky_cfg.get("limit_per_run", 50)

    try:
        with httpx.Client(timeout=15) as client:
            for account in accounts:
                # Fetch recent posts (public API accepts handles directly)
                feed_resp = client.get(
                    "https://public.api.bsky.app/xrpc/app.bsky.feed.getAuthorFeed",
                    params={"actor": account, "limit": 20},
                )
                if feed_resp.status_code != 200:
                    log.warning(f"Bluesky: failed to fetch @{account} (HTTP {feed_resp.status_code})")
                    continue

                for post_item in feed_resp.json().get("feed", []):
                    post = post_item.get("post", {})
                    record = post.get("record", {})
                    text = record.get("text", "")
                    if not text or len(text) < 20:
                        continue

                    uri = post.get("uri", "")
                    url = f"https://bsky.app/profile/{account}/post/{uri.split('/')[-1]}" if uri else ""
                    item_id = url_hash(url or text)
                    if item_id in seen:
                        continue

                    kw_score, matched = score_item(text)
                    item = {
                        "id": item_id,
                        "source": "bluesky",
                        "url": url,
                        "title": text[:120],
                        "score": kw_score,
                        "raw_score": post.get("likeCount", 0),
                        "keywords_matched": matched,
                        "author": account,
                        "summary_raw": text[:500],
                        "fetched_at": datetime.now(timezone.utc).isoformat(),
                        "published_at": record.get("createdAt", ""),
                        "synthesis": None,
                    }
                    if save_item(item, dry_run):
                        seen[item_id] = datetime.now(timezone.utc).isoformat()
                        items.append(item)
                        log.info(f"  + Bluesky @{account}: {text[:60]} (kw={kw_score})")

        update_status("bluesky", "ok", len(items))
    except Exception as e:
        log.error(f"Bluesky collection failed: {e}")
        update_status("bluesky", "error", 0, str(e))
    return items


# ── Round 2 Sources ───────────────────────────────────────────────────────────

TRENDS_DIR = BASE / "trends"
TRENDS_DIR.mkdir(parents=True, exist_ok=True)

AI_KEYWORDS = [
    "ai", "agent", "mcp", "llm", "model context protocol", "claude",
    "openai", "anthropic", "tool use", "multi-agent", "autonomous",
    "rag", "embedding", "copilot", "gpt", "gemini", "mistral",
]


def _text_matches_ai_keywords(text: str) -> bool:
    """Check if text contains AI/agent/MCP related keywords."""
    lower = text.lower()
    return any(kw in lower for kw in AI_KEYWORDS)


def collect_producthunt(seen: dict, dry_run: bool = False) -> list[dict]:
    """Product Hunt RSS — filter for AI/agent/MCP related products."""
    cfg = CONFIG.get("sources", {}).get("producthunt", {})
    if not cfg.get("enabled", False):
        return []
    log.info("Collecting Product Hunt...")
    items = []
    try:
        feed = feedparser.parse(cfg["url"])
        for entry in feed.entries[:30]:
            link = entry.get("link", "")
            if not link:
                continue
            title = entry.get("title", "")
            summary = entry.get("summary", "")[:500]
            # Filter: only AI/agent/MCP related products
            if not _text_matches_ai_keywords(title + " " + summary):
                continue
            item_id = url_hash(link)
            if item_id in seen:
                continue
            published = entry.get("published", entry.get("updated", ""))
            if is_too_old(published):
                continue
            kw_score, matched = score_item(title, summary)
            item = {
                "id": item_id,
                "source": "producthunt",
                "url": link,
                "title": title,
                "score": kw_score,
                "raw_score": 0,
                "keywords_matched": matched,
                "summary_raw": summary,
                "fetched_at": datetime.now(timezone.utc).isoformat(),
                "published_at": published,
                "synthesis": None,
            }
            if save_item(item, dry_run):
                seen[item_id] = datetime.now(timezone.utc).isoformat()
                items.append(item)
                log.info(f"  + ProductHunt: {title[:70]} (kw={kw_score})")
        update_status("producthunt", "ok", len(items))
    except Exception as e:
        log.error(f"Product Hunt collection failed: {e}")
        update_status("producthunt", "error", 0, str(e))
    return items


def collect_npm_mcp(seen: dict, dry_run: bool = False) -> list[dict]:
    """npm registry — poll for new MCP server packages."""
    cfg = CONFIG.get("sources", {}).get("npm_mcp", {})
    if not cfg.get("enabled", False):
        return []
    log.info("Collecting npm MCP packages...")
    # Load previously seen package names
    npm_seen_file = BASE / "npm_seen.json"
    npm_seen = set()
    if npm_seen_file.exists():
        try:
            npm_seen = set(json.loads(npm_seen_file.read_text()))
        except Exception:
            pass

    items = []
    try:
        with httpx.Client(timeout=15) as client:
            resp = client.get(cfg["url"])
            resp.raise_for_status()
            data = resp.json()
            for obj in data.get("objects", []):
                pkg = obj.get("package", {})
                name = pkg.get("name", "")
                if not name or "mcp" not in name.lower():
                    continue
                if name in npm_seen:
                    continue
                url = f"https://www.npmjs.com/package/{name}"
                item_id = url_hash(url)
                if item_id in seen:
                    npm_seen.add(name)
                    continue
                description = pkg.get("description", "")[:500]
                version = pkg.get("version", "")
                kw_score, matched = score_item(name, description)
                published = pkg.get("date", "")
                item = {
                    "id": item_id,
                    "source": "npm_mcp",
                    "url": url,
                    "title": f"{name}@{version}" if version else name,
                    "score": kw_score,
                    "raw_score": 0,
                    "keywords_matched": matched,
                    "summary_raw": description,
                    "author": pkg.get("author", {}).get("name", "") if isinstance(pkg.get("author"), dict) else str(pkg.get("author", "")),
                    "fetched_at": datetime.now(timezone.utc).isoformat(),
                    "published_at": published,
                    "synthesis": None,
                }
                if save_item(item, dry_run):
                    seen[item_id] = datetime.now(timezone.utc).isoformat()
                    items.append(item)
                    log.info(f"  + npm: {name}@{version} (kw={kw_score})")
                npm_seen.add(name)

        # Persist seen package names
        if not dry_run:
            npm_seen_file.write_text(json.dumps(sorted(npm_seen), indent=2))
        update_status("npm_mcp", "ok", len(items))
    except Exception as e:
        log.error(f"npm MCP collection failed: {e}")
        update_status("npm_mcp", "error", 0, str(e))
    return items


def collect_pypi_updates(seen: dict, dry_run: bool = False) -> list[dict]:
    """PyPI updates RSS — filter for AI/agent/MCP keywords."""
    cfg = CONFIG.get("sources", {}).get("pypi_updates", {})
    if not cfg.get("enabled", False):
        return []
    log.info("Collecting PyPI updates...")
    items = []
    try:
        feed = feedparser.parse(cfg["url"])
        for entry in feed.entries[:50]:
            title = entry.get("title", "")
            summary = entry.get("summary", "")[:500]
            link = entry.get("link", "")
            if not link:
                continue
            # Filter: only AI/agent/MCP related packages
            if not _text_matches_ai_keywords(title + " " + summary):
                continue
            item_id = url_hash(link)
            if item_id in seen:
                continue
            published = entry.get("published", entry.get("updated", ""))
            if is_too_old(published):
                continue
            kw_score, matched = score_item(title, summary)
            item = {
                "id": item_id,
                "source": "pypi_updates",
                "url": link,
                "title": title,
                "score": kw_score,
                "raw_score": 0,
                "keywords_matched": matched,
                "summary_raw": summary,
                "fetched_at": datetime.now(timezone.utc).isoformat(),
                "published_at": published,
                "synthesis": None,
            }
            if save_item(item, dry_run):
                seen[item_id] = datetime.now(timezone.utc).isoformat()
                items.append(item)
                log.info(f"  + PyPI: {title[:70]} (kw={kw_score})")
        update_status("pypi_updates", "ok", len(items))
    except Exception as e:
        log.error(f"PyPI updates collection failed: {e}")
        update_status("pypi_updates", "error", 0, str(e))
    return items


def collect_github_releases(seen: dict, dry_run: bool = False) -> list[dict]:
    """GitHub release Atom feeds for key repos."""
    cfg = CONFIG.get("sources", {}).get("github_releases", {})
    if not cfg.get("enabled", False):
        return []
    log.info("Collecting GitHub releases...")
    items = []
    feeds = cfg.get("feeds", [])
    for feed_url in feeds:
        try:
            feed = feedparser.parse(feed_url)
            # Derive repo name from URL
            repo_name = "/".join(feed_url.replace("https://github.com/", "").split("/")[:2])
            for entry in feed.entries[:10]:
                link = entry.get("link", "")
                if not link:
                    continue
                item_id = url_hash(link)
                if item_id in seen:
                    continue
                published = entry.get("published", entry.get("updated", ""))
                if is_too_old(published):
                    continue
                title = entry.get("title", "")
                summary = entry.get("summary", "")[:500]
                kw_score, matched = score_item(f"{repo_name} {title}", summary)
                item = {
                    "id": item_id,
                    "source": "github_releases",
                    "url": link,
                    "title": f"{repo_name}: {title}",
                    "score": kw_score,
                    "raw_score": 0,
                    "keywords_matched": matched,
                    "summary_raw": summary,
                    "fetched_at": datetime.now(timezone.utc).isoformat(),
                    "published_at": published,
                    "synthesis": None,
                }
                if save_item(item, dry_run):
                    seen[item_id] = datetime.now(timezone.utc).isoformat()
                    items.append(item)
                    log.info(f"  + Release: {repo_name}: {title[:50]} (kw={kw_score})")
        except Exception as e:
            log.error(f"GitHub releases failed for {feed_url}: {e}")
    update_status("github_releases", "ok", len(items))
    return items


def collect_star_velocity(seen: dict, dry_run: bool = False) -> list[dict]:
    """Star velocity detector — track star counts for GitHub trending repos, flag 1000+ gains."""
    log.info("Checking star velocity...")
    history_file = TRENDS_DIR / "star_history.json"
    history = {}
    if history_file.exists():
        try:
            history = json.loads(history_file.read_text())
        except Exception:
            pass

    items = []
    # Read recent github_trending items to get repos to check
    repos_to_check = []
    for path in sorted(ITEMS_DIR.glob("*.json"), reverse=True)[:200]:
        try:
            item = json.loads(path.read_text())
            if item.get("source") == "github_trending":
                owner_repo = item.get("title", "")
                import re as _re
                # Must be exactly owner/repo format, reject navigation links
                if (_re.match(r'^[A-Za-z0-9_.-]+/[A-Za-z0-9_.-]+$', owner_repo)
                        and owner_repo.split("/")[0] not in ("trending", "sponsors", "collections", "topics")):
                    repos_to_check.append(owner_repo)
        except Exception:
            continue

    if not repos_to_check:
        log.info("  No GitHub trending repos to check star velocity for.")
        return items

    # Deduplicate
    repos_to_check = list(dict.fromkeys(repos_to_check))[:30]  # cap at 30

    try:
        with httpx.Client(timeout=15) as client:
            for repo in repos_to_check:
                try:
                    resp = client.get(
                        f"https://api.github.com/repos/{repo}",
                        headers={"Accept": "application/vnd.github.v3+json", "User-Agent": "OpenClaw-Intelligence/1.0"},
                    )
                    if resp.status_code != 200:
                        continue
                    data = resp.json()
                    current_stars = data.get("stargazers_count", 0)
                    prev = history.get(repo, {})
                    prev_stars = prev.get("stars", 0)
                    prev_date = prev.get("date", "")

                    # Update history
                    history[repo] = {
                        "stars": current_stars,
                        "date": datetime.now(timezone.utc).isoformat(),
                    }

                    # Flag repos that gained 1000+ stars since last check
                    if prev_stars > 0 and (current_stars - prev_stars) >= 1000:
                        gain = current_stars - prev_stars
                        url = f"https://github.com/{repo}"
                        item_id = url_hash(f"star_velocity_{repo}_{datetime.now(timezone.utc).strftime('%Y%m%d')}")
                        if item_id in seen:
                            continue
                        kw_score, matched = score_item(repo.replace("/", " ").replace("-", " "))
                        item = {
                            "id": item_id,
                            "source": "star_velocity",
                            "url": url,
                            "title": f"Star velocity: {repo} gained {gain:,} stars",
                            "score": max(kw_score, 3),  # minimum score 3 for velocity events
                            "raw_score": current_stars,
                            "keywords_matched": matched,
                            "summary_raw": f"{repo} gained {gain:,} stars (from {prev_stars:,} to {current_stars:,}) since {prev_date}",
                            "fetched_at": datetime.now(timezone.utc).isoformat(),
                            "published_at": datetime.now(timezone.utc).isoformat(),
                            "synthesis": None,
                        }
                        if save_item(item, dry_run):
                            seen[item_id] = datetime.now(timezone.utc).isoformat()
                            items.append(item)
                            log.warning(f"  ★ STAR VELOCITY: {repo} +{gain:,} stars!")
                    time.sleep(0.5)  # GitHub API rate limiting
                except Exception as e:
                    log.warning(f"  Star check failed for {repo}: {e}")
                    continue
    except Exception as e:
        log.error(f"Star velocity check failed: {e}")

    # Save updated history
    if not dry_run:
        history_file.write_text(json.dumps(history, indent=2))
    update_status("star_velocity", "ok", len(items))
    return items


# ── Main ───────────────────────────────────────────────────────────────────────

def main():
    parser = argparse.ArgumentParser(description="OpenClaw Intelligence Collector")
    parser.add_argument("--source", help="Run only this source (hn/simon/arxiv/github)")
    parser.add_argument("--dry-run", action="store_true", help="Print items without saving")
    args = parser.parse_args()

    seen = load_seen()
    all_items = []

    sources = {
        "hn": lambda: collect_hn(seen, args.dry_run),
        "simon": lambda: collect_rss("simon_willison", "https://simonwillison.net/atom/everything/", seen, args.dry_run),
        "arxiv_ma": lambda: collect_rss("arxiv_ma", "https://arxiv.org/rss/cs.MA", seen, args.dry_run),
        "arxiv_ai": lambda: collect_rss("arxiv_ai", "https://arxiv.org/rss/cs.AI", seen, args.dry_run),
        "github": lambda: collect_github_trending(seen, args.dry_run),
        "github_trending": lambda: collect_github_trending(seen, args.dry_run),
        "bluesky": lambda: collect_bluesky(seen, args.dry_run),
        # Reddit feeds
        "reddit_localllama": lambda: collect_reddit(
            "reddit_localllama", "https://www.reddit.com/r/LocalLLaMA/hot/.rss",
            CONFIG.get("sources", {}).get("reddit_localllama", {}).get("min_upvotes", 100),
            seen, args.dry_run,
        ),
        "reddit_claudeai": lambda: collect_reddit(
            "reddit_claudeai", "https://www.reddit.com/r/ClaudeAI/hot/.rss",
            CONFIG.get("sources", {}).get("reddit_claudeai", {}).get("min_upvotes", 100),
            seen, args.dry_run,
        ),
        "reddit_machinelearning": lambda: collect_reddit(
            "reddit_machinelearning", "https://www.reddit.com/r/MachineLearning/hot/.rss",
            CONFIG.get("sources", {}).get("reddit_machinelearning", {}).get("min_upvotes", 100),
            seen, args.dry_run,
        ),
        # awesome-mcp-servers GitHub commit feed
        "awesome_mcp_servers": lambda: collect_rss(
            "awesome_mcp_servers",
            "https://github.com/punkpeye/awesome-mcp-servers/commits/main.atom",
            seen, args.dry_run,
        ),
        # Round 2 sources
        "producthunt": lambda: collect_producthunt(seen, args.dry_run),
        "npm_mcp": lambda: collect_npm_mcp(seen, args.dry_run),
        "pypi_updates": lambda: collect_pypi_updates(seen, args.dry_run),
        "github_releases": lambda: collect_github_releases(seen, args.dry_run),
        "star_velocity": lambda: collect_star_velocity(seen, args.dry_run),
    }

    to_run = [args.source] if args.source and args.source in sources else list(sources.keys())

    # Check enabled status from config for sources that have it
    source_configs = CONFIG.get("sources", {})
    enabled_check = {
        "reddit_localllama": "reddit_localllama",
        "reddit_claudeai": "reddit_claudeai",
        "reddit_machinelearning": "reddit_machinelearning",
        "awesome_mcp_servers": "awesome_mcp_servers",
        "bluesky": "bluesky",
        "producthunt": "producthunt",
        "npm_mcp": "npm_mcp",
        "pypi_updates": "pypi_updates",
        "github_releases": "github_releases",
    }

    for source_name in to_run:
        # Skip disabled sources
        cfg_key = enabled_check.get(source_name)
        if cfg_key and not source_configs.get(cfg_key, {}).get("enabled", False):
            continue

        lock = acquire_lock(source_name)
        if lock is None:
            continue
        try:
            items = sources[source_name]()
            all_items.extend(items)
        finally:
            release_lock(lock, source_name)

    # Semantic dedup: remove near-duplicates using embeddings
    if all_items and not args.dry_run:
        all_items = semantic_dedup(all_items)

    save_seen(seen)

    log.info(f"Collection complete: {len(all_items)} new items across {len(to_run)} sources")

    if args.dry_run:
        for item in all_items:
            print(f"\n{'='*60}")
            print(f"Source: {item['source']} | Score: {item['score']} | KW: {item['keywords_matched']}")
            print(f"Title:  {item['title']}")
            print(f"URL:    {item['url']}")

    # Write last_run job record
    last_run = {
        "timestamp": datetime.now(timezone.utc).isoformat(),
        "sources_run": to_run,
        "items_collected": len(all_items),
        "status": "ok",
    }
    (JOBS_DIR / "last_run.json").write_text(json.dumps(last_run, indent=2))

    return 0


if __name__ == "__main__":
    sys.exit(main())
