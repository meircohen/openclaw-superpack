---
name: backup
description: Backup and restore openclaw configuration, skills, commands, and settings. Sync across devices, version control with git, automate backups, and migrate to new machines. Includes HTTP server for browser-based backup management.
metadata: {"openclaw":{"emoji":"💾","requires":{"bins":["git","tar","rsync","node","python3"],"env":[]},"trust":"high","permissions":["read:~/.openclaw","write:~/.openclaw","network:listen"]}}
---

# OpenClaw Backup & Restore

Complete backup/restore system for OpenClaw with HTTP server for migrations.

## ⚠️ Security Model

This skill handles **highly sensitive data**: bot tokens, API keys, channel credentials, session history.

**Access control:**
- `backup.sh` — reads ~/.openclaw/, writes chmod 600 archive to disk (no network)
- `restore.sh` — overwrites ~/.openclaw/ from archive (requires typing `yes`, always run `--dry-run` first)
- `serve.sh` + `server.js` — HTTP server, **token mandatory** (refuses to start without one)
  - Shell execution endpoints (`/backup`, `/restore`) are **localhost-only**
  - Remote access can only download/upload files, not trigger execution

## Scripts

| Script | Purpose |
|---|---|
| `scripts/backup.sh [output-dir]` | Create backup (default: /tmp/openclaw-backups/) |
| `scripts/restore.sh <archive> [--dry-run] [--overwrite-gateway-token]` | Restore — **always dry-run first** |
| `scripts/serve.sh start --token TOKEN [--port 7373]` | Start HTTP server — **token required** |
| `scripts/serve.sh stop\|status` | Stop/check server |
| `scripts/schedule.sh [--interval daily\|weekly\|hourly]` | System cron scheduling |

**Gateway token behavior:** By default, `restore.sh` preserves the new server's `gateway.auth.token` after restoring `openclaw.json`. This prevents "gateway token mismatch" errors after migration. Use `--overwrite-gateway-token` only for full disaster recovery on the same server.

## What Gets Backed Up

**Includes:** workspace (MEMORY.md, skills, agent files), openclaw.json (bot tokens + API keys), credentials, channel pairing state, agent config + session history, devices, identity, cron jobs, guardian scripts.

**Excludes:** logs, binary media, node_modules, canvas system files.

See `references/what-gets-saved.md` for full details.

## Common Workflows

### Create backup

```bash
bash scripts/backup.sh /tmp/openclaw-backups
# → /tmp/openclaw-backups/openclaw-backup_TIMESTAMP.tar.gz (chmod 600)
```

### Restore — always dry-run first

```bash
# Step 1: preview what will change
bash scripts/restore.sh openclaw-backup_TIMESTAMP.tar.gz --dry-run

# Step 2: review the output, then apply
bash scripts/restore.sh openclaw-backup_TIMESTAMP.tar.gz
```

The restore script saves a pre-restore snapshot before overwriting anything.

### HTTP server — token is mandatory

```bash
# Token is required — server refuses to start without one
bash scripts/serve.sh start --token $(openssl rand -hex 16) --port 7373
# → http://localhost:7373/?token=<generated-token>
```

**Never share the URL on a public network without a reverse proxy + TLS.**

Web UI provides: create backup, download .tar.gz, upload, dry-run preview, restore.

**HTTP API (all require token except /health):**
- `GET  /health`              — Health check (unauthenticated, read-only)
- `GET  /backups`             — List backups
- `POST /backup`              — Create backup
- `GET  /download/:filename`  — Download archive
- `POST /upload`              — Upload archive (multipart, field: `backup`)
- `POST /restore/:filename`   — Restore; add `?dry_run=1` to preview

### Migrate to a new instance

**Old machine:**
```bash
bash scripts/serve.sh start --token MYTOKEN --port 7373
```

**New machine (after installing OpenClaw):**
```bash
# Download
curl -O "http://OLD_IP:7373/download/openclaw-backup_TIMESTAMP.tar.gz?token=MYTOKEN"

# Always dry-run first
bash scripts/restore.sh openclaw-backup_TIMESTAMP.tar.gz --dry-run

# Apply
bash scripts/restore.sh openclaw-backup_TIMESTAMP.tar.gz
# All channels reconnect automatically — no re-pairing needed
```

### Schedule daily auto-backup (OpenClaw cron)

```json
{
  "name": "daily-openclaw-backup",
  "schedule": { "kind": "cron", "expr": "0 3 * * *", "tz": "America/New_York" },
  "payload": {
    "kind": "agentTurn",
    "message": "Run a backup using the backup skill. Output dir: /tmp/openclaw-backups",
    "timeoutSeconds": 120
  },
  "sessionTarget": "isolated",
  "delivery": { "mode": "announce", "channel": "telegram", "to": "-1003846443358" }
}
```

## Post-Restore: Automatic Recovery Report

After `restore.sh` completes, it writes `workspace/.restore-complete.json`. On the next heartbeat/startup, the Agent should:

1. Check if `workspace/.restore-complete.json` exists
2. If yes: read it, send a restore report to the user, then **delete the file** (one-shot)
3. **Send the report in the user's primary language** (read from `workspace/USER.md`)

Report format (adapt language from USER.md):
```
✅ Restore complete

📦 Backup: {backup_name}
🤖 Agent: {agent_name}
🕐 Restored at: {restored_at}
💾 Contents restored: workspace, config, credentials, history, cron...
```

## Dependencies

Requires: `node`, `rsync`, `tar`, `python3`, `openclaw` CLI (all standard on OpenClaw instances).

Check: `which node rsync tar python3 openclaw`
