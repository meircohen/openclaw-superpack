#!/bin/bash
# scripts/audit-self-discover.sh — Pre-audit self-discovery
set -euo pipefail

WORKSPACE="${OPENCLAW_WORKSPACE:-$HOME/.openclaw/workspace}"
SCOPE_FILE="$WORKSPACE/config/audit-scope-current.json"
SCORECARD="$WORKSPACE/config/self-scorecard.json"
OUTPUT="$WORKSPACE/artifacts/pre-audit-discovery-$(date +%Y-%m-%d).md"
TODAY=$(date +%Y-%m-%d)

# Determine last audit date from scorecard
LAST_AUDIT_DATE=$(python3 -c "
import json
with open('$SCORECARD') as f:
    sc = json.load(f)
print(sc.get('lastUpdated','2026-01-01')[:10])
" 2>/dev/null || echo "2026-01-01")

echo "# Pre-Audit Discovery Report" > "$OUTPUT"
echo "**Generated:** $(date -Iseconds)" >> "$OUTPUT"
echo "**Period:** $LAST_AUDIT_DATE → $TODAY" >> "$OUTPUT"
echo "**Workspace:** $WORKSPACE" >> "$OUTPUT"
echo "" >> "$OUTPUT"

# ─── GIT DIFF ───
echo "## 1. Workspace File Changes (Git)" >> "$OUTPUT"
cd "$WORKSPACE"
if git rev-parse --is-inside-work-tree >/dev/null 2>&1; then
  # New files since last audit
  NEW_FILES=$(git log --since="$LAST_AUDIT_DATE" --diff-filter=A --name-only --pretty=format: | sort -u | grep -v '^$' || true)
  MODIFIED_FILES=$(git log --since="$LAST_AUDIT_DATE" --diff-filter=M --name-only --pretty=format: | sort -u | grep -v '^$' || true)
  DELETED_FILES=$(git log --since="$LAST_AUDIT_DATE" --diff-filter=D --name-only --pretty=format: | sort -u | grep -v '^$' || true)
  
  NEW_COUNT=$(echo "$NEW_FILES" | grep -c '.' 2>/dev/null || echo 0)
  MOD_COUNT=$(echo "$MODIFIED_FILES" | grep -c '.' 2>/dev/null || echo 0)
  DEL_COUNT=$(echo "$DELETED_FILES" | grep -c '.' 2>/dev/null || echo 0)
  
  echo "- **New files:** $NEW_COUNT" >> "$OUTPUT"
  echo "- **Modified files:** $MOD_COUNT" >> "$OUTPUT"
  echo "- **Deleted files:** $DEL_COUNT" >> "$OUTPUT"
  echo "" >> "$OUTPUT"
  
  # Categorize new files by system
  echo "### New Files by System" >> "$OUTPUT"
  for sys in "time-awareness" "nechie-onboarding" "agent-room" "smart-router" "skill-graphs" "dashboard" "voice" "reb"; do
    matches=$(echo "$NEW_FILES" | grep -i "$sys" || true)
    if [ -n "$matches" ]; then
      count=$(echo "$matches" | wc -l | tr -d ' ')
      echo "- **$sys:** $count new files" >> "$OUTPUT"
      echo "$matches" | sed 's/^/  - /' >> "$OUTPUT"
    fi
  done
  echo "" >> "$OUTPUT"
else
  echo "⚠️ Not a git repo — falling back to file timestamp diff" >> "$OUTPUT"
  # Fallback: find files modified since last audit date
  find "$WORKSPACE" -type f -newer <(date -j -f "%Y-%m-%d" "$LAST_AUDIT_DATE" +"%Y%m%d%H%M.%S" 2>/dev/null || echo "202601010000.00") \
    -not -path "*/node_modules/*" -not -path "*/.git/*" \
    -not -path "*/logs/*" | head -100 >> "$OUTPUT" 2>/dev/null || true
  echo "" >> "$OUTPUT"
fi

# ─── CRON DIFF ───
echo "## 2. Cron Job Inventory" >> "$OUTPUT"
CRON_LIST=$(openclaw cron list 2>/dev/null || echo "ERROR: could not list crons")
CRON_COUNT=$(echo "$CRON_LIST" | grep -c '.' 2>/dev/null || echo 0)
echo "- **Active crons:** $CRON_COUNT" >> "$OUTPUT"

# Compare against last known cron count (from scope file)
if [ -f "$SCOPE_FILE" ]; then
  PREV_CRON_COUNT=$(python3 -c "
import json
with open('$SCOPE_FILE') as f:
    s = json.load(f)
print(s.get('cron_count', 0))
" 2>/dev/null || echo 0)
  CRON_DELTA=$((CRON_COUNT - PREV_CRON_COUNT))
  if [ "$CRON_DELTA" -gt 0 ]; then
    echo "- ✅ **NEW:** $CRON_DELTA crons added since last audit" >> "$OUTPUT"
  elif [ "$CRON_DELTA" -lt 0 ]; then
    echo "- ❌ **REMOVED:** $((-CRON_DELTA)) crons deleted since last audit" >> "$OUTPUT"
  else
    echo "- ⏸️ No cron count change" >> "$OUTPUT"
  fi
fi
echo "" >> "$OUTPUT"

# List crons with IDs for diff tracking
echo "### Current Cron Inventory" >> "$OUTPUT"
echo '```' >> "$OUTPUT"
echo "$CRON_LIST" >> "$OUTPUT"
echo '```' >> "$OUTPUT"
echo "" >> "$OUTPUT"

# ─── AGENT CONFIG DIFF ───
echo "## 3. Agent & Model Configuration" >> "$OUTPUT"

# Check model registry for changes
if [ -f "$WORKSPACE/config/models/model-registry.json" ]; then
  MODEL_COUNT=$(python3 -c "
import json
with open('$WORKSPACE/config/models/model-registry.json') as f:
    d = json.load(f)
models = d.get('models', d)
print(len(models) if isinstance(models, (list, dict)) else 0)
" 2>/dev/null || echo "?")
  echo "- **Models in registry:** $MODEL_COUNT" >> "$OUTPUT"
fi

# Check budget configs
echo "- **Budget targets:**" >> "$OUTPUT"
python3 -c "
import json
with open('$SCORECARD') as f:
    sc = json.load(f)
ct = sc.get('cost_tracking', {})
print(f'  - Total estimated spend: \${ct.get(\"total_estimated_cost_usd\", \"unknown\")}')
for model, data in ct.get('by_model', {}).items():
    print(f'  - {model}: \${data}')
" 2>/dev/null >> "$OUTPUT" || echo "  - (cost tracking not populated)" >> "$OUTPUT"
echo "" >> "$OUTPUT"

# ─── INFRASTRUCTURE SCAN ───
echo "## 4. Infrastructure Inventory" >> "$OUTPUT"

# Check running services
echo "### Active Services" >> "$OUTPUT"
echo "| Service | Status | PID/Port |" >> "$OUTPUT"
echo "|---------|--------|----------|" >> "$OUTPUT"

# Gateway
GW_PID=$(pgrep -f "openclaw" | head -1 || echo "none")
echo "| OpenClaw Gateway | $([ "$GW_PID" != "none" ] && echo "✅ Running" || echo "❌ Down") | PID $GW_PID |" >> "$OUTPUT"

# Cloudflared
CF_PID=$(pgrep -f "cloudflared" | head -1 || echo "none")
echo "| Cloudflared Tunnel | $([ "$CF_PID" != "none" ] && echo "✅ Running" || echo "❌ Down") | PID $CF_PID |" >> "$OUTPUT"

# Agent Room API
AR_STATUS=$(curl -s -o /dev/null -w '%{http_code}' http://localhost:3001/api/queue/status 2>/dev/null || echo "000")
echo "| Agent Room v2 API | $([ "$AR_STATUS" = "200" ] && echo "✅ Running" || echo "❌ Down ($AR_STATUS)") | :3001 |" >> "$OUTPUT"

# Oz Voice
OV_PID=$(pgrep -f "oz-voice" | head -1 || echo "none")
echo "| Oz Voice Server | $([ "$OV_PID" != "none" ] && echo "✅ Running" || echo "❌ Down") | PID $OV_PID |" >> "$OUTPUT"

echo "" >> "$OUTPUT"

# Check LaunchAgents
echo "### LaunchAgents" >> "$OUTPUT"
launchctl list 2>/dev/null | grep -i "bigcohen\|agent-room\|oz-voice\|cloudflare" | while read line; do
  echo "- $line" >> "$OUTPUT"
done
echo "" >> "$OUTPUT"

# Check network endpoints
echo "### Network Endpoints" >> "$OUTPUT"
for url in "http://localhost:18789" "http://localhost:3001/api/queue/status" "https://voice.bigcohen.org" "https://api.bigcohen.org"; do
  status=$(curl -s -o /dev/null -w '%{http_code}' --max-time 5 "$url" 2>/dev/null || echo "timeout")
  echo "- $url → $status" >> "$OUTPUT"
done
echo "" >> "$OUTPUT"

# Check Reb VM connectivity
echo "### Fleet Connectivity" >> "$OUTPUT"
REB_PING=$(ssh -o ConnectTimeout=5 -o StrictHostKeyChecking=no reb@100.126.105.8 'echo ok' 2>/dev/null || echo "UNREACHABLE")
echo "- Reb VM (100.126.105.8): $REB_PING" >> "$OUTPUT"
if [ "$REB_PING" = "ok" ]; then
  REB_GW=$(ssh -o ConnectTimeout=5 reb@100.126.105.8 'openclaw gateway status 2>/dev/null | head -1' 2>/dev/null || echo "unknown")
  echo "- Reb Gateway: $REB_GW" >> "$OUTPUT"
  REB_CRONS=$(ssh -o ConnectTimeout=5 reb@100.126.105.8 'openclaw cron list 2>/dev/null | wc -l' 2>/dev/null || echo "?")
  echo "- Reb Crons: $REB_CRONS" >> "$OUTPUT"
fi
echo "" >> "$OUTPUT"

# ─── SCOPE DELTA COMPUTATION ───
echo "## 5. Audit Scope Delta" >> "$OUTPUT"
echo "" >> "$OUTPUT"

# Detect new systems by checking for signature files (bash 3.2 compatible)
check_system() {
  local name="$1"
  shift
  local files=("$@")
  local found=0
  local total=${#files[@]}
  
  for f in "${files[@]}"; do
    [ -e "$WORKSPACE/$f" ] && found=$((found + 1))
  done
  
  if [ "$found" -gt 0 ]; then
    echo "- ✅ **$name**: detected ($found/$total signature files present)" >> "$OUTPUT"
  else
    echo "- ⚪ **$name**: not detected (0/$total signature files)" >> "$OUTPUT"
  fi
}

check_system "time-awareness" "scripts/time-awareness.sh" "data/time-state.json" "scripts/shabbos-safe-notify.sh"
check_system "nechie-onboarding" "data/nechie-onboarding-state.json"
check_system "agent-room-v2" "agent-room-v2/lib/index.js" "agent-room-v2/db"
check_system "smart-router" "scripts/smart-router-v2.js" "config/smart-router-config.json"
check_system "skill-graphs" "skill-graphs/index.md" "skill-graphs/financial/index.md"
check_system "dashboard" "bigcohen-dashboard/"
check_system "oz-voice" "oz-voice/server.js"
check_system "custom-domains" "scripts/tunnel-health.sh"
check_system "model-registry" "config/models/model-registry.json" "docs/MODEL-CATALOG.md"

echo "" >> "$OUTPUT"

# Compare against previous scope
if [ -f "$SCOPE_FILE" ]; then
  echo "### Changes vs Last Audit Scope" >> "$OUTPUT"
  python3 -c "
import json
with open('$SCOPE_FILE') as f:
    prev = json.load(f)
prev_systems = set(prev.get('detected_systems', []))
# Current systems would be computed above; for now list what we found
print(f'Previous scope had {len(prev_systems)} systems: {\", \".join(sorted(prev_systems))}')
print(f'Review the detection list above for additions/removals.')
" 2>/dev/null >> "$OUTPUT" || echo "  (no previous scope file to compare)" >> "$OUTPUT"
else
  echo "### First Run — No Previous Scope" >> "$OUTPUT"
  echo "This is the first discovery run. All detected systems are NEW to scope." >> "$OUTPUT"
fi
echo "" >> "$OUTPUT"

# ─── UPDATE SCOPE FILE ───
echo "## 6. Updated Scope Written" >> "$OUTPUT"

# Build new scope JSON
python3 << 'PYSCRIPT' > "$SCOPE_FILE"
import json, subprocess, os, datetime

workspace = os.environ.get("OPENCLAW_WORKSPACE", os.path.expanduser("~/.openclaw/workspace"))
today = datetime.date.today().isoformat()

# Detect which systems are present
system_signatures = {
    "time-awareness": ["scripts/time-awareness.sh", "data/time-state.json"],
    "nechie-onboarding": ["data/nechie-onboarding-state.json"],
    "agent-room-v2": ["agent-room-v2/lib/index.js"],
    "smart-router": [],  # may not have dedicated files yet
    "skill-graphs": ["skill-graphs/index.md"],
    "dashboard": [],
    "oz-voice": ["oz-voice/server.js"],
    "model-registry": ["config/models/model-registry.json"],
    "financial-systems": ["financial-state.json", "config/bill-pay-calendar.json"],
    "memory-system": ["MEMORY.md", "memory/active-tasks.md"],
    "x-twitter": [],
}

detected = []
for system, files in system_signatures.items():
    if not files:
        detected.append(system)  # always include systems without signature files
        continue
    for f in files:
        if os.path.exists(os.path.join(workspace, f)):
            detected.append(system)
            break

# Count crons
try:
    result = subprocess.run(["openclaw", "cron", "list"], capture_output=True, text=True, timeout=10)
    cron_count = len([l for l in result.stdout.strip().split('\n') if l.strip()])
except:
    cron_count = 0

# Count skill graph nodes
try:
    result = subprocess.run(["find", os.path.join(workspace, "skill-graphs"), "-name", "*.md", "-type", "f"],
                          capture_output=True, text=True, timeout=5)
    sg_count = len([l for l in result.stdout.strip().split('\n') if l.strip()])
except:
    sg_count = 0

scope = {
    "version": "2.0",
    "generated": today,
    "last_audit_date": today,
    "detected_systems": sorted(detected),
    "system_count": len(detected),
    "cron_count": cron_count,
    "skill_graph_nodes": sg_count,
    "fleet_members": {
        "oz": {"host": "iMac", "ip": "127.0.0.1:18789", "tailscale": "100.103.183.77"},
        "homebot": {"host": "iMac", "role": "family-ops"},
        "reb": {"host": "GCE e2-medium", "ip": "34.44.62.146", "tailscale": "100.126.105.8"}
    },
    "audit_sections": 13,
    "notes": "Auto-generated by audit-self-discover.sh"
}

print(json.dumps(scope, indent=2))
PYSCRIPT

echo "Scope file updated: $SCOPE_FILE" >> "$OUTPUT"
echo "" >> "$OUTPUT"

# ─── SUMMARY ───
echo "## Summary" >> "$OUTPUT"
echo "" >> "$OUTPUT"
echo "Discovery complete. Audit scope is current." >> "$OUTPUT"
echo "Run the full audit with the updated scope." >> "$OUTPUT"

echo "✅ Discovery report written to: $OUTPUT"
echo "✅ Scope file updated: $SCOPE_FILE"
