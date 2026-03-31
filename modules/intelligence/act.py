#!/usr/bin/env python3
"""
OpenClaw Intelligence Action Layer — v2 (Autonomous Self-Improvement Agent)

Pipeline: collector.py → filter.py → act.py → digest.py

  collector.py  — pulls items from HN, GitHub Trending, arXiv, blogs; deduplicates, scores keywords
  filter.py     — two-pass LLM classification (cheap classify → expensive synthesis for top items)
  act.py        — reads classified items and takes autonomous action based on classification (THIS FILE)
  digest.py     — formats a readable markdown digest sorted by priority

v2 additions:
  - Auto-install Claude Code skills (repos with 'skill'/'claude-skill' in name, 100+ stars)
  - Auto-install OpenClaw skills (tagged 'openclaw-skill')
  - Auto-pull Ollama models + benchmark vs nomic-embed-text
  - Memory technique extraction (RAG, chunking, embedding, prompt engineering)
  - Breaking change detection for tools we use
  - Self-tracking: all actions logged to auto_actions.json
  - Dangerous actions → pending_approval.json instead of auto-executing
"""

import argparse
import json
import logging
import re
import shutil
import sys
import time
from datetime import datetime, timezone, date
from pathlib import Path

from typing import Optional, List, Dict

import subprocess

import httpx
import yaml

# ── Paths ──────────────────────────────────────────────────────────────────────
BASE = Path(__file__).parent
ITEMS_DIR = BASE / "items"
HOT_FILE = BASE / "hot.json"
ACTIONS_DIR = BASE / "actions"
PROCESSED_FILE = ACTIONS_DIR / "processed.json"
LAST_RUN_FILE = ACTIONS_DIR / "last_run.json"
MONITORED_FILE = ACTIONS_DIR / "monitored.jsonl"
PENDING_DIR = ACTIONS_DIR / "pending"
ALERTS_DIR = ACTIONS_DIR / "alerts"

WORKSPACE = Path.home() / ".openclaw" / "workspace"
MEMORY_INTEL = WORKSPACE / "memory" / "intel"
THREATS_DIR = MEMORY_INTEL / "threats"
EVALUATIONS_DIR = MEMORY_INTEL / "evaluations"
DAILY_DIR = MEMORY_INTEL / "daily"
PROJECTS_DIR = WORKSPACE / "projects"
AUTO_INSTALLED_FILE = ACTIONS_DIR / "auto_installed.json"
SKILLS_EVALUATED_FILE = ACTIONS_DIR / "skills_evaluated.json"
URGENT_FILE = BASE / "urgent.json"
CONFIG_FILE = BASE / "config.yaml"
ACCOUNTS_ADDED_FILE = ACTIONS_DIR / "accounts_added.json"
KEYWORDS_ADDED_FILE = ACTIONS_DIR / "keywords_added.json"
TAG_FREQUENCY_FILE = BASE / "trends" / "tag_frequency.json"

# ── v2 paths (autonomous self-improvement) ────────────────────────────────────
AUTO_ACTIONS_FILE = ACTIONS_DIR / "auto_actions.json"
PENDING_APPROVAL_FILE = ACTIONS_DIR / "pending_approval.json"
MODEL_BENCHMARKS_FILE = ACTIONS_DIR / "model_benchmarks.json"
IMPROVEMENTS_QUEUE_FILE = ACTIONS_DIR / "improvements_queue.json"
BREAKING_CHANGES_FILE = ACTIONS_DIR / "breaking_changes.json"
IMPROVEMENTS_LOG = MEMORY_INTEL / "improvements.md"
TECHNIQUES_DIR = MEMORY_INTEL / "techniques"
CLAUDE_SKILLS_DIR = Path.home() / ".claude" / "skills"
OPENCLAW_SKILLS_DIR = WORKSPACE / "skills"

# Directories to scan for dependency files
DEP_SCAN_DIRS = [
    WORKSPACE / "projects",
    Path.home() / "Claude Code",
    Path.home() / "Projects",
]

# Tools we use — for breaking change detection
OUR_TOOLS = {"ollama", "claude", "anthropic", "openai", "cloudflare", "mcp",
             "chromadb", "chroma", "litellm", "httpx", "fastapi", "uvicorn"}

TODAY = date.today().isoformat()

# ── Logging ────────────────────────────────────────────────────────────────────
logging.basicConfig(
    level=logging.INFO,
    format="%(asctime)s [act] %(levelname)s %(message)s",
    datefmt="%H:%M:%S",
)
KEYWORD_STOPWORDS = {
    'python', 'github', 'javascript', 'typescript', 'rust', 'go', 'ruby',
    'noise', 'generic', 'no-content', 'weekly', 'daily', 'monthly',
    'metadata-only', 'language-filter', 'other', 'none', 'unknown',
    'meta', 'data', 'file', 'files', 'code', 'tool', 'tools',
    'http', 'https', 'api', 'web', 'app', 'new', 'update',
}

log = logging.getLogger("act")

# ── Helpers ────────────────────────────────────────────────────────────────────

def ensure_dirs():
    """Create all output directories if they don't exist."""
    for d in [ACTIONS_DIR, PENDING_DIR, ALERTS_DIR, TAG_FREQUENCY_FILE.parent,
              THREATS_DIR, EVALUATIONS_DIR, DAILY_DIR, TECHNIQUES_DIR,
              CLAUDE_SKILLS_DIR, OPENCLAW_SKILLS_DIR]:
        d.mkdir(parents=True, exist_ok=True)


def append_json_log(path: Path, entry: Dict) -> None:
    """Append an entry to a JSON array log file."""
    existing = []
    if path.exists():
        try:
            existing = json.loads(path.read_text())
        except Exception:
            existing = []
    existing.append(entry)
    path.write_text(json.dumps(existing, indent=2) + "\n")


def log_auto_action(action_type: str, item_id: str, title: str, what_done: str,
                    success: bool, details: Optional[Dict] = None) -> None:
    """Log every autonomous action to auto_actions.json for self-tracking."""
    entry = {
        "timestamp": datetime.now(timezone.utc).isoformat(),
        "action_type": action_type,
        "item_id": item_id,
        "title": title,
        "what_done": what_done,
        "success": success,
    }
    if details:
        entry["details"] = details
    append_json_log(AUTO_ACTIONS_FILE, entry)


