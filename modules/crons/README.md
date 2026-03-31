# Cron Job Templates

These are templates for the automated background jobs that make OpenClaw truly autonomous.
After installing the superpack, your OpenClaw can set these up for you.

Just say: "Set up the [name] cron job" and it will configure it.

## Available Templates

| Cron | Schedule | What It Does |
|------|----------|-------------|
| heartbeat | Every 30 min | Health checks, handoff processing, memory maintenance |
| intelligence-sweep | Every 6 hours | Scans HN, GitHub, Reddit, Bluesky for AI news |
| x-queue-poster | 9am, 1pm, 6pm | Posts queued tweets at optimal times |
| email-watchdog | 8am daily | Scans inbox for priority emails, alerts you |
| btc-intelligence | 8am daily | Crypto market analysis, Fear/Greed index |
| provider-health | 9am daily | Tests all AI provider APIs for degradation |
| auto-heal | 8am, 8pm | Detects and fixes common system issues |
| nightly-backup | 3am daily | Backs up configs, memory, and workspace |
| memory-maintenance | 8:30am daily | Reviews notes, updates memory blocks, consolidates |
| weekly-pattern-recognition | Monday 9am | Analyzes your sessions for recurring themes |
| model-health-check | Monday 10am | Tests all AI models in your registry |
