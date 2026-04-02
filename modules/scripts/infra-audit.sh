#!/usr/bin/env bash
# Infrastructure Audit Script
# Purpose: Re-check infrastructure state and flag changes since last baseline
# Baseline: /Users/meircohen/.openclaw/workspace/config/infrastructure/infrastructure-state.md
# Usage: ./scripts/infra-audit.sh [--update-baseline]

set -euo pipefail

WORKSPACE="/Users/meircohen/.openclaw/workspace"
STATE_FILE="$WORKSPACE/config/infrastructure/infrastructure-state.md"
TEMP_STATE="/tmp/infra-audit-temp-$$.md"
DIFF_OUTPUT="/tmp/infra-audit-diff-$$.txt"

# Colors for output
RED='\033[0;31m'
YELLOW='\033[1;33m'
GREEN='\033[0;32m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "🔍 Infrastructure Audit"
echo "$(date '+%Y-%m-%d %H:%M:%S %Z')"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo

# Check if baseline exists
if [[ ! -f "$STATE_FILE" ]]; then
    echo -e "${RED}❌ Baseline state file not found: $STATE_FILE${NC}"
    echo "Run this script to create initial baseline."
    exit 1
fi

# Function to run command and handle errors gracefully
run_cmd() {
    "$@" 2>/dev/null || echo "[command unavailable or failed]"
}

# ============================================
# 1. COLLECT CURRENT STATE
# ============================================

echo "📊 Collecting current state..."

{
    echo "# Current Infrastructure Snapshot"
    echo "**Captured:** $(date '+%Y-%m-%d %H:%M:%S %Z')"
    echo
    
    # iMac Hardware
    echo "## iMac Hardware"
    /usr/sbin/system_profiler SPHardwareDataType 2>/dev/null | grep -E 'Chip:|Memory:' || echo "[hardware info unavailable]"
    df -h / | tail -1
    echo
    
    # Running Services
    echo "## Running Services"
    ps aux | grep -E 'openclaw|vault|cloudflared|pm2|oz-voice' | grep -v grep || echo "[no matching processes]"
    echo
    
    # LaunchAgents Status
    echo "## LaunchAgents"
    launchctl list | grep -E 'ai.openclaw.gateway|com.bigcohen|com.openclaw' || echo "[no agents loaded]"
    echo
    
    # Reb VM
    echo "## Reb VM"
    ssh -i ~/.ssh/id_ed25519 -o ConnectTimeout=5 meircohen@100.126.105.8 \
        'echo "=== System ===" && uname -a && echo "=== Disk ===" && df -h / && echo "=== Memory ===" && free -h && echo "=== Processes ===" && ps aux | grep -E "openclaw|gateway" | grep -v grep && echo "=== Uptime ===" && uptime' 2>&1 || echo "[Reb VM unreachable]"
    echo
    
    # Cloudflare Tunnels
    echo "## Cloudflare Tunnels"
    cloudflared tunnel list 2>/dev/null || echo "[cloudflared unavailable]"
    echo
    
    # DNS Resolution
    echo "## DNS"
    echo "bigcohen.org: $(dig +short bigcohen.org 2>/dev/null || echo '[dig unavailable]')"
    echo "aleph.bigcohen.org: $(dig +short aleph.bigcohen.org 2>/dev/null || echo '[dig unavailable]')"
    echo "voice.bigcohen.org: $(dig +short voice.bigcohen.org 2>/dev/null || echo '[dig unavailable]')"
    echo
    
    # Config Files
    echo "## Config Files"
    ls -lh ~/.openclaw/.env ~/.openclaw/.api-keys ~/.openclaw/.x-env ~/.claude.json 2>&1
    echo
    
    # Vault
    echo "## Vault Secrets"
    vault kv list secret/ 2>&1 || echo "[vault unavailable]"
    
} > "$TEMP_STATE"

echo "✅ Current state collected"
echo

# ============================================
# 2. COMPARE WITH BASELINE
# ============================================

echo "🔍 Comparing with baseline..."

# Extract key sections and compare
declare -A CHANGES=()

# Function to extract section from markdown
extract_section() {
    local file=$1
    local section=$2
    awk "/^## $section/,/^## /" "$file" | head -n -1
}