def request_approval(action_type: str, item_id: str, title: str,
                     description: str, details: Optional[Dict] = None) -> None:
    """Write a dangerous action to pending_approval.json instead of executing."""
    entry = {
        "timestamp": datetime.now(timezone.utc).isoformat(),
        "action_type": action_type,
        "item_id": item_id,
        "title": title,
        "description": description,
        "status": "pending",
    }
    if details:
        entry["details"] = details
    append_json_log(PENDING_APPROVAL_FILE, entry)
    log.info("  → Pending approval: %s — %s", action_type, description)


def run_cmd(cmd: List[str], timeout: int = 60) -> subprocess.CompletedProcess:
    """Run a subprocess with timeout. Returns CompletedProcess."""
    return subprocess.run(cmd, capture_output=True, text=True, timeout=timeout)


def load_processed() -> Dict:
    """Load the set of already-processed item IDs."""
    if PROCESSED_FILE.exists():
        return json.loads(PROCESSED_FILE.read_text())
    return {}


def save_processed(processed: dict):
    PROCESSED_FILE.write_text(json.dumps(processed, indent=2) + "\n")


def load_items() -> List[Dict]:
    """Load all classified items from hot.json and items/*.json."""
    items = {}

    # hot.json items first
    if HOT_FILE.exists():
        try:
            for item in json.loads(HOT_FILE.read_text()):
                if item.get("classification"):
                    items[item["id"]] = item
        except (json.JSONDecodeError, KeyError):
            log.warning("Failed to parse hot.json")

    # Then items/*.json
    if ITEMS_DIR.exists():
        for f in ITEMS_DIR.glob("*.json"):
            try:
                item = json.loads(f.read_text())
                if item.get("classification") and item["id"] not in items:
                    items[item["id"]] = item
            except (json.JSONDecodeError, KeyError):
                log.warning("Failed to parse %s", f.name)

    return list(items.values())


def fetch_url(url: str) -> Optional[str]:
    """Fetch URL content with timeout. Returns text or None on failure."""
    try:
        resp = httpx.get(url, timeout=30, follow_redirects=True,
                         headers={"User-Agent": "OpenClaw-Intelligence/1.0"})
        resp.raise_for_status()
        return resp.text
    except Exception as e:
        log.warning("Failed to fetch %s: %s", url, e)
        return None


def extract_text_summary(html: str, max_chars: int = 2000) -> str:
    """Extract readable text from HTML, very basic."""
    text = re.sub(r'<script[^>]*>.*?</script>', '', html, flags=re.DOTALL)
    text = re.sub(r'<style[^>]*>.*?</style>', '', text, flags=re.DOTALL)
    text = re.sub(r'<[^>]+>', ' ', text)
    text = re.sub(r'\s+', ' ', text).strip()
    return text[:max_chars]


def extract_github_meta(html: str, url: str) -> Optional[Dict]:
    """Extract basic GitHub repo metadata from page HTML."""
    if "github.com" not in url:
        return None
    meta = {}
    stars_match = re.search(r'(\d[\d,]*)\s*stars?', html, re.IGNORECASE)
    if stars_match:
        meta["stars"] = stars_match.group(1).replace(",", "")
    lang_match = re.search(r'itemprop="programmingLanguage">([^<]+)', html)
    if lang_match:
        meta["language"] = lang_match.group(1).strip()
    desc_match = re.search(r'<meta\s+name="description"\s+content="([^"]*)"', html)
    if desc_match:
        meta["description"] = desc_match.group(1)[:200]
    commit_match = re.search(r'<relative-time[^>]*datetime="([^"]*)"', html)
    if commit_match:
        meta["last_commit"] = commit_match.group(1)
    return meta if meta else None


def extract_package_names(tags: List[str], title: str) -> List[str]:
    """Extract likely package names from tags and title for vulnerability matching."""
    GENERIC = {
        "security", "vulnerability", "cve", "exploit", "rce", "xss", "sqli",
        "patch", "update", "critical", "high", "medium", "low", "advisory",
        "the", "and", "for", "with", "new", "has", "are", "this", "that",
        "from", "can", "was", "bug", "fix", "release", "version", "in", "of",
        "mcp", "ai", "llm", "tool", "api", "tooling", "competitive",
    }
    candidates = set()
    for tag in tags:
        t = tag.lower().strip()
        if t and t not in GENERIC and len(t) > 1:
            candidates.add(t)
    for word in title.split():
        w = word.strip(".:;,()[]{}\"'<>v").lower()
        if w and w not in GENERIC and len(w) > 2 and not w.startswith("http"):
            candidates.add(w)
    return list(candidates)


def find_affected_deps(tags: List[str], title: str) -> List[Dict]:
    """Search local dependency files for the actual vulnerable package name."""
    package_names = extract_package_names(tags, title)
    if not package_names:
        return []

    findings = []
    dep_patterns = ["package.json", "requirements.txt", "Pipfile", "pyproject.toml"]

    dep_files = []
    for scan_dir in DEP_SCAN_DIRS:
        if scan_dir.exists():
            for pattern in dep_patterns:
                dep_files.extend(scan_dir.rglob(pattern))
    for name in dep_patterns:
        f = WORKSPACE / name
        if f.exists() and f not in dep_files:
            dep_files.append(f)

    for dep_file in dep_files:
        try:
            content = dep_file.read_text().lower()
            matched = [pkg for pkg in package_names if pkg in content]
            if matched:
                findings.append({
                    "file": str(dep_file),
                    "matched_terms": matched,
                })
        except Exception:
            continue

    return findings


def extract_mcp_install_info(readme_text: str, url: str) -> Optional[Dict]:
    """Parse a GitHub README for MCP server install commands."""
    repo_match = re.search(r'github\.com/[^/]+/([^/?\s#]+)', url)
    if not repo_match:
        return None
    repo_name = repo_match.group(1).rstrip("/")

    npx_match = re.search(r'npx\s+(?:-y\s+)?(@?[\w./@-]+)', readme_text)
    if npx_match:
        package_name = npx_match.group(1)
        return {
            "server_name": repo_name,
            "package_name": package_name,
            "install_method": "npx",
        }

    return None


def extract_repo_name(url: str) -> Optional[str]:
    """Extract 'org/repo' from a GitHub URL."""
    m = re.search(r'github\.com/([^/]+/[^/?\s#]+)', url)
    if m:
        return m.group(1).rstrip("/")
    return None


