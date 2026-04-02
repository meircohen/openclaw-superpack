#!/bin/bash
# vault-dashboard.sh — Cohen Document Vault Dashboard
# Shows key metrics, coverage, missing docs, and compliance deadlines

DB="$HOME/.openclaw/workspace/state/vault/document-vault-index.db"
CALENDAR="$HOME/.openclaw/workspace/config/financial/compliance-calendar.json"

echo "╔══════════════════════════════════════════════════════════╗"
echo "║            COHEN DOCUMENT VAULT — DASHBOARD             ║"
echo "╠══════════════════════════════════════════════════════════╣"
echo "║  Generated: $(date '+%Y-%m-%d %H:%M')                          ║"
echo "╚══════════════════════════════════════════════════════════╝"
echo ""

# Overall stats
echo "── VAULT STATISTICS ──────────────────────────────────────"
sqlite3 "$DB" "
SELECT
  (SELECT COUNT(*) FROM documents) as total_docs,
  (SELECT COUNT(*) FROM documents WHERE entity IS NOT NULL AND entity != '') as with_entity,
  (SELECT COUNT(*) FROM documents WHERE doc_type IS NOT NULL AND doc_type != '') as with_type,
  (SELECT COUNT(*) FROM documents WHERE doc_year IS NOT NULL AND doc_year != '' AND doc_year != '0') as with_year,
  (SELECT COUNT(*) FROM documents WHERE drive_id IS NOT NULL AND drive_id != '') as on_drive,
  (SELECT COUNT(*) FROM documents_fts) as fts_indexed,
  (SELECT COUNT(*) FROM entities) as entities;
" | awk -F'|' '{
  printf "  Total documents:     %s\n", $1
  printf "  With entity tag:     %s (%d%%)\n", $2, ($2/$1)*100
  printf "  With doc type:       %s (%d%%)\n", $3, ($3/$1)*100
  printf "  With year:           %s (%d%%)\n", $4, ($4/$1)*100
  printf "  On Google Drive:     %s (%d%%)\n", $5, ($5/$1)*100
  printf "  FTS5 searchable:     %s\n", $6
  printf "  Entities tracked:    %s\n", $7
}'
echo ""

# Entity coverage
echo "── ENTITY COVERAGE (Expected Documents) ────────────────"
sqlite3 -header -column "$DB" "
SELECT
  entity_name as Entity,
  SUM(CASE WHEN status='found' THEN 1 ELSE 0 END) as Found,
  SUM(CASE WHEN status='missing' THEN 1 ELSE 0 END) as Missing,
  COUNT(*) as Total,
  ROUND(100.0 * SUM(CASE WHEN status='found' THEN 1 ELSE 0 END) / COUNT(*), 0) || '%' as Coverage
FROM expected_documents
GROUP BY entity_name
ORDER BY Coverage DESC
LIMIT 20;
"
echo ""

# Critical missing
echo "── CRITICAL MISSING DOCUMENTS ──────────────────────────"
sqlite3 -column "$DB" "
SELECT entity_name || ': ' || doc_type || COALESCE(' (' || year || ')', '') || ' — ' || COALESCE(source_hint, '?') as missing
FROM expected_documents
WHERE status = 'missing'
AND doc_type IN ('1065 Tax Return', '1040 Tax Return', '1041 Trust Return', 'Operating Agreement', 'K-1 (received)', 'Certificate of Formation')
ORDER BY entity_name, doc_type, year
LIMIT 25;
"
echo ""

# Recent uploads (last 7 days)
echo "── RECENT UPLOADS (last 7 days) ────────────────────────"
sqlite3 -column "$DB" "
SELECT name, entity, doc_type
FROM documents
WHERE uploaded_at >= datetime('now', '-7 days')
   OR indexed_at >= datetime('now', '-7 days')
ORDER BY COALESCE(uploaded_at, indexed_at) DESC
LIMIT 10;
"
echo ""

# Compliance deadlines
echo "── COMPLIANCE DEADLINES (next 60 days) ─────────────────"
if [ -f "$CALENDAR" ]; then
    python3 -c "
import json, datetime
today = datetime.date.today()
cutoff = today + datetime.timedelta(days=60)
with open('$CALENDAR') as f:
    cal = json.load(f)
for d in sorted(cal.get('deadlines', cal if isinstance(cal, list) else []), key=lambda x: x.get('due_date', '')):
    due = d.get('due_date', '')
    if due:
        due_date = datetime.date.fromisoformat(due)
        if due_date <= cutoff:
            urgency = 'PAST DUE' if due_date < today else ('THIS WEEK' if (due_date - today).days <= 7 else '')
            entity = d.get('entity', '')
            filing = d.get('filing_type', d.get('type', ''))
            print(f'  {due}  {entity:30s}  {filing:25s}  {urgency}')
" 2>/dev/null
else
    echo "  (no compliance calendar found)"
fi
echo ""
echo "── END ──────────────────────────────────────────────────"
