#!/bin/bash
# nightly-backup.sh — Automated nightly backup to Google Drive
# Runs via OpenClaw cron at 3 AM EDT
# Keeps last 7 backups, auto-rotates old ones

set -e

LOG_FILE="$HOME/.openclaw/workspace/memory/backup-log.md"
BACKUP_DIR="/tmp/openclaw-nightly-backup"
DRIVE_FOLDER_NAME="OpenClaw Backups"
MAX_BACKUPS=7

log() { echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1" >> "$LOG_FILE"; echo "$1"; }

mkdir -p "$BACKUP_DIR"

# Step 1: Git commit + push workspace
log "Starting nightly backup..."
cd "$HOME/.openclaw/workspace"
if [ -n "$(git status --porcelain 2>/dev/null)" ]; then
  git add -A 2>/dev/null
  git commit -m "Nightly auto-backup $(date '+%Y-%m-%d %H:%M')" 2>/dev/null || true
  git push origin main 2>/dev/null && log "Git push: OK" || log "Git push: FAILED (non-fatal)"
else
  log "Git: no changes to commit"
fi

# Step 2: Run full backup
BACKUP_SCRIPT="$HOME/.openclaw/skills/backup/scripts/backup.sh"
if [ ! -f "$BACKUP_SCRIPT" ]; then
  log "ERROR: backup script not found at $BACKUP_SCRIPT"
  exit 1
fi

bash "$BACKUP_SCRIPT" "$BACKUP_DIR" 2>&1
BACKUP_FILE=$(ls -t "$BACKUP_DIR"/openclaw-backup_*.tar.gz 2>/dev/null | head -1)

if [ -z "$BACKUP_FILE" ] || [ ! -f "$BACKUP_FILE" ]; then
  log "ERROR: backup file not created"
  exit 1
fi

BACKUP_SIZE=$(du -h "$BACKUP_FILE" | cut -f1)
log "Backup created: $(basename "$BACKUP_FILE") ($BACKUP_SIZE)"

# Step 3: Upload to Google Drive
DATE_STAMP=$(date '+%Y-%m-%d')
DRIVE_NAME="openclaw-backup-${DATE_STAMP}.tar.gz"

if command -v gog >/dev/null 2>&1; then
  UPLOAD_RESULT=$(gog drive upload "$BACKUP_FILE" --name "$DRIVE_NAME" 2>&1)
  if echo "$UPLOAD_RESULT" | grep -q "id"; then
    FILE_ID=$(echo "$UPLOAD_RESULT" | grep "^id" | awk '{print $2}')
    log "Drive upload: OK (id: $FILE_ID)"
  else
    log "Drive upload: FAILED — $UPLOAD_RESULT"
  fi
else
  log "WARNING: gog CLI not available, skipping Drive upload"
fi

# Step 4: Rotate old backups on Drive (keep last 7)
if command -v gog >/dev/null 2>&1; then
  # List all openclaw-backup files in Drive, sorted by date
  # BSD head doesn't support negative line counts; use awk to drop the last N lines
  OLD_BACKUPS=$(gog drive list --query "name contains 'openclaw-backup'" --sort "createdTime" 2>/dev/null | tail -n +2 | awk -v keep="$MAX_BACKUPS" '{lines[NR]=$0} END {for(i=1;i<=NR-keep;i++) print lines[i]}')
  
  if [ -n "$OLD_BACKUPS" ]; then
    DELETED=0
    while IFS=$'\t' read -r fid fname _rest; do
      if [ -n "$fid" ] && [ "$fid" != "id" ]; then
        gog drive delete "$fid" 2>/dev/null && DELETED=$((DELETED + 1)) || true
      fi
    done <<< "$OLD_BACKUPS"
    log "Rotation: deleted $DELETED old backup(s), keeping last $MAX_BACKUPS"
  else
    log "Rotation: nothing to delete (under $MAX_BACKUPS backups)"
  fi
fi

# Step 5: Cleanup local temp
rm -rf "$BACKUP_DIR"
log "Nightly backup complete: $DRIVE_NAME ($BACKUP_SIZE)"
log "---"