def auto_install_mcp_server(info: Dict, dry_run: bool) -> Dict:
    """Install an MCP server via `claude mcp add` and log the result."""
    result = {
        "server_name": info["server_name"],
        "package_name": info["package_name"],
        "install_method": info["install_method"],
        "installed_at": datetime.now(timezone.utc).isoformat(),
        "success": False,
        "error": None,
    }

    if dry_run:
        result["success"] = True
        result["dry_run"] = True
        log.info("  → [DRY RUN] Would auto-install MCP server: %s (%s)",
                 info["server_name"], info["package_name"])
        return result

    try:
        proc = run_cmd(
            ["claude", "mcp", "add", info["server_name"], "--", "npx", "-y", info["package_name"]],
        )
        if proc.returncode == 0:
            result["success"] = True
            log.info("  → Auto-installed MCP server: %s (%s)", info["server_name"], info["package_name"])
        else:
            result["error"] = proc.stderr.strip() or f"exit code {proc.returncode}"
            log.warning("  → MCP install failed for %s: %s", info["server_name"], result["error"])
    except Exception as e:
        result["error"] = str(e)
        log.warning("  → MCP install error for %s: %s", info["server_name"], e)

    append_json_log(AUTO_INSTALLED_FILE, result)
    return result


# ── v2: Auto-install Claude Code Skills ───────────────────────────────────────

def detect_claude_skill(item: dict) -> bool:
    """Check if item looks like a Claude Code skill repo."""
    url = item.get("url", "").lower()
    tags = [t.lower() for t in item.get("classification", {}).get("tags", [])]
    repo_name = (extract_repo_name(item.get("url", "")) or "").lower()

    has_skill_name = any(kw in repo_name for kw in ("skill", "claude-skill"))
    has_skill_tag = "claude-skill" in tags or "claude-skills" in tags or "claude-code" in tags

    stars = int(item.get("raw_score", 0)) if isinstance(item.get("raw_score"), (int, float)) else 0
    return (has_skill_name and stars >= 100) or has_skill_tag


def auto_install_claude_skill(item: dict, dry_run: bool) -> Optional[Dict]:
    """Clone a Claude Code skill repo to ~/.claude/skills/."""
    if not detect_claude_skill(item):
        return None

    url = item.get("url", "")
    repo_name = extract_repo_name(url)
    if not repo_name:
        return None

    short_name = repo_name.split("/")[-1]
    dest = CLAUDE_SKILLS_DIR / short_name

    if dest.exists():
        log.info("  → Claude skill already installed: %s", short_name)
        return None

    result = {
        "type": "claude_skill",
        "repo": repo_name,
        "dest": str(dest),
        "installed_at": datetime.now(timezone.utc).isoformat(),
        "success": False,
    }

    if dry_run:
        result["success"] = True
        result["dry_run"] = True
        log.info("  → [DRY RUN] Would install Claude skill: %s", repo_name)
        log_auto_action("claude_skill_install", item["id"], item.get("title", ""),
                        f"[DRY RUN] Would clone {repo_name} to {dest}", True)
        return result

    clone_url = f"https://github.com/{repo_name}.git"
    try:
        proc = run_cmd(["git", "clone", "--depth", "1", clone_url, str(dest)])
        if proc.returncode == 0:
            result["success"] = True
            log.info("  → Installed Claude skill: %s → %s", repo_name, dest)
        else:
            result["error"] = proc.stderr.strip()
            log.warning("  → Claude skill clone failed: %s", result["error"])
    except Exception as e:
        result["error"] = str(e)
        log.warning("  → Claude skill install error: %s", e)

    append_json_log(AUTO_INSTALLED_FILE, result)
    log_auto_action("claude_skill_install", item["id"], item.get("title", ""),
                    f"Cloned {repo_name} to {dest}", result["success"], result)
    return result


# ── v2: Auto-install OpenClaw Skills ──────────────────────────────────────────

def detect_openclaw_skill(item: dict) -> bool:
    """Check if item is tagged as an OpenClaw skill."""
    tags = [t.lower() for t in item.get("classification", {}).get("tags", [])]
    return "openclaw-skill" in tags


def auto_install_openclaw_skill(item: dict, dry_run: bool) -> Optional[Dict]:
    """Clone an OpenClaw skill repo to ~/.openclaw/workspace/skills/."""
    if not detect_openclaw_skill(item):
        return None

    url = item.get("url", "")
    repo_name = extract_repo_name(url)
    if not repo_name:
        return None

    short_name = repo_name.split("/")[-1]
    dest = OPENCLAW_SKILLS_DIR / short_name

    if dest.exists():
        log.info("  → OpenClaw skill already installed: %s", short_name)
        return None

    result = {
        "type": "openclaw_skill",
        "repo": repo_name,
        "dest": str(dest),
        "installed_at": datetime.now(timezone.utc).isoformat(),
        "success": False,
    }

    if dry_run:
        result["success"] = True
        result["dry_run"] = True
        log.info("  → [DRY RUN] Would install OpenClaw skill: %s", repo_name)
        log_auto_action("openclaw_skill_install", item["id"], item.get("title", ""),
                        f"[DRY RUN] Would clone {repo_name} to {dest}", True)
        return result

    clone_url = f"https://github.com/{repo_name}.git"
    try:
        proc = run_cmd(["git", "clone", "--depth", "1", clone_url, str(dest)])
        if proc.returncode == 0:
            result["success"] = True
            log.info("  → Installed OpenClaw skill: %s → %s", repo_name, dest)
        else:
            result["error"] = proc.stderr.strip()
            log.warning("  → OpenClaw skill clone failed: %s", result["error"])
    except Exception as e:
        result["error"] = str(e)
        log.warning("  → OpenClaw skill install error: %s", e)

    append_json_log(AUTO_INSTALLED_FILE, result)
    log_auto_action("openclaw_skill_install", item["id"], item.get("title", ""),
                    f"Cloned {repo_name} to {dest}", result["success"], result)
    return result


# ── v2: Auto-pull Ollama Models ───────────────────────────────────────────────

EMBEDDING_KEYWORDS = {"embedding", "embed", "embeddings", "sentence-transformer",
                      "nomic", "bge", "gte", "e5", "arctic-embed"}
SMALL_LLM_KEYWORDS = {"llama", "phi", "qwen", "gemma", "mistral", "tinyllama", "smollm"}
OLLAMA_MODEL_PATTERN = re.compile(r'(?:ollama\s+(?:pull|run)\s+)?([\w./:_-]+:\S+|[\w./_-]+)', re.IGNORECASE)


