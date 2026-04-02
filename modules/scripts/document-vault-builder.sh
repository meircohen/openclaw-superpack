#!/bin/bash
# Document Vault Builder - Phase 1: Copy, Move, Dedup, Index
# Handles: Andrea's folders → copy, old root folders → move, local files → upload
# ALWAYS checks for duplicates before any operation

set -euo pipefail

WORKSPACE="$HOME/.openclaw/workspace"
VAULT_MAP="$WORKSPACE/config/integrations/document-vault-map.json"
ACCOUNT="meircohen@gmail.com"
INDEX_DB="$WORKSPACE/state/vault/document-vault-index.db"
LOG_FILE="$WORKSPACE/state/vault/vault-builder.log"
DEDUP_LOG="$WORKSPACE/state/vault/vault-duplicates.jsonl"

mkdir -p "$WORKSPACE/state"

log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $*" | tee -a "$LOG_FILE"
}

# Initialize SQLite index
init_db() {
    sqlite3 "$INDEX_DB" <<'SQL'
CREATE TABLE IF NOT EXISTS documents (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    drive_id TEXT UNIQUE,
    name TEXT NOT NULL,
    mime_type TEXT,
    size_bytes INTEGER,
    md5_checksum TEXT,
    vault_path TEXT,
    vault_folder_id TEXT,
    source TEXT,
    source_path TEXT,
    entity TEXT,
    doc_type TEXT,
    doc_year INTEGER,
    tags TEXT,
    indexed_at TEXT DEFAULT (datetime('now')),
    uploaded_at TEXT,
    status TEXT DEFAULT 'indexed'
);

CREATE TABLE IF NOT EXISTS entities (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    name TEXT UNIQUE,
    entity_type TEXT,
    ein TEXT,
    expected_docs TEXT,
    vault_folder_id TEXT
);

CREATE TABLE IF NOT EXISTS expected_documents (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    entity_name TEXT,
    doc_type TEXT,
    year INTEGER,
    status TEXT DEFAULT 'missing',
    document_id INTEGER,
    source_hint TEXT,
    FOREIGN KEY(document_id) REFERENCES documents(id)
);

CREATE TABLE IF NOT EXISTS duplicates (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    original_id INTEGER,
    duplicate_drive_id TEXT,
    duplicate_name TEXT,
    duplicate_path TEXT,
    detected_at TEXT DEFAULT (datetime('now')),
    action TEXT DEFAULT 'pending',
    FOREIGN KEY(original_id) REFERENCES documents(id)
);

CREATE INDEX IF NOT EXISTS idx_docs_name ON documents(name);
CREATE INDEX IF NOT EXISTS idx_docs_md5 ON documents(md5_checksum);
CREATE INDEX IF NOT EXISTS idx_docs_entity ON documents(entity);
CREATE INDEX IF NOT EXISTS idx_docs_type ON documents(doc_type);
CREATE INDEX IF NOT EXISTS idx_docs_year ON documents(doc_year);
CREATE INDEX IF NOT EXISTS idx_expected_status ON expected_documents(status);
SQL
    log "Database initialized: $INDEX_DB"
}

