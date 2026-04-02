#!/bin/bash
# vault-sync.sh — Sync Drive vault folder tree with SQLite index
# Runs periodically to catch moves, renames, deletes, and new files added directly to vault
# Usage: vault-sync.sh [--dry-run]

set -euo pipefail

DB="$HOME/.openclaw/workspace/state/vault/document-vault-index.db"
VAULT_MAP="$HOME/.openclaw/workspace/config/integrations/document-vault-map.json"
LOG="$HOME/.openclaw/workspace/state/vault/vault-sync.log"
DRY_RUN=false
[[ "${1:-}" == "--dry-run" ]] && DRY_RUN=true

ACCOUNT="meircohen@gmail.com"
RATE_LIMIT=0.3

ts() { date "+%Y-%m-%d %H:%M:%S"; }
log() { echo "[$(ts)] $1" | tee -a "$LOG"; }

log "=== Vault Sync Started (dry_run=$DRY_RUN) ==="

# Get all vault folder IDs from the map (using jq for reliability)
FOLDER_IDS=$(jq -r '.. | strings | select(length > 20 and test("^[0-9A-Za-z_-]{20,}$"))' "$VAULT_MAP" 2>/dev/null | sort -u)

FOLDER_COUNT=$(echo "$FOLDER_IDS" | wc -l | tr -d ' ')
log "Scanning $FOLDER_COUNT vault folders"

ADDED=0
UPDATED=0
REMOVED=0
SCANNED=0
ERRORS=0

# Temp file for all Drive file IDs we see
SEEN_IDS=$(mktemp)
trap "rm -f $SEEN_IDS" EXIT

for FID in $FOLDER_IDS; do
    SCANNED=$((SCANNED + 1))
    
    # List files in this folder
    FILES_JSON=$(gog drive ls "$FID" --account "$ACCOUNT" --json 2>/dev/null || echo "[]")
    sleep "$RATE_LIMIT"
    
    if [[ "$FILES_JSON" == "[]" ]] || [[ -z "$FILES_JSON" ]]; then
        continue
    fi
    
    # Parse each file
    echo "$FILES_JSON" | /usr/bin/python3 -c "
import json, sys, sqlite3, os

dry_run = '$DRY_RUN' == 'true'
db_path = '$DB'
folder_id = '$FID'

try:
    data = json.load(sys.stdin)
except:
    sys.exit(0)

if not isinstance(data, list):
    data = [data]

conn = sqlite3.connect(db_path)
c = conn.cursor()

added = 0
updated = 0

for f in data:
    fid = f.get('id','')
    name = f.get('name','')
    mime = f.get('mimeType','')
    size = f.get('size', 0)
    md5 = f.get('md5Checksum','')
    
    if not fid or not name:
        continue
    if mime == 'application/vnd.google-apps.folder':
        continue
    
    # Write to seen IDs file
    with open('$SEEN_IDS', 'a') as sf:
        sf.write(fid + '\n')
    
    # Check if exists in DB
    c.execute('SELECT id, name, vault_folder_id FROM documents WHERE drive_id = ?', (fid,))
    row = c.fetchone()
    
    if row is None:
        # New file — add it
        if not dry_run:
            c.execute('''INSERT INTO documents (drive_id, name, mime_type, size_bytes, md5_checksum, vault_folder_id, source, indexed_at, status)
                VALUES (?, ?, ?, ?, ?, ?, 'drive_sync', datetime('now'), 'indexed')''',
                (fid, name, mime, size, md5, folder_id))
        added += 1
        print(f'ADD: {name}')
    else:
        # Exists — check if name or folder changed
        old_name = row[1]
        old_folder = row[2]
        changes = []
        if old_name != name:
            changes.append(f'name: {old_name} -> {name}')
        if old_folder != folder_id:
            changes.append(f'folder: {old_folder} -> {folder_id}')
        if changes:
            if not dry_run:
                c.execute('UPDATE documents SET name = ?, vault_folder_id = ? WHERE drive_id = ?',
                    (name, folder_id, fid))
            updated += 1
            print(f'UPD: {name} ({\" | \".join(changes)})')

if not dry_run:
    conn.commit()
conn.close()

print(f'STATS: +{added} ~{updated}')
" 2>/dev/null || ERRORS=$((ERRORS + 1))
    
    # Progress every 10 folders
    if (( SCANNED % 10 == 0 )); then
        log "  Scanned $SCANNED/$FOLDER_COUNT folders..."
    fi
done

log "Scan complete: $SCANNED folders scanned, $ERRORS errors"

# Phase 2: Detect deletions — find DB records with drive_id not seen in scan
if [[ -s "$SEEN_IDS" ]]; then
    SEEN_COUNT=$(wc -l < "$SEEN_IDS" | tr -d ' ')
    log "Checking for deletions ($SEEN_COUNT files seen on Drive)"
    
    DELETED=$(/usr/bin/python3 -c "
import sqlite3

seen = set()
with open('$SEEN_IDS') as f:
    for line in f:
        seen.add(line.strip())

dry_run = '$DRY_RUN' == 'true'
conn = sqlite3.connect('$DB')
c = conn.cursor()
c.execute('SELECT id, drive_id, name FROM documents WHERE drive_id IS NOT NULL AND status != \"deleted\"')
deleted = 0
for row in c.fetchall():
    if row[1] not in seen:
        if not dry_run:
            c.execute('UPDATE documents SET status = \"deleted\" WHERE id = ?', (row[0],))
        deleted += 1
        if deleted <= 10:
            print(f'DEL: {row[2]}')

if not dry_run:
    conn.commit()
conn.close()
print(f'TOTAL_DELETED: {deleted}')
" 2>/dev/null)
    
    echo "$DELETED" | tee -a "$LOG"
fi

# Phase 3: Auto-tag untagged docs by folder path
if [[ "$DRY_RUN" == "false" ]]; then
    TAGGED=$(/usr/bin/python3 -c "
import sqlite3, json

conn = sqlite3.connect('$DB')
c = conn.cursor()

# Load folder-to-entity mapping
with open('$HOME/.openclaw/workspace/config/integrations/document-vault-map.json') as f:
    vmap = json.load(f)

# Build folder_id -> entity name mapping
folder_entity = {}
companies = vmap.get('sections',{}).get('01 - Companies',{})
if isinstance(companies, dict):
    for entity_name, folders in companies.items():
        if isinstance(folders, str):
            folder_entity[folders] = entity_name
        elif isinstance(folders, dict):
            for sub_name, fid in folders.items():
                if isinstance(fid, str):
                    folder_entity[fid] = entity_name

# Tag untagged docs
c.execute('SELECT id, vault_folder_id FROM documents WHERE (entity IS NULL OR entity = \"\") AND vault_folder_id IS NOT NULL')
tagged = 0
for row in c.fetchall():
    entity = folder_entity.get(row[1])
    if entity:
        c.execute('UPDATE documents SET entity = ? WHERE id = ?', (entity, row[0]))
        tagged += 1

conn.commit()
conn.close()
print(f'Auto-tagged {tagged} docs by folder')
" 2>/dev/null)
    log "$TAGGED"
fi

# Summary
TOTAL=$(sqlite3 "$DB" "SELECT count(*) FROM documents WHERE status != 'deleted';")
ENTITY_PCT=$(sqlite3 "$DB" "SELECT printf('%.0f', 100.0 * count(CASE WHEN entity IS NOT NULL AND entity != '' THEN 1 END) / count(*)) FROM documents WHERE status != 'deleted';")
log "=== Vault Sync Complete: $TOTAL active docs, ${ENTITY_PCT}% entity-tagged ==="
