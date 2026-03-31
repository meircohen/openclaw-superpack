# OpenClaw Intelligence Module

Automated intelligence pipeline that monitors AI/agent/MCP ecosystem signals and surfaces actionable insights.

## Pipeline Overview

```
collector.py --> filter.py --> act.py --> digest.py
                                  |
                              trends.py
                                  |
                              review.py (manual calibration)
```

### 1. Collector (`collector.py`)

Pulls signals from multiple sources on a configurable schedule:

- **Hacker News** (Algolia API) -- top stories matching AI/agent keywords
- **RSS feeds** -- Simon Willison's blog, arXiv (cs.MA, cs.AI), awesome-mcp-servers
- **GitHub Trending** -- Python repos, star velocity detection
- **Reddit** -- r/LocalLLaMA, r/ClaudeAI, r/MachineLearning (JSON API with RSS fallback)
- **Bluesky** -- posts from curated AI researcher accounts
- **Package registries** -- npm MCP packages, PyPI AI-related updates
- **Product Hunt** -- AI/agent product launches
- **GitHub Releases** -- tracked repos (Anthropic SDK, Ollama, MCP servers, etc.)

Each item is deduplicated (URL hash + optional semantic embedding dedup), keyword-scored, and saved to `items/`.

### 2. Filter (`filter.py`)

Two-pass LLM classification using local Ollama:

- **Pass 1** (cheap): Classifies every unprocessed item -- relevance score (0-10), actionability (none/monitor/evaluate/act_now), category, tags, threat/opportunity assessment
- **Pass 2** (expensive): Full synthesis only for high-signal items (relevance >= 7, OpenClaw-relevant, or act_now) -- generates headline, why-it-matters, recommended action
- **Cross-source amplification**: Items appearing from multiple sources get a relevance boost

Token usage is tracked and capped per run.

### 3. Act (`act.py`)

Autonomous action layer that processes classified items:

- **act_now**: MCP server install recommendations, threat briefs, security dependency checks, urgent notification via Telegram
- **evaluate**: Fetches URL content, extracts GitHub metadata, auto-installs high-relevance MCP servers
- **monitor**: Logs to monitored.jsonl for trend tracking
- **Auto-discovery**: Adds high-signal Bluesky accounts and trending keywords to config
- **Skill installation**: Detects and installs Claude Code skills and OpenClaw skills from GitHub
- **Model management**: Auto-pulls new Ollama models, benchmarks embedding models against baseline
- **Technique extraction**: Saves RAG/memory/prompting techniques to the knowledge base
- **Breaking change detection**: Scans local projects for affected dependencies

Dangerous actions (config changes, model swaps) go to `pending_approval.json` instead of auto-executing.

### 4. Digest (`digest.py`)

Generates readable markdown digests:

- Daily digest sorted by priority (act_now > evaluate > monitor)
- Weekly memory entry injected into MEMORY.md (concept-first format for semantic retrieval)
- Daily learnings appended to the knowledge base

### 5. Trends (`trends.py`)

Weekly topic frequency analysis:

- Compares this week's tag distribution against last week
- Reports rising, falling, and newly-emerged topics
- Tracks sentiment shifts (threat vs. opportunity) per topic
- Writes compact summaries to memory for long-term pattern tracking

### 6. Review (`review.py`)

Manual calibration CLI for tuning filter thresholds:

- Interactive review: rate items as useful/not useful
- Statistics dashboard: per-source signal rates, relevance score accuracy
- Threshold recommendations based on human ratings
- Run after 3 days of collection to empirically calibrate the pipeline

## Configuration

Edit `config.yaml` to:

- Enable/disable sources
- Adjust keyword weights and scoring thresholds
- Configure LLM models and token budgets
- Set collection intervals

## Setup

```bash
bash init.sh
```

This installs Python dependencies, configures the launchd job for automatic collection every 6 hours, and runs a dry-run test.

## Directory Structure

```
intelligence/
  collector.py      # Source collection
  filter.py         # LLM classification
  act.py            # Autonomous actions
  digest.py         # Digest generation
  trends.py         # Trend analysis
  review.py         # Manual calibration
  config.yaml       # Pipeline configuration
  init.sh           # One-command setup
  hot.json          # Current high-signal items
  seen.json         # Deduplication state
  usage.json        # LLM token usage tracking
  status.json       # Source health status
  items/            # Individual item JSON files
  actions/          # Action logs and pending approvals
  trends/           # Weekly trend reports
  raw/              # Raw daily JSONL archives
```