def detect_ollama_model(item: dict) -> Optional[str]:
    """Detect if item is about a new Ollama-compatible model. Returns model name or None."""
    title = item.get("title", "").lower()
    tags = [t.lower() for t in item.get("classification", {}).get("tags", [])]
    all_text = title + " " + " ".join(tags)

    is_model_item = any(kw in all_text for kw in ("ollama", "embedding model", "small llm", "gguf"))
    is_relevant_type = (
        any(kw in all_text for kw in EMBEDDING_KEYWORDS) or
        any(kw in all_text for kw in SMALL_LLM_KEYWORDS)
    )

    if not (is_model_item or is_relevant_type):
        return None

    m = OLLAMA_MODEL_PATTERN.search(item.get("title", ""))
    if m:
        return m.group(1)

    for kw in list(EMBEDDING_KEYWORDS) + list(SMALL_LLM_KEYWORDS):
        pattern = re.search(rf'({kw}[\w./:_-]*)', title, re.IGNORECASE)
        if pattern:
            return pattern.group(1)

    return None


def benchmark_embedding_model(model_name: str) -> Optional[Dict]:
    """Embed 10 test strings with the new model and nomic-embed-text, compare speed."""
    test_strings = [
        "How to implement RAG with ChromaDB",
        "Breaking changes in the latest API version",
        "Machine learning model fine-tuning techniques",
        "Kubernetes deployment best practices",
        "Python async programming patterns",
        "Vector database comparison benchmark",
        "Claude Code skill installation guide",
        "OpenAI function calling vs tool use",
        "Memory-efficient transformer architectures",
        "Real-time data processing pipelines",
    ]

    results = {"model": model_name, "test_count": len(test_strings)}

    for name in [model_name, "nomic-embed-text"]:
        start = time.time()
        success_count = 0
        for s in test_strings:
            try:
                proc = run_cmd(
                    ["ollama", "run", name, f"Embed: {s}"],
                    timeout=30,
                )
                if proc.returncode == 0:
                    success_count += 1
            except Exception:
                pass
        elapsed = time.time() - start
        results[name] = {
            "total_time_s": round(elapsed, 2),
            "avg_time_s": round(elapsed / len(test_strings), 3),
            "success_count": success_count,
        }

    new_avg = results.get(model_name, {}).get("avg_time_s", 999)
    baseline_avg = results.get("nomic-embed-text", {}).get("avg_time_s", 999)
    results["faster_than_baseline"] = new_avg < baseline_avg
    results["speedup_ratio"] = round(baseline_avg / new_avg, 2) if new_avg > 0 else 0

    return results


def auto_pull_ollama_model(item: dict, dry_run: bool) -> Optional[Dict]:
    """Pull a new Ollama model and benchmark it."""
    model_name = detect_ollama_model(item)
    if not model_name:
        return None

    if len(model_name) < 2 or " " in model_name:
        return None

    result = {
        "type": "ollama_model_pull",
        "model": model_name,
        "item_id": item["id"],
        "timestamp": datetime.now(timezone.utc).isoformat(),
        "success": False,
    }

    if dry_run:
        result["success"] = True
        result["dry_run"] = True
        log.info("  → [DRY RUN] Would pull Ollama model: %s", model_name)
        log_auto_action("ollama_model_pull", item["id"], item.get("title", ""),
                        f"[DRY RUN] Would pull {model_name}", True)
        return result

    log.info("  → Pulling Ollama model: %s", model_name)
    try:
        proc = run_cmd(["ollama", "pull", model_name], timeout=300)
        if proc.returncode == 0:
            result["success"] = True
            result["pull_output"] = proc.stdout[-500:] if proc.stdout else ""
            log.info("  → Pulled Ollama model: %s", model_name)
        else:
            result["error"] = proc.stderr.strip()[:300]
            log.warning("  → Ollama pull failed for %s: %s", model_name, result["error"])
            log_auto_action("ollama_model_pull", item["id"], item.get("title", ""),
                            f"Pull failed: {result['error']}", False, result)
            append_json_log(MODEL_BENCHMARKS_FILE, result)
            return result
    except subprocess.TimeoutExpired:
        result["error"] = "timeout (300s)"
        log.warning("  → Ollama pull timed out for %s", model_name)
        log_auto_action("ollama_model_pull", item["id"], item.get("title", ""),
                        "Pull timed out", False, result)
        append_json_log(MODEL_BENCHMARKS_FILE, result)
        return result
    except Exception as e:
        result["error"] = str(e)
        log_auto_action("ollama_model_pull", item["id"], item.get("title", ""),
                        f"Pull error: {e}", False, result)
        append_json_log(MODEL_BENCHMARKS_FILE, result)
        return result

    # Benchmark if it's an embedding model
    is_embedding = any(kw in model_name.lower() for kw in EMBEDDING_KEYWORDS)
    if is_embedding:
        log.info("  → Benchmarking %s vs nomic-embed-text", model_name)
        benchmark = benchmark_embedding_model(model_name)
        if benchmark:
            result["benchmark"] = benchmark
            if benchmark.get("faster_than_baseline"):
                result["note"] = f"Faster than baseline ({benchmark['speedup_ratio']}x) — consider config update"
                log.info("  → %s is faster than nomic-embed-text (%sx)", model_name, benchmark["speedup_ratio"])
                # Config change is dangerous → request approval
                request_approval(
                    "model_config_update", item["id"], item.get("title", ""),
                    f"Model {model_name} benchmarked {benchmark['speedup_ratio']}x faster than nomic-embed-text. Update config?",
                    {"model": model_name, "benchmark": benchmark},
                )

    append_json_log(MODEL_BENCHMARKS_FILE, result)
    log_auto_action("ollama_model_pull", item["id"], item.get("title", ""),
                    f"Pulled and benchmarked {model_name}", True, result)
    return result


# ── v2: Memory Technique Extraction ───────────────────────────────────────────

TECHNIQUE_KEYWORDS = {"rag", "chunking", "embedding", "memory", "retrieval",
                      "prompt engineering", "prompt pattern", "vector search",
                      "context window", "reranking", "hyde", "hypothetical",
                      "semantic search", "chunk", "indexing strategy"}


def detect_technique(item: dict) -> bool:
    """Check if item is about a memory/RAG/prompting technique."""
    title = item.get("title", "").lower()
    tags = [t.lower() for t in item.get("classification", {}).get("tags", [])]
    reason = item.get("classification", {}).get("reason", "").lower()
    all_text = title + " " + " ".join(tags) + " " + reason

    return sum(1 for kw in TECHNIQUE_KEYWORDS if kw in all_text) >= 2


