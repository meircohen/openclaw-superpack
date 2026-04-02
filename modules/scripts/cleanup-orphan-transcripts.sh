#!/bin/bash
# Safe orphan transcript cleanup
# Only removes transcripts older than 7 days NOT referenced in sessions.json

set -euo pipefail

SESSIONS_DIR="$HOME/.openclaw/agents/main/sessions"
SESSIONS_JSON="$SESSIONS_DIR/sessions.json"
BACKUP_LIST="$HOME/.openclaw/workspace/artifacts/orphan-transcripts-$(date +%Y%m%d-%H%M%S).txt"

echo "🔍 Finding orphan transcripts..."

# Extract all session IDs from sessions.json
ACTIVE_IDS=$(jq -r 'keys[]' "$SESSIONS_JSON" | grep -v '^$' || true)

# Find all transcript files older than 7 days
cd "$SESSIONS_DIR"
ORPHANS=0
SAVED_SPACE=0

# Create backup list
mkdir -p "$(dirname "$BACKUP_LIST")"
echo "# Orphan transcripts cleanup - $(date)" > "$BACKUP_LIST"

for file in $(find . -maxdepth 1 -name "*.jsonl" -type f -mtime +7); do
    basename_file=$(basename "$file")
    session_id="${basename_file%.jsonl}"
    
    # Check if this session ID is in the active list
    if ! echo "$ACTIVE_IDS" | grep -qF "$session_id"; then
        size=$(stat -f%z "$file" 2>/dev/null || stat -c%s "$file" 2>/dev/null || echo "0")
        echo "$file ($size bytes)" >> "$BACKUP_LIST"
        SAVED_SPACE=$((SAVED_SPACE + size))
        ORPHANS=$((ORPHANS + 1))
        
        # Delete the orphan
        rm "$file"
    fi
done

SAVED_MB=$((SAVED_SPACE / 1024 / 1024))

echo "✅ Cleanup complete:"
echo "   - Orphans removed: $ORPHANS"
echo "   - Space freed: ${SAVED_MB}MB"
echo "   - Backup list: $BACKUP_LIST"

if [ "$ORPHANS" -eq 0 ]; then
    echo "   - No orphans found (already clean)"
fi
