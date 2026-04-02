#!/usr/bin/env bash
# VAULT INTELLIGENCE UPGRADE 5: Intelligent Orchestrator
#
# Single command to run all vault intelligence modules.
# Designed for scheduled execution (daily/weekly) or manual runs.
#
# Usage:
#   ./vault-intelligence.sh              # Run all modules
#   ./vault-intelligence.sh --quick      # Status-only (no Drive changes)
#   ./vault-intelligence.sh --module X   # Run specific module (enrich|compliance|autofile|views)
#   ./vault-intelligence.sh --dry-run    # Preview all changes
#   ./vault-intelligence.sh --help
#
# Modules (run in order):
#   1. enrich     - Fill missing metadata (year, doc_type, category)
#   2. compliance - Generate compliance digest with deadlines
#   3. autofile   - Classify and route new inbox docs
#   4. views      - Rebuild role-based Drive views (CPA, Family, Attorney)

set -euo pipefail

WORKSPACE="$HOME/.openclaw/workspace"
SCRIPTS="$WORKSPACE/scripts"
STATE="$WORKSPACE/state"
LOG_DIR="$STATE/intelligence-logs"
TIMESTAMP=$(date +%Y%m%d-%H%M%S)
LOG_FILE="$LOG_DIR/run-$TIMESTAMP.log"

# Parse args
DRY_RUN=""
QUICK=""
MODULE=""
VERBOSE=""

while [[ $# -gt 0 ]]; do
    case $1 in
        --dry-run)  DRY_RUN="--dry-run"; shift ;;
        --quick)    QUICK=1; shift ;;
        --verbose)  VERBOSE="--verbose"; shift ;;
        --module)   MODULE="$2"; shift 2 ;;
        --help)
            head -16 "$0" | tail -14
            exit 0
            ;;
        *)  echo "Unknown arg: $1"; exit 1 ;;
    esac
done

# Setup
mkdir -p "$LOG_DIR"
cd "$WORKSPACE"

# Logging
log() {
    local msg="[$(date +%H:%M:%S)] $1"
    echo "$msg"
    echo "$msg" >> "$LOG_FILE"
}

run_module() {
    local name="$1"
    local script="$2"
    shift 2
    local args=("$@")

    log "--- MODULE: $name ---"
    local start=$(date +%s)

    if python3 -u "$script" "${args[@]}" >> "$LOG_FILE" 2>&1; then
        local elapsed=$(( $(date +%s) - start ))
        log "  $name completed in ${elapsed}s"
        return 0
    else
        log "  ERROR: $name failed (exit code $?)"
        return 1
    fi
}

# =====================================================
# MAIN
# =====================================================

log "========================================="
log "VAULT INTELLIGENCE SYSTEM"
log "Mode: ${QUICK:+QUICK }${DRY_RUN:+DRY-RUN }${MODULE:+MODULE=$MODULE }${VERBOSE:+VERBOSE}"
log "========================================="

ERRORS=0

# Module 1: Metadata Enrichment
if [[ -z "$MODULE" || "$MODULE" == "enrich" ]]; then
    if [[ -z "$QUICK" ]]; then
        run_module "Metadata Enrichment" "$SCRIPTS/vault-enrich-metadata.py" $DRY_RUN || ((ERRORS++))
    else
        log "--- MODULE: Metadata Enrichment (skipped in quick mode) ---"
    fi
fi

# Module 2: Compliance Digest
if [[ -z "$MODULE" || "$MODULE" == "compliance" ]]; then
    if [[ -n "$QUICK" ]]; then
        run_module "Compliance Digest (status)" "$SCRIPTS/vault-compliance-digest.py" --status-only || ((ERRORS++))
    else
        run_module "Compliance Digest" "$SCRIPTS/vault-compliance-digest.py" $DRY_RUN || ((ERRORS++))
    fi
fi

# Module 3: Auto-Filing
if [[ -z "$MODULE" || "$MODULE" == "autofile" ]]; then
    if [[ -z "$QUICK" ]]; then
        run_module "Auto-Filing Pipeline" "$SCRIPTS/vault-autofile.py" $DRY_RUN $VERBOSE || ((ERRORS++))
    else
        log "--- MODULE: Auto-Filing (skipped in quick mode) ---"
    fi