def extract_technique(item: dict, dry_run: bool) -> Optional[Dict]:
    """Extract a technique/pattern from an item and save it."""
    if not detect_technique(item):
        return None

    cls = item.get("classification", {})
    synthesis = item.get("synthesis", {})
    item_id = item["id"]

    technique_md = f"""# {item.get('title', 'Unknown Technique')}

**Date:** {TODAY}
**Source:** {item.get('source', 'unknown')}
**URL:** {item.get('url', 'N/A')}
**Relevance:** {cls.get('relevance_score', '?')}/10
**Tags:** {', '.join(cls.get('tags', []))}

## Key Technique
{cls.get('reason', 'No description available.')}

"""
    if synthesis:
        technique_md += f"""## Why It Matters
{synthesis.get('why_it_matters', 'N/A')}

## Recommended Action
{synthesis.get('action', 'N/A')}

## Headline
{synthesis.get('headline', 'N/A')}
"""

    if not dry_run:
        out = TECHNIQUES_DIR / f"{TODAY}-{item_id}.md"
        out.write_text(technique_md)

    queue_entry = {
        "id": item_id,
        "title": item.get("title", ""),
        "url": item.get("url", ""),
        "technique_file": f"{TODAY}-{item_id}.md",
        "priority": cls.get("relevance_score", 5),
        "tags": cls.get("tags", []),
        "added_at": datetime.now(timezone.utc).isoformat(),
        "status": "pending",
    }
    if not dry_run:
        append_json_log(IMPROVEMENTS_QUEUE_FILE, queue_entry)

    log.info("  → Technique extracted: %s", item.get("title", ""))
    log_auto_action("technique_extraction", item_id, item.get("title", ""),
                    f"Saved technique to techniques/{TODAY}-{item_id}.md", True)
    return queue_entry


# ── v2: Breaking Change Detection ─────────────────────────────────────────────

BREAKING_KEYWORDS = {"deprecat", "breaking change", "breaking", "removed", "sunset",
                     "end of life", "eol", "discontinued", "migration required"}


def detect_breaking_change(item: dict) -> Optional[str]:
    """Check if item mentions a breaking change for tools we use. Returns affected tool or None."""
    title = item.get("title", "").lower()
    tags = [t.lower() for t in item.get("classification", {}).get("tags", [])]
    reason = item.get("classification", {}).get("reason", "").lower()
    all_text = title + " " + " ".join(tags) + " " + reason

    has_breaking = any(kw in all_text for kw in BREAKING_KEYWORDS)
    if not has_breaking:
        return None

    for tool in OUR_TOOLS:
        if tool in all_text:
            return tool

    return None


def check_breaking_change(item: dict, dry_run: bool) -> Optional[Dict]:
    """Detect breaking changes and check which projects are affected."""
    affected_tool = detect_breaking_change(item)
    if not affected_tool:
        return None

    cls = item.get("classification", {})
    item_id = item["id"]

    # Scan projects for usage of the affected tool
    affected_projects = []
    if PROJECTS_DIR.exists():
        for project_dir in PROJECTS_DIR.iterdir():
            if not project_dir.is_dir():
                continue
            for pattern in ["*.py", "*.js", "*.ts", "*.json", "*.yaml", "*.yml", "*.toml"]:
                for f in project_dir.rglob(pattern):
                    try:
                        if affected_tool in f.read_text().lower():
                            affected_projects.append({
                                "project": project_dir.name,
                                "file": str(f.relative_to(PROJECTS_DIR)),
                            })
                            break
                    except Exception:
                        continue

    alert = {
        "id": item_id,
        "title": item.get("title", ""),
        "url": item.get("url", ""),
        "affected_tool": affected_tool,
        "affected_projects": affected_projects,
        "reason": cls.get("reason", ""),
        "tags": cls.get("tags", []),
        "detected_at": datetime.now(timezone.utc).isoformat(),
    }

    if not dry_run:
        append_json_log(BREAKING_CHANGES_FILE, alert)

    if affected_projects:
        log.warning("  → BREAKING CHANGE for '%s' — %d projects affected: %s",
                    affected_tool, len(affected_projects),
                    ", ".join(p["project"] for p in affected_projects[:5]))
    else:
        log.info("  → Breaking change detected for '%s' (no local projects affected)", affected_tool)

    log_auto_action("breaking_change_detection", item_id, item.get("title", ""),
                    f"Breaking change in {affected_tool}, {len(affected_projects)} projects affected",
                    True, alert)
    return alert


# ── Skills Evaluation (existing, kept) ────────────────────────────────────────

def evaluate_for_skill_install(item: dict, dry_run: bool) -> Optional[Dict]:
    """Check if a GitHub repo should be evaluated as a Claude Code skill."""
    url = item.get("url", "")
    if "github.com" not in url:
        return None

    title = item.get("title", "").lower()
    tags = [t.lower() for t in item.get("classification", {}).get("tags", [])]
    stars = 0

    raw_score = item.get("raw_score", 0)
    if isinstance(raw_score, (int, float)):
        stars = int(raw_score)

    name_match = "skill" in title or "skills" in title
    tag_match = "claude-code" in tags or "claude-skills" in tags

    should_evaluate = (name_match and stars >= 100) or tag_match

    if not should_evaluate:
        return None

    entry = {
        "id": item["id"],
        "title": item.get("title", ""),
        "url": url,
        "stars": stars,
        "match_reason": [],
        "tags": tags,
        "evaluated_at": datetime.now(timezone.utc).isoformat(),
        "status": "pending_review",
    }
    if name_match and stars >= 100:
        entry["match_reason"].append(f"name contains 'skill' with {stars}+ stars")
    if tag_match:
        entry["match_reason"].append("tagged claude-code or claude-skills")

    if not dry_run:
        existing = []
        if SKILLS_EVALUATED_FILE.exists():
            try:
                existing = json.loads(SKILLS_EVALUATED_FILE.read_text())
            except Exception:
                pass
        existing_ids = {e["id"] for e in existing}
        if item["id"] not in existing_ids:
            existing.append(entry)
            SKILLS_EVALUATED_FILE.write_text(json.dumps(existing, indent=2) + "\n")

    log.info("  → Skill candidate: %s (%s)", item["title"], ", ".join(entry["match_reason"]))
    return entry


def write_urgent_json(item: dict) -> None:
    """Write act_now item to urgent.json for Telegram notification pickup."""
    cls = item.get("classification", {})
    synthesis = item.get("synthesis", {})
    entry = {
        "id": item["id"],
        "title": item.get("title", ""),
        "url": item.get("url", ""),
        "source": item.get("source", ""),
        "relevance_score": cls.get("relevance_score", 0),
        "actionability": cls.get("actionability", ""),
        "headline": (synthesis or {}).get("headline", ""),
        "action": (synthesis or {}).get("action", ""),
        "timestamp": datetime.now(timezone.utc).isoformat(),
    }
    try:
        existing = []
        if URGENT_FILE.exists():
            try:
                existing = json.loads(URGENT_FILE.read_text())
            except Exception:
                pass
        existing.append(entry)
        existing = existing[-50:]
        URGENT_FILE.write_text(json.dumps(existing, indent=2) + "\n")
        log.info("  → Written to urgent.json for Telegram pickup")
    except Exception as e:
        log.warning("  → Failed to write urgent.json: %s", e)


