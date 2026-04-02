#!/bin/bash
# Dashboard data refresh script
# Runs every 15 minutes to update CEO monitoring dashboard

set -e

WORKSPACE_ROOT="$HOME/.openclaw/workspace"
DASHBOARD_PROJECT="$HOME/Projects/bigcohen-dashboard"
cd "$WORKSPACE_ROOT"

echo "[$(date -Iseconds)] Starting dashboard refresh..."

# Generate fresh data
bash scripts/generate-dashboard-data.sh

# Copy to dashboard project
cp data/dashboard-data.json "$DASHBOARD_PROJECT/data.json"

# Deploy to Cloudflare Pages
cd "$DASHBOARD_PROJECT"
npx wrangler pages deploy . --project-name=bigcohen-dashboard

echo "[$(date -Iseconds)] Dashboard refresh complete"
