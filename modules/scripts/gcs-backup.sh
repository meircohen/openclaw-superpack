#!/bin/bash
# gcs-backup.sh — Local + Git backup
set -e

WORKSPACE="$HOME/.openclaw/workspace"
BACKUP_DIR="$HOME/.openclaw/workspace/backups"
DATE_STAMP=$(date '+%Y%m%d-%H%M%S')
BACKUP_FILE="$BACKUP_DIR/workspace-${DATE_STAMP}.tar.gz"

mkdir -p "$BACKUP_DIR"

# Git commit + push
cd "$WORKSPACE"
if [ -n "$(git status --porcelain 2>/dev/null)" ]; then
  git add -A 2>/dev/null
  git commit -m "Auto-backup ${DATE_STAMP}" 2>/dev/null || true
  git push origin main 2>/dev/null && echo "Git push: OK" || echo "Git push: FAILED"
else
  echo "Git: no changes"
fi

# Create tarball (exclude large dirs)
tar czf "$BACKUP_FILE" \
  --exclude='projects' \
  --exclude='agent-room-v2' \
  --exclude='temp_temple' \
  --exclude='MetaClaw' \
  --exclude='source' \
  --exclude='node_modules' \
  --exclude='.git' \
  --exclude='haggadah-production' \
  -C "$HOME/.openclaw" workspace/ 2>/dev/null

BACKUP_SIZE=$(du -h "$BACKUP_FILE" | cut -f1)
echo "Backup created: $BACKUP_FILE ($BACKUP_SIZE)"

# Rotate — keep last 7
cd "$BACKUP_DIR"
ls -t workspace-*.tar.gz 2>/dev/null | tail -n +8 | xargs rm -f 2>/dev/null
echo "Rotation done. Backups: $(ls workspace-*.tar.gz 2>/dev/null | wc -l)"