# ── Action Handlers ────────────────────────────────────────────────────────────

def handle_act_now(item: dict, dry_run: bool) -> dict:
    """Process an act_now item. Returns action record."""
    cls = item["classification"]
    item_id = item["id"]
    tags = cls.get("tags", [])
    category = cls.get("category", "")
    threat_opp = cls.get("threat_opportunity", "")
    action_taken = []

    # MCP tooling → install recommendation
    if category == "tooling" and "mcp" in [t.lower() for t in tags]:
        rec = {
            "id": item_id,
            "title": item["title"],
            "url": item.get("url", ""),
            "category": "mcp_tooling",
            "recommendation": "evaluate_for_install",
            "reason": cls.get("reason", ""),
            "tags": tags,
            "created_at": datetime.now(timezone.utc).isoformat(),
        }
        if not dry_run:
            content = fetch_url(item.get("url", ""))
            if content:
                rec["fetched_summary"] = extract_text_summary(content, 500)
            out = PENDING_DIR / f"{item_id}.json"
            out.write_text(json.dumps(rec, indent=2) + "\n")
        action_taken.append("install_recommendation")
        log.info("  → Install recommendation: %s", item["title"])

    # Competitive threat → threat brief
    if category == "competitive" or threat_opp == "threat":
        brief = f"""# Threat Brief: {item['title']}

**Date:** {TODAY}
**Source:** {item.get('source', 'unknown')}
**URL:** {item.get('url', 'N/A')}
**Relevance:** {cls.get('relevance_score', '?')}/10
**Time Sensitivity:** {cls.get('time_sensitivity', 'unknown')}

## Classification
- Category: {category}
- Tags: {', '.join(tags)}
- Threat/Opportunity: {threat_opp}

## Analysis
{cls.get('reason', 'No analysis available.')}

## Synthesis
"""
        if item.get("synthesis"):
            s = item["synthesis"]
            brief += f"""- **Headline:** {s.get('headline', 'N/A')}
- **Why it matters:** {s.get('why_it_matters', 'N/A')}
- **Action:** {s.get('action', 'N/A')}
- **Confidence:** {s.get('confidence', 'N/A')}
"""
        else:
            brief += "No synthesis available (Pass 2 not run).\n"

        if not dry_run:
            out = THREATS_DIR / f"{TODAY}-{item_id}.md"
            out.write_text(brief)
        action_taken.append("threat_brief")
        log.info("  → Threat brief: %s", item["title"])

    # Security/vulnerability → dependency check
    if "security" in [t.lower() for t in tags] or "vulnerability" in [t.lower() for t in tags]:
        findings = find_affected_deps(tags, item["title"])
        alert = {
            "id": item_id,
            "title": item["title"],
            "url": item.get("url", ""),
            "tags": tags,
            "reason": cls.get("reason", ""),
            "affected_deps": findings,
            "checked_at": datetime.now(timezone.utc).isoformat(),
        }
        if not dry_run:
            out = ALERTS_DIR / f"{item_id}.json"
            out.write_text(json.dumps(alert, indent=2) + "\n")
        action_taken.append("security_alert")
        if findings:
            log.warning("  → SECURITY ALERT (deps affected): %s", item["title"])
        else:
            log.info("  → Security check (no local deps affected): %s", item["title"])

    if not action_taken:
        action_taken.append("logged_only")
        log.info("  → Act-now item logged (no specific handler): %s", item["title"])

    return {"actions": action_taken, "item_id": item_id}


def handle_evaluate(item: dict, dry_run: bool) -> dict:
    """Process an evaluate item. Fetch, summarize, extract metadata."""
    cls = item["classification"]
    item_id = item["id"]
    url = item.get("url", "")
    category = cls.get("category", "")

    summary_lines = [
        f"# {item['title']}",
        f"",
        f"**Date:** {TODAY}",
        f"**Source:** {item.get('source', 'unknown')}",
        f"**URL:** {url}",
        f"**Relevance:** {cls.get('relevance_score', '?')}/10",
        f"**Tags:** {', '.join(cls.get('tags', []))}",
        f"",
    ]

    github_meta = None
    if not dry_run and url:
        content = fetch_url(url)
        if content:
            text = extract_text_summary(content, 1000)
            sentences = [s.strip() for s in re.split(r'[.!?]+', text) if len(s.strip()) > 20]
            summary_text = ". ".join(sentences[:5]) + "." if sentences else text[:500]
            summary_lines.append("## Summary")
            summary_lines.append(summary_text)
            summary_lines.append("")

            if "github.com" in url:
                github_meta = extract_github_meta(content, url)
                if github_meta:
                    summary_lines.append("## GitHub Metadata")
                    for k, v in github_meta.items():
                        summary_lines.append(f"- **{k}:** {v}")
                    summary_lines.append("")
        else:
            summary_lines.append("*Failed to fetch URL content.*")
            summary_lines.append("")

    # Auto-install MCP servers: tooling + mcp tag + high relevance + GitHub URL
    mcp_install_result = None
    tags = cls.get("tags", [])
    tag_lower = [t.lower() for t in tags]
    relevance = cls.get("relevance_score", 0)
    if (category == "tooling"
            and ("mcp" in tag_lower or "MCP" in tags)
            and relevance >= 8
            and "github.com" in url):
        readme_url = re.sub(r'/?$', '', url) + "/raw/HEAD/README.md"
        readme_text = None if dry_run else fetch_url(readme_url)
        if not readme_text and not dry_run:
            readme_url_alt = re.sub(r'/?$', '', url) + "/raw/main/README.md"
            readme_text = fetch_url(readme_url_alt)
        if readme_text or dry_run:
            install_info = extract_mcp_install_info(readme_text or "", url)
            if install_info:
                mcp_install_result = auto_install_mcp_server(install_info, dry_run)
                summary_lines.append("## MCP Auto-Install")
                summary_lines.append(f"- **Server:** {install_info['server_name']}")
                summary_lines.append(f"- **Package:** {install_info['package_name']}")
                summary_lines.append(f"- **Success:** {mcp_install_result.get('success', False)}")
                if mcp_install_result.get("error"):
                    summary_lines.append(f"- **Error:** {mcp_install_result['error']}")
                summary_lines.append("")

    summary_lines.append("## Key Takeaway")
    summary_lines.append(cls.get("reason", "No analysis available."))
    summary_lines.append("")

    if item.get("synthesis"):
        s = item["synthesis"]
        summary_lines.append("## Synthesis")
        summary_lines.append(f"- **Headline:** {s.get('headline', 'N/A')}")
        summary_lines.append(f"- **Why it matters:** {s.get('why_it_matters', 'N/A')}")
        summary_lines.append(f"- **Action:** {s.get('action', 'N/A')}")
        summary_lines.append("")

    if not dry_run:
        out = EVALUATIONS_DIR / f"{TODAY}-{item_id}.md"
        out.write_text("\n".join(summary_lines))

    actions = ["evaluation_written"]
    if mcp_install_result:
        actions.append("mcp_auto_installed" if mcp_install_result.get("success") else "mcp_install_failed")

    log.info("  → Evaluation: %s", item["title"])
    return {"actions": actions, "item_id": item_id, "github_meta": github_meta}