fi

# Module 4: Role-Based Views
if [[ -z "$MODULE" || "$MODULE" == "views" ]]; then
    if [[ -z "$QUICK" && -z "$DRY_RUN" ]]; then
        run_module "Role-Based Views" "$SCRIPTS/vault-views.py" --update || ((ERRORS++))
    else
        log "--- MODULE: Role-Based Views (skipped in quick/dry-run mode) ---"
    fi
fi

# =====================================================
# SUMMARY
# =====================================================

log ""
log "========================================="
log "VAULT INTELLIGENCE RUN COMPLETE"
log "========================================="

# Quick stats from DB
TOTAL=$(sqlite3 "$STATE/document-vault-index.db" "SELECT COUNT(*) FROM documents")
WITH_ENTITY=$(sqlite3 "$STATE/document-vault-index.db" "SELECT COUNT(*) FROM documents WHERE entity IS NOT NULL AND entity != ''")
WITH_DRIVE=$(sqlite3 "$STATE/document-vault-index.db" "SELECT COUNT(*) FROM documents WHERE drive_id IS NOT NULL AND drive_id != ''")
WITH_CATEGORY=$(sqlite3 "$STATE/document-vault-index.db" "SELECT COUNT(*) FROM documents WHERE category IS NOT NULL AND category != ''")
MISSING_DOCS=$(sqlite3 "$STATE/document-vault-index.db" "SELECT COUNT(*) FROM expected_documents WHERE status = 'missing'" 2>/dev/null || echo "0")
OPEN_ALERTS=$(sqlite3 "$STATE/document-vault-index.db" "SELECT COUNT(*) FROM vault_alerts WHERE status = 'open'" 2>/dev/null || echo "0")

ENT_PCT=$(( WITH_ENTITY * 100 / TOTAL ))
DRV_PCT=$(( WITH_DRIVE * 100 / TOTAL ))
CAT_PCT=$(( WITH_CATEGORY * 100 / TOTAL ))

log "  Documents:     $TOTAL"
log "  Entity:        $ENT_PCT% ($WITH_ENTITY / $TOTAL)"
log "  Drive:         $DRV_PCT% ($WITH_DRIVE / $TOTAL)"
log "  Category:      $CAT_PCT% ($WITH_CATEGORY / $TOTAL)"
log "  Missing docs:  $MISSING_DOCS"
log "  Open alerts:   $OPEN_ALERTS"
log "  Errors:        $ERRORS"
log "  Log:           $LOG_FILE"
log "========================================="

# Check for urgent compliance items
CRITICAL=$(sqlite3 "$STATE/document-vault-index.db" \
    "SELECT COUNT(*) FROM vault_alerts WHERE UPPER(severity) = 'HIGH' AND status = 'open'" 2>/dev/null || echo "0")

if [[ "$CRITICAL" -gt 0 ]]; then
    log ""
    log "⚠  $CRITICAL HIGH-SEVERITY ALERTS OPEN"
    log "   Run: python3 $SCRIPTS/vault-compliance-digest.py"
    log "   View: $WORKSPACE/artifacts/memos/compliance-digest-latest.md"
fi

# Save run metadata
cat > "$STATE/vault-intelligence-last-run.json" << ENDJSON
{
  "timestamp": "$(date -u +%Y-%m-%dT%H:%M:%SZ)",
  "mode": "${QUICK:+quick }${DRY_RUN:+dry-run }${MODULE:-all}",
  "stats": {
    "total_docs": $TOTAL,
    "entity_pct": $ENT_PCT,
    "drive_pct": $DRV_PCT,
    "category_pct": $CAT_PCT,
    "missing_docs": $MISSING_DOCS,
    "open_alerts": $OPEN_ALERTS
  },
  "errors": $ERRORS,
  "log_file": "$LOG_FILE"
}
ENDJSON

exit $ERRORS