# Check process counts
BASELINE_PROCS=$(grep -c "openclaw-gateway" "$STATE_FILE" || echo 0)
CURRENT_PROCS=$(grep -c "openclaw-gateway" "$TEMP_STATE" || echo 0)

if [[ "$BASELINE_PROCS" != "$CURRENT_PROCS" ]]; then
    CHANGES["gateway_processes"]="Changed from $BASELINE_PROCS to $CURRENT_PROCS gateway processes"
fi

# Check LaunchAgent status
BASELINE_AGENTS=$(extract_section "$STATE_FILE" "LaunchAgents" | grep -c "✅" || echo 0)
CURRENT_AGENTS=$(extract_section "$TEMP_STATE" "LaunchAgents" | grep -c "0" || echo 0)

if [[ "$BASELINE_AGENTS" != "$CURRENT_AGENTS" ]]; then
    CHANGES["launchagents"]="LaunchAgent count changed from $BASELINE_AGENTS to $CURRENT_AGENTS loaded"
fi

# Check DNS resolution changes
BASELINE_DNS=$(grep -A3 "### Domain Resolution" "$STATE_FILE" | tail -3)
CURRENT_DNS=$(extract_section "$TEMP_STATE" "DNS")

if [[ "$BASELINE_DNS" != "$CURRENT_DNS" ]]; then
    CHANGES["dns"]="DNS resolution IPs changed"
fi

# Check if Reb VM is reachable
if grep -q "\[Reb VM unreachable\]" "$TEMP_STATE"; then
    CHANGES["reb_vm"]="⚠️ Reb VM is unreachable"
fi

# Check for high CPU on Reb VM
if grep -q "100%" "$TEMP_STATE"; then
    CHANGES["reb_cpu"]="⚠️ High CPU usage detected on Reb VM"
fi

# Check config files
BASELINE_CONFIGS=$(grep -c "✅" "$STATE_FILE" | grep -A5 "### Present" || echo 0)
CURRENT_CONFIGS=$(grep "~/.openclaw" "$TEMP_STATE" | grep -v "cannot access" | wc -l)

if [[ "$BASELINE_CONFIGS" != "$CURRENT_CONFIGS" ]]; then
    CHANGES["config_files"]="Config file count changed"
fi

# ============================================
# 3. REPORT CHANGES
# ============================================

echo
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "📋 Change Summary"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo

if [[ ${#CHANGES[@]} -eq 0 ]]; then
    echo -e "${GREEN}✅ No significant changes detected${NC}"
else
    echo -e "${YELLOW}⚠️  Changes detected:${NC}"
    echo
    for key in "${!CHANGES[@]}"; do
        echo -e "  ${YELLOW}•${NC} ${CHANGES[$key]}"
    done
fi

echo
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

# ============================================
# 4. DETAILED DIFF (optional)
# ============================================

if [[ ${#CHANGES[@]} -gt 0 ]]; then
    echo
    echo "🔎 Detailed comparison:"
    echo
    
    # Show side-by-side diff of key sections
    diff -u \
        <(extract_section "$STATE_FILE" "Running Services") \
        <(extract_section "$TEMP_STATE" "Running Services") \
        > "$DIFF_OUTPUT" 2>&1 || true
    
    if [[ -s "$DIFF_OUTPUT" ]]; then
        echo "--- Services Diff ---"
        cat "$DIFF_OUTPUT" | head -30
        echo
    fi
fi

# ============================================
# 5. UPDATE BASELINE (if requested)
# ============================================

if [[ "${1:-}" == "--update-baseline" ]]; then
    echo
    echo -e "${BLUE}📝 Updating baseline state file...${NC}"
    
    # Keep the detailed format from original state file
    # Just update the timestamp and known-variable sections
    
    # For now, simple approach: regenerate entire state file
    # (In production, would preserve comments/formatting)
    
    echo "⚠️  Full baseline regeneration not implemented yet."
    echo "Current snapshot saved to: $TEMP_STATE"
    echo "Review and manually update $STATE_FILE if needed."
else
    echo
    echo "💡 Tip: Run with --update-baseline to accept current state as new baseline"
fi

echo
echo "📁 Temp state saved to: $TEMP_STATE"
echo "🗂️  Baseline: $STATE_FILE"
echo

# Cleanup
# rm -f "$TEMP_STATE" "$DIFF_OUTPUT"  # Uncomment to auto-cleanup

echo "✅ Audit complete"
