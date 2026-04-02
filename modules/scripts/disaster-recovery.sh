#!/bin/bash
# disaster-recovery.sh — One-command OpenClaw restore
# Usage: curl -sL https://raw.githubusercontent.com/meircohen/openclaw-system/main/scripts/disaster-recovery.sh | bash
#
# What this does:
# 1. Installs OpenClaw
# 2. Downloads latest backup from Google Drive
# 3. Restores everything
# 4. Clones workspace
# 5. Starts the gateway
#
# Prerequisites: Node.js 22+, gog CLI (for Drive download), git

set -e

echo ""
echo "🦞 OpenClaw Disaster Recovery"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

# Colors
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

step() { echo -e "${GREEN}[Step $1/6]${NC} $2"; }
warn() { echo -e "${YELLOW}[!]${NC} $1"; }
fail() { echo -e "${RED}[✗]${NC} $1"; exit 1; }

# Check prerequisites
command -v node >/dev/null 2>&1 || fail "Node.js not found. Install: brew install node"
command -v git >/dev/null 2>&1 || fail "git not found. Install: xcode-select --install"

NODE_VERSION=$(node -v | sed 's/v//' | cut -d. -f1)
if [ "$NODE_VERSION" -lt 22 ]; then
  fail "Node.js 22+ required (found v$(node -v)). Run: nvm install 22"
fi

# Step 1: Install OpenClaw
step 1 "Installing OpenClaw..."
if command -v openclaw >/dev/null 2>&1; then
  echo "  OpenClaw already installed: $(openclaw --version 2>/dev/null || echo 'unknown version')"
  echo "  Updating to latest..."
  npm i -g openclaw@beta --no-fund --no-audit 2>&1 | tail -1
else
  npm i -g openclaw@beta --no-fund --no-audit 2>&1 | tail -1
fi
echo "  ✅ OpenClaw ready"

# Step 2: Download backup from Google Drive
step 2 "Downloading backup from Google Drive..."
BACKUP_DIR="$HOME/Desktop"
BACKUP_FILE="$BACKUP_DIR/openclaw-restore.tar.gz"
DRIVE_FILE_ID="1s2dQpB4D-BrFafq3s4JHWHMctPmECdcI"

if [ -f "$BACKUP_FILE" ]; then
  echo "  Backup already downloaded: $BACKUP_FILE"
else
  if command -v gog >/dev/null 2>&1; then
    gog drive download "$DRIVE_FILE_ID" --output "$BACKUP_FILE" 2>&1
  else
    warn "gog CLI not installed. Downloading via direct link..."
    # Fallback: use curl with Google Drive direct download
    curl -L "https://drive.google.com/uc?export=download&id=$DRIVE_FILE_ID" -o "$BACKUP_FILE" 2>&1
    if [ ! -s "$BACKUP_FILE" ]; then
      echo ""
      warn "Auto-download failed (file may be too large for direct link)."
      echo "  Manual download:"
      echo "  1. Go to: https://drive.google.com/file/d/$DRIVE_FILE_ID"
      echo "  2. Download to Desktop"
      echo "  3. Rename to: openclaw-restore.tar.gz"
      echo "  4. Re-run this script"
      exit 1
    fi
  fi
fi
echo "  ✅ Backup downloaded ($(du -h "$BACKUP_FILE" | cut -f1))"

# Step 3: Restore from backup
step 3 "Restoring from backup..."
if [ -d "$HOME/.openclaw/workspace" ]; then
  warn "Existing ~/.openclaw found. Backup will merge/overwrite."
  read -p "  Continue? (y/N) " -n 1 -r
  echo
  if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    echo "  Aborted."
    exit 1
  fi
fi

RESTORE_SCRIPT="$HOME/.openclaw/skills/backup/scripts/restore.sh"
if [ -f "$RESTORE_SCRIPT" ]; then
  bash "$RESTORE_SCRIPT" "$BACKUP_FILE"
else
  # If restore script doesn't exist yet, extract manually
  echo "  Extracting backup..."
  mkdir -p "$HOME/.openclaw"
  tar xzf "$BACKUP_FILE" -C "$HOME/.openclaw" 2>&1
fi
echo "  ✅ Restore complete"

# Step 4: Clone latest workspace from GitHub
step 4 "Pulling latest workspace from GitHub..."
if [ -d "$HOME/.openclaw/workspace/.git" ]; then
  cd "$HOME/.openclaw/workspace"
  git pull origin main 2>&1 | tail -3
else
  # Backup workspace before clone
  if [ -d "$HOME/.openclaw/workspace" ]; then
    mv "$HOME/.openclaw/workspace" "$HOME/.openclaw/workspace-backup-$(date +%s)"
  fi
  git clone https://github.com/meircohen/openclaw-system.git "$HOME/.openclaw/workspace" 2>&1
fi
echo "  ✅ Workspace synced"

# Step 5: Set permissions
step 5 "Setting permissions..."
chmod -R 700 "$HOME/.openclaw" 2>/dev/null
find "$HOME/.openclaw/workspace/scripts" -name "*.sh" -exec chmod +x {} \; 2>/dev/null
find "$HOME/.openclaw/workspace/scripts" -name "*.py" -exec chmod +x {} \; 2>/dev/null
echo "  ✅ Permissions set"

# Step 6: Start gateway
step 6 "Starting OpenClaw gateway..."
openclaw start 2>&1 || warn "Gateway start failed — may need manual channel re-auth"

echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "🦞 Recovery complete!"
echo ""
echo "Next steps:"
echo "  1. Check: openclaw doctor"
echo "  2. Verify Telegram: message the bot"
echo "  3. Verify Slack: check channel"
echo ""
echo "If channels need re-auth:"
echo "  openclaw channels login --channel telegram"
echo "  openclaw channels login --channel slack"
echo ""
echo "Backup source: Google Drive (uploaded $(date -r "$BACKUP_FILE" '+%Y-%m-%d %H:%M'))"
echo "Workspace source: github.com/meircohen/openclaw-system (commit $(cd "$HOME/.openclaw/workspace" && git rev-parse --short HEAD 2>/dev/null || echo 'unknown'))"
echo ""
