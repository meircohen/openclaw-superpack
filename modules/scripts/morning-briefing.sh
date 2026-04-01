#!/bin/bash
# morning-briefing.sh — Generates daily briefing from workspace data
# Pulls from: pending_items.md, active_guidance.md, cron status, git log, intel digest
set -e

WORKSPACE="$HOME/.openclaw/workspace"
DATE=$(date '+%Y-%m-%d')
DAY=$(date '+%A')
TIME=$(date '+%I:%M %p')

echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "☀️ DAILY BRIEFING — $DAY, $(date '+%B %d, %Y') at $TIME"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

# Overdue items
echo "⚠️ OVERDUE"
grep -E "^\- \[ \].*CRITICAL|^\- \[ \].*overdue|^\- \[ \].*PASSED" "$WORKSPACE/memory/blocks/pending_items.md" 2>/dev/null | sed 's/^- \[ \] /• /' || echo "• None"
echo ""

# Today's active tasks
echo "📋 ACTIVE TASKS"
grep -E "^\- \[ \]" "$WORKSPACE/memory/blocks/pending_items.md" 2>/dev/null | grep -v "CRITICAL\|overdue\|PASSED" | head -8 | sed 's/^- \[ \] /• /' || echo "• None"
echo ""

# Cron health
echo "⚡ CRON STATUS"
openclaw cron list --json 2>/dev/null | python3 -c "
import json, sys
data = json.load(sys.stdin)
ok = sum(1 for j in data.get('jobs', []) if j['state'].get('consecutiveErrors', 0) == 0)
total = len(data.get('jobs', []))
failing = [j['name'] for j in data.get('jobs', []) if j['state'].get('consecutiveErrors', 0) > 0]
print(f'• {ok}/{total} healthy')
for f in failing:
    print(f'• ❌ {f}')
" 2>/dev/null || echo "• Unable to check"
echo ""

# Recent git activity
echo "📝 RECENT COMMITS (24h)"
cd "$WORKSPACE" && git log --oneline --since="24 hours ago" 2>/dev/null | head -5 | sed 's/^/• /' || echo "• None"
echo ""

# Intelligence digest summary
if [ -f "$WORKSPACE/intelligence/digest.md" ]; then
    echo "🧠 INTEL DIGEST"
    grep -c "^### 🔴" "$WORKSPACE/intelligence/digest.md" 2>/dev/null | xargs -I{} echo "• {} act-now items"
    grep -c "^### 🟡" "$WORKSPACE/intelligence/digest.md" 2>/dev/null | xargs -I{} echo "• {} evaluate items"
fi
echo ""

# Mesh health
echo "🔧 MESH STATUS"
python3 "$WORKSPACE/mesh/health.py" --json 2>/dev/null | python3 -c "
import json, sys
data = json.load(sys.stdin)
online = sum(1 for s in data.get('systems', []) if s.get('online'))
total = len(data.get('systems', []))
offline = [s['name'] for s in data.get('systems', []) if not s.get('online')]
print(f'• {online}/{total} systems online')
for o in offline:
    print(f'• ❌ {o}')
" 2>/dev/null || echo "• Unable to check"
echo ""

# Backup status
echo "💾 BACKUP STATUS"
LAST_BACKUP=$(ls -t "$WORKSPACE/backups"/workspace-*.tar.gz 2>/dev/null | head -1)
if [ -n "$LAST_BACKUP" ]; then
    BACKUP_DATE=$(stat -f "%Sm" -t "%Y-%m-%d %H:%M" "$LAST_BACKUP" 2>/dev/null || stat -c "%y" "$LAST_BACKUP" 2>/dev/null | cut -d. -f1)
    BACKUP_SIZE=$(du -h "$LAST_BACKUP" | cut -f1)
    echo "• Last: $BACKUP_DATE ($BACKUP_SIZE)"
else
    echo "• ⚠️ No local backups found"
fi
LAST_GIT=$(cd "$WORKSPACE" && git log -1 --format="%ci" 2>/dev/null | cut -d' ' -f1,2)
echo "• Git: $LAST_GIT"
echo ""

echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