# Check if a file already exists in the index (by name + size OR md5)
check_duplicate() {
    local name="$1"
    local size="${2:-0}"
    local md5="${3:-}"
    
    local result=""
    
    # Check by MD5 first (most reliable)
    if [[ -n "$md5" ]]; then
        result=$(sqlite3 "$INDEX_DB" "SELECT id, drive_id, vault_path FROM documents WHERE md5_checksum='$md5' LIMIT 1;" 2>/dev/null)
    fi
    
    # Fallback: check by name + size
    if [[ -z "$result" && -n "$name" ]]; then
        result=$(sqlite3 "$INDEX_DB" "SELECT id, drive_id, vault_path FROM documents WHERE name='$(echo "$name" | sed "s/'/''/g")' AND size_bytes=$size LIMIT 1;" 2>/dev/null)
    fi
    
    # Fallback: check by name only (fuzzy - warn but don't block)
    if [[ -z "$result" && -n "$name" ]]; then
        result=$(sqlite3 "$INDEX_DB" "SELECT id, drive_id, vault_path FROM documents WHERE name='$(echo "$name" | sed "s/'/''/g")' LIMIT 1;" 2>/dev/null)
        if [[ -n "$result" ]]; then
            echo "WARN_SIMILAR|$result"
            return 0
        fi
    fi
    
    if [[ -n "$result" ]]; then
        echo "DUPLICATE|$result"
        return 0
    fi
    
    echo "NEW"
    return 0
}

# Index a Drive file into the database
index_drive_file() {
    local drive_id="$1"
    local name="$2"
    local mime_type="$3"
    local size="${4:-0}"
    local md5="${5:-}"
    local vault_path="$6"
    local vault_folder_id="$7"
    local source="$8"
    local entity="${9:-}"
    local doc_type="${10:-}"
    local doc_year="${11:-}"
    
    # Escape single quotes for SQL
    local safe_name=$(echo "$name" | sed "s/'/''/g")
    local safe_path=$(echo "$vault_path" | sed "s/'/''/g")
    local safe_source=$(echo "$source" | sed "s/'/''/g")
    
    sqlite3 "$INDEX_DB" "INSERT OR IGNORE INTO documents (drive_id, name, mime_type, size_bytes, md5_checksum, vault_path, vault_folder_id, source, entity, doc_type, doc_year, status) VALUES ('$drive_id', '$safe_name', '$mime_type', $size, '$md5', '$safe_path', '$vault_folder_id', '$safe_source', '$entity', '$doc_type', ${doc_year:-NULL}, 'indexed');" 2>/dev/null
}

# Crawl a Drive folder recursively and index all files
crawl_drive_folder() {
    local folder_id="$1"
    local path_prefix="$2"
    local source="$3"
    local depth="${4:-0}"
    
    if [[ $depth -gt 10 ]]; then
        log "WARNING: Max depth reached at $path_prefix"
        return
    fi
    
    local files_json=$(gog drive ls --account "$ACCOUNT" --parent "$folder_id" --max 100 --json 2>/dev/null)
    
    echo "$files_json" | python3 -c "
import json, sys
try:
    d = json.load(sys.stdin)
    for f in d.get('files', []):
        mime = f.get('mimeType', '')
        is_folder = '1' if mime == 'application/vnd.google-apps.folder' else '0'
        size = f.get('size', '0')
        md5 = f.get('md5Checksum', '')
        name = f.get('name', '').replace('\t', ' ')
        fid = f.get('id', '')
        print(f'{is_folder}\t{fid}\t{name}\t{mime}\t{size}\t{md5}')
except:
    pass
" | while IFS=$'\t' read -r is_folder fid fname fmime fsize fmd5; do
        if [[ "$is_folder" == "1" ]]; then
            log "  Crawling subfolder: $path_prefix/$fname"
            crawl_drive_folder "$fid" "$path_prefix/$fname" "$source" $((depth + 1))
        else
            local dup_check=$(check_duplicate "$fname" "$fsize" "$fmd5")
            if [[ "$dup_check" == DUPLICATE* ]]; then
                log "  SKIP (duplicate): $fname"
                echo "{\"action\":\"skip_duplicate\",\"name\":\"$fname\",\"existing\":\"${dup_check#DUPLICATE|}\",\"source\":\"$source\"}" >> "$DEDUP_LOG"
            else
                index_drive_file "$fid" "$fname" "$fmime" "$fsize" "$fmd5" "$path_prefix/$fname" "$folder_id" "$source" "" "" ""
                log "  Indexed: $fname ($fsize bytes)"
            fi
        fi
    done
}

# Main
case "${1:-help}" in
    init)
        init_db
        ;;
    crawl)
        # Crawl a specific Drive folder
        folder_id="${2:?Usage: $0 crawl <folder_id> <path_prefix> <source>}"
        path_prefix="${3:-/}"
        source="${4:-drive}"
        log "Starting crawl: $path_prefix (source: $source)"
        crawl_drive_folder "$folder_id" "$path_prefix" "$source"
        log "Crawl complete."
        ;;
    stats)
        echo "=== Document Vault Index Stats ==="
        sqlite3 "$INDEX_DB" "SELECT 'Total documents:', COUNT(*) FROM documents;"
        sqlite3 "$INDEX_DB" "SELECT 'By source:', source, COUNT(*) FROM documents GROUP BY source;"
        sqlite3 "$INDEX_DB" "SELECT 'Duplicates found:', COUNT(*) FROM duplicates;"
        sqlite3 "$INDEX_DB" "SELECT 'Missing expected:', COUNT(*) FROM expected_documents WHERE status='missing';"
        ;;
    search)
        query="${2:?Usage: $0 search <query>}"
        sqlite3 -header -column "$INDEX_DB" "SELECT name, vault_path, entity, doc_type, doc_year FROM documents WHERE name LIKE '%$query%' OR entity LIKE '%$query%' OR doc_type LIKE '%$query%' LIMIT 20;"
        ;;
    missing)
        sqlite3 -header -column "$INDEX_DB" "SELECT entity_name, doc_type, year, source_hint FROM expected_documents WHERE status='missing' ORDER BY entity_name, year;"
        ;;
    help|*)
        echo "Usage: $0 {init|crawl|stats|search|missing}"
        echo "  init              - Initialize the SQLite index database"
        echo "  crawl <id> <path> <source> - Crawl a Drive folder and index files"
        echo "  stats             - Show index statistics"
        echo "  search <query>    - Search documents by name/entity/type"
        echo "  missing           - Show missing expected documents"
        ;;
esac
