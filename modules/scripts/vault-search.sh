#!/bin/bash
# vault-search.sh — Smart search across the Cohen Document Vault
# Usage: vault-search.sh "query" [--entity X] [--type X] [--year YYYY]

DB="$HOME/.openclaw/workspace/state/vault/document-vault-index.db"

if [ -z "$1" ]; then
    echo "Usage: vault-search.sh \"query\" [--entity X] [--type X] [--year YYYY]"
    echo ""
    echo "Examples:"
    echo "  vault-search.sh \"K-1 ZettaPOW\""
    echo "  vault-search.sh \"operating agreement\" --entity \"Disrupt Ventures\""
    echo "  vault-search.sh \"tax return\" --year 2023"
    exit 1
fi

QUERY="$1"
shift

ENTITY_FILTER=""
TYPE_FILTER=""
YEAR_FILTER=""

while [[ $# -gt 0 ]]; do
    case "$1" in
        --entity) ENTITY_FILTER="$2"; shift 2 ;;
        --type) TYPE_FILTER="$2"; shift 2 ;;
        --year) YEAR_FILTER="$2"; shift 2 ;;
        *) shift ;;
    esac
done

# Build WHERE clauses for metadata filters
META_WHERE=""
if [ -n "$ENTITY_FILTER" ]; then
    META_WHERE="$META_WHERE AND d.entity LIKE '%${ENTITY_FILTER}%'"
fi
if [ -n "$TYPE_FILTER" ]; then
    META_WHERE="$META_WHERE AND d.doc_type LIKE '%${TYPE_FILTER}%'"
fi
if [ -n "$YEAR_FILTER" ]; then
    META_WHERE="$META_WHERE AND d.doc_year = '${YEAR_FILTER}'"
fi

# Try FTS5 first
FTS_RESULTS=$(sqlite3 -header -column "$DB" "
SELECT d.name, d.entity, d.doc_type, d.doc_year,
       CASE WHEN d.drive_id IS NOT NULL AND d.drive_id != ''
            THEN 'https://drive.google.com/file/d/' || d.drive_id || '/view'
            ELSE '(local only)' END as link
FROM documents_fts f
JOIN documents d ON d.id = CAST(f.doc_id AS INTEGER)
WHERE documents_fts MATCH '${QUERY}' ${META_WHERE}
ORDER BY rank
LIMIT 20;
" 2>/dev/null)

if [ -n "$FTS_RESULTS" ]; then
    echo "=== Full-Text Search Results ==="
    echo "$FTS_RESULTS"
else
    # Fallback to LIKE search on name
    echo "=== Name Search Results ==="
    sqlite3 -header -column "$DB" "
    SELECT d.name, d.entity, d.doc_type, d.doc_year,
           CASE WHEN d.drive_id IS NOT NULL AND d.drive_id != ''
                THEN 'https://drive.google.com/file/d/' || d.drive_id || '/view'
                ELSE '(local only)' END as link
    FROM documents d
    WHERE d.name LIKE '%${QUERY}%' ${META_WHERE}
    ORDER BY d.name
    LIMIT 20;
    "
fi