def handle_monitor(item: dict, dry_run: bool) -> dict:
    """Log a monitor item to monitored.jsonl."""
    cls = item["classification"]
    entry = {
        "id": item["id"],
        "title": item["title"],
        "url": item.get("url", ""),
        "date": TODAY,
        "relevance_score": cls.get("relevance_score", 0),
    }
    if not dry_run:
        with open(MONITORED_FILE, "a") as f:
            f.write(json.dumps(entry) + "\n")
    log.info("  → Monitored: %s", item["title"])
    return {"actions": ["monitored"], "item_id": item["id"]}


# ── Daily Brief ────────────────────────────────────────────────────────────────

def write_daily_brief(act_now_items: List[Dict]):
    """Write a daily brief of act_now items for the main agent."""
    if not act_now_items:
        return

    lines = [
        f"# Intelligence Brief — {TODAY}",
        "",
        f"**{len(act_now_items)} act-now items processed.**",
        "",
    ]
    for item in act_now_items:
        cls = item.get("classification", {})
        lines.append(f"### {item['title']}")
        lines.append(f"- **Category:** {cls.get('category', '?')}")
        lines.append(f"- **Relevance:** {cls.get('relevance_score', '?')}/10")
        lines.append(f"- **Threat/Opportunity:** {cls.get('threat_opportunity', 'N/A')}")
        lines.append(f"- **URL:** {item.get('url', 'N/A')}")
        lines.append(f"- **Reason:** {cls.get('reason', 'N/A')}")
        if item.get("synthesis"):
            s = item["synthesis"]
            lines.append(f"- **Action:** {s.get('action', 'N/A')}")
        lines.append("")

    out = DAILY_DIR / f"{TODAY}.md"
    out.write_text("\n".join(lines))
    log.info("Daily brief written to %s", out)


# ── v2: Improvements Log ──────────────────────────────────────────────────────

def write_improvement_line(summary: str) -> None:
    """Append a 1-line 'what I improved today' to improvements.md."""
    line = f"- **{TODAY}:** {summary}\n"
    if IMPROVEMENTS_LOG.exists():
        content = IMPROVEMENTS_LOG.read_text()
    else:
        content = "# Intelligence Self-Improvement Log\n\n"
    content += line
    IMPROVEMENTS_LOG.write_text(content)


# ── Auto-discover Bluesky accounts ────────────────────────────────────────────

def auto_discover_bluesky_account(item: dict, dry_run: bool) -> Optional[str]:
    """If a Bluesky post scores 8+, add unseen authors to config.yaml."""
    if item.get("source") != "bluesky":
        return None
    cls = item.get("classification", {})
    relevance = cls.get("relevance_score", 0)
    if relevance < 8:
        return None
    author = (item.get("author") or "").strip().lower()
    if not author:
        return None

    try:
        with open(CONFIG_FILE) as f:
            config = yaml.safe_load(f) or {}
        sources_cfg = config.setdefault("sources", {})
        bluesky_cfg = sources_cfg.setdefault("bluesky", {})
        accounts = bluesky_cfg.setdefault("accounts", [])
        normalized_accounts = {str(account).strip().lower() for account in accounts}
        if author in normalized_accounts:
            return None

        log.info(f"  → Auto-discovering Bluesky account: @{author} (relevance={relevance})")

        if not dry_run:
            accounts.append(author)
            bluesky_cfg["accounts"] = accounts
            with open(CONFIG_FILE, "w") as f:
                yaml.safe_dump(config, f, default_flow_style=False, sort_keys=False)

            append_json_log(ACCOUNTS_ADDED_FILE, {
                "account": author,
                "reason": f"Post scored {relevance}/10",
                "item_id": item.get("id"),
                "item_title": item.get("title", "")[:100],
                "url": item.get("url", ""),
                "added_at": datetime.now(timezone.utc).isoformat(),
            })
        return author
    except Exception as e:
        log.warning(f"  → Failed to auto-discover Bluesky account: {e}")
    return None


# ── Auto-discover keywords ───────────────────────────────────────────────────

def track_tags_and_discover_keywords(items: list, dry_run: bool) -> list[str]:
    """Track tag frequency across items. If a new tag appears 3+ times in one
    sweep and isn't in keyword_weights, auto-add it with weight 1."""
    tag_freq: dict[str, int] = {}
    if TAG_FREQUENCY_FILE.exists():
        try:
            tag_freq = json.loads(TAG_FREQUENCY_FILE.read_text())
        except Exception:
            pass

    sweep_tags: dict[str, int] = {}
    for item in items:
        cls = item.get("classification", {})
        for tag in cls.get("tags", []):
            tag_lower = str(tag).lower().strip()
            if tag_lower:
                sweep_tags[tag_lower] = sweep_tags.get(tag_lower, 0) + 1

    for tag, count in sweep_tags.items():
        tag_freq[tag] = tag_freq.get(tag, 0) + count

    if not dry_run:
        Path(TAG_FREQUENCY_FILE).parent.mkdir(parents=True, exist_ok=True)
        TAG_FREQUENCY_FILE.write_text(json.dumps(tag_freq, indent=2) + "\n")

    try:
        with open(CONFIG_FILE) as f:
            config = yaml.safe_load(f) or {}
        scoring_cfg = config.setdefault("scoring", {})
        keyword_weights = scoring_cfg.setdefault("keyword_weights", {})
        existing_kw = {k.lower() for k in keyword_weights}

        added = []
        for tag, count in sweep_tags.items():
            if count >= 3 and tag not in existing_kw and tag not in KEYWORD_STOPWORDS:
                keyword_weights[tag] = 1
                existing_kw.add(tag)
                added.append(tag)
                log.info(f"  → Auto-discovered keyword: '{tag}' (appeared {count}x in sweep)")

        if added and not dry_run:
            scoring_cfg["keyword_weights"] = keyword_weights
            with open(CONFIG_FILE, "w") as f:
                yaml.safe_dump(config, f, default_flow_style=False, sort_keys=False)

            for kw in added:
                append_json_log(KEYWORDS_ADDED_FILE, {
                    "keyword": kw,
                    "sweep_count": sweep_tags[kw],
                    "added_at": datetime.now(timezone.utc).isoformat(),
                })
        return added
    except Exception as e:
        log.warning(f"  → Failed to auto-discover keywords: {e}")
    return []


# ── Main ───────────────────────────────────────────────────────────────────────

def main():
    parser = argparse.ArgumentParser(description="OpenClaw Intelligence Action Layer v2")
    parser.add_argument("--dry-run", action="store_true",
                        help="Show what actions would be taken without writing files or fetching URLs")
    args = parser.parse_args()

    if args.dry_run:
        log.info("=== DRY RUN — no files will be written, no URLs fetched ===")

    ensure_dirs()

    processed = load_processed()
    items = load_items()
    log.info("Loaded %d classified items (%d already processed)", len(items), len(processed))

    # Filter to unprocessed items with a classification
    pending = [i for i in items if i["id"] not in processed and i.get("classification")]
    if not pending:
        log.info("No new items to process.")
        if not args.dry_run:
            LAST_RUN_FILE.write_text(json.dumps({
                "timestamp": datetime.now(timezone.utc).isoformat(),
                "items_checked": len(items),
                "items_processed": 0,
                "actions": {},
                "errors": [],
            }, indent=2) + "\n")
        return

    log.info("Processing %d new items", len(pending))

    # Counters
    counts = {"act_now": 0, "evaluate": 0, "monitor": 0, "skipped": 0}
    v2_counts = {"skills_installed": 0, "models_pulled": 0,
                 "techniques_extracted": 0, "breaking_changes": 0}
    errors = []
    act_now_items = []
    improvements_today = []

    for item in pending:
        cls = item["classification"]
        actionability = cls.get("actionability", "none")
        item_id = item["id"]

        try:
            if actionability == "act_now":
                log.info("[ACT NOW] %s", item["title"])
                handle_act_now(item, args.dry_run)
                counts["act_now"] += 1
                act_now_items.append(item)
                if not args.dry_run:
                    write_urgent_json(item)

            elif actionability == "evaluate":
                log.info("[EVALUATE] %s", item["title"])
                handle_evaluate(item, args.dry_run)
                counts["evaluate"] += 1

            elif actionability == "monitor":
                log.info("[MONITOR] %s", item["title"])
                handle_monitor(item, args.dry_run)
                counts["monitor"] += 1

            else:
                counts["skipped"] += 1
                continue

            # ── v2 autonomous actions (run on every non-skipped item) ─────

            # Auto-install Claude Code skills
            skill_result = auto_install_claude_skill(item, args.dry_run)
            if skill_result and skill_result.get("success"):
                v2_counts["skills_installed"] += 1
                improvements_today.append(f"Installed Claude skill: {skill_result.get('repo', '?')}")

            # Auto-install OpenClaw skills
            oc_result = auto_install_openclaw_skill(item, args.dry_run)
            if oc_result and oc_result.get("success"):
                v2_counts["skills_installed"] += 1
                improvements_today.append(f"Installed OpenClaw skill: {oc_result.get('repo', '?')}")

            # Auto-pull Ollama models
            model_result = auto_pull_ollama_model(item, args.dry_run)
            if model_result and model_result.get("success"):
                v2_counts["models_pulled"] += 1
                improvements_today.append(f"Pulled model: {model_result.get('model', '?')}")

            # Extract memory techniques
            tech_result = extract_technique(item, args.dry_run)
            if tech_result:
                v2_counts["techniques_extracted"] += 1
                improvements_today.append(f"Extracted technique: {tech_result.get('title', '?')[:60]}")

            # Breaking change detection
            breaking_result = check_breaking_change(item, args.dry_run)
            if breaking_result:
                v2_counts["breaking_changes"] += 1
                improvements_today.append(
                    f"Breaking change alert: {breaking_result.get('affected_tool', '?')}")

            # Skills evaluation (existing v1)
            evaluate_for_skill_install(item, args.dry_run)

            # Auto-discover Bluesky accounts
            auto_discover_bluesky_account(item, args.dry_run)

            # Mark as processed
            if not args.dry_run:
                processed[item_id] = datetime.now(timezone.utc).isoformat()

        except Exception as e:
            log.error("Error processing %s: %s", item_id, e)
            errors.append({"item_id": item_id, "error": str(e)})

    # Auto-discover keywords from tag frequency across this sweep
    classified_pending = [i for i in pending if i.get("classification")]
    if classified_pending:
        track_tags_and_discover_keywords(classified_pending, args.dry_run)

    # Write daily brief for act_now items
    if act_now_items and not args.dry_run:
        write_daily_brief(act_now_items)

    # Write improvement log
    if improvements_today and not args.dry_run:
        summary = "; ".join(improvements_today[:5])
        if len(improvements_today) > 5:
            summary += f" (+{len(improvements_today) - 5} more)"
        write_improvement_line(summary)

    # Save processed state
    if not args.dry_run:
        save_processed(processed)

    # Write run summary
    summary = {
        "timestamp": datetime.now(timezone.utc).isoformat(),
        "items_checked": len(items),
        "items_processed": counts["act_now"] + counts["evaluate"] + counts["monitor"],
        "actions": counts,
        "v2_actions": v2_counts,
        "errors": errors,
    }
    if not args.dry_run:
        LAST_RUN_FILE.write_text(json.dumps(summary, indent=2) + "\n")

    log.info("Done — act_now: %d, evaluate: %d, monitor: %d, skipped: %d, errors: %d",
             counts["act_now"], counts["evaluate"], counts["monitor"],
             counts["skipped"], len(errors))
    if any(v for v in v2_counts.values()):
        log.info("v2 actions — skills: %d, models: %d, techniques: %d, breaking: %d",
                 v2_counts["skills_installed"], v2_counts["models_pulled"],
                 v2_counts["techniques_extracted"], v2_counts["breaking_changes"])


if __name__ == "__main__":
    main()
