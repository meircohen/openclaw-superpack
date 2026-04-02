#!/usr/bin/env bash
# handoff.sh — Create, pickup, complete, and monitor handoffs between agents/systems
# Usage:
#   bash scripts/handoff.sh create <from> <to> <title> [priority] [deadline]
#   bash scripts/handoff.sh pickup <handoff_file>
#   bash scripts/handoff.sh complete <handoff_file> [notes]
#   bash scripts/handoff.sh list [pending|complete|stale]
#   bash scripts/handoff.sh stale  → check for handoffs pending >48h
#
# Systems: openclaw, claude-code, cowork, codex, meir

set -euo pipefail

WORKSPACE="/Users/meircohen/.openclaw/workspace"
HANDOFF_DIR="$WORKSPACE/shared/handoffs"
mkdir -p "$HANDOFF_DIR"

ACTION="${1:-help}"

case "$ACTION" in
  create)
    FROM="${2:?Usage: handoff.sh create <from> <to> <title> [priority] [deadline]}"
    TO="${3:?Missing target system}"
    TITLE="${4:?Missing title}"
    PRIORITY="${5:-medium}"
    DEADLINE="${6:-}"
    
    SLUG=$(echo "$TITLE" | tr '[:upper:]' '[:lower:]' | tr ' ' '-' | tr -cd 'a-z0-9-' | head -c 40)
    DATE=$(date +%Y-%m-%d)
    FILENAME="${DATE}-${SLUG}.json"
    FILEPATH="$HANDOFF_DIR/$FILENAME"
    
    # Don't overwrite
    if [[ -f "$FILEPATH" ]]; then
      FILEPATH="$HANDOFF_DIR/${DATE}-${SLUG}-$(date +%H%M).json"
      FILENAME=$(basename "$FILEPATH")
    fi
    
    jq -n \
      --arg from "$FROM" \
      --arg to "$TO" \
      --arg title "$TITLE" \
      --arg priority "$PRIORITY" \
      --arg deadline "$DEADLINE" \
      --arg status "pending" \
      --arg created "$(date -u +"%Y-%m-%dT%H:%M:%SZ")" \
      --arg file "$FILENAME" \
      '{
        from: $from,
        to: $to,
        title: $title,
        priority: $priority,
        status: $status,
        created: $created,
        deadline: (if $deadline != "" then $deadline else null end),
        picked_up_at: null,
        completed_at: null,
        context: {},
        files: [],
        notes: ""
      }' > "$FILEPATH"
    
    echo "Created handoff: $FILENAME"
    echo "  From: $FROM → To: $TO"
    echo "  Priority: $PRIORITY"
    [[ -n "$DEADLINE" ]] && echo "  Deadline: $DEADLINE"
    echo "  File: $FILEPATH"
    ;;
    
  pickup)
    FILE="${2:?Usage: handoff.sh pickup <handoff_file>}"
    [[ "$FILE" == */* ]] || FILE="$HANDOFF_DIR/$FILE"
    
    if [[ ! -f "$FILE" ]]; then
      echo "ERROR: Handoff file not found: $FILE" >&2
      exit 1
    fi
    
    STATUS=$(jq -r '.status' "$FILE")
    if [[ "$STATUS" != "pending" ]]; then
      echo "ERROR: Handoff is already ${STATUS}, not pending" >&2
      exit 1
    fi
    
    TMP=$(mktemp)
    jq --arg ts "$(date -u +"%Y-%m-%dT%H:%M:%SZ")" \
      '.status = "in_progress" | .picked_up_at = $ts' "$FILE" > "$TMP" && mv "$TMP" "$FILE"
    
    TITLE=$(jq -r '.title' "$FILE")
    echo "Picked up: $TITLE"
    ;;
    
  complete)
    FILE="${2:?Usage: handoff.sh complete <handoff_file> [notes]}"
    NOTES="${3:-}"
    [[ "$FILE" == */* ]] || FILE="$HANDOFF_DIR/$FILE"
    
    if [[ ! -f "$FILE" ]]; then
      echo "ERROR: Handoff file not found: $FILE" >&2
      exit 1
    fi
    
    TMP=$(mktemp)
    jq --arg ts "$(date -u +"%Y-%m-%dT%H:%M:%SZ")" --arg notes "$NOTES" \
      '.status = "complete" | .completed_at = $ts | .notes = (if $notes != "" then $notes else .notes end)' "$FILE" > "$TMP" && mv "$TMP" "$FILE"
    
    TITLE=$(jq -r '.title' "$FILE")
    echo "Completed: $TITLE"
    ;;
    
  list)
    FILTER="${2:-all}"
    echo "=== Handoffs (${FILTER}) ==="
    
    for f in "$HANDOFF_DIR"/*.json; do
      [[ -f "$f" ]] || continue
      STATUS=$(jq -r '.status' "$f")
      
      case "$FILTER" in
        pending) [[ "$STATUS" != "pending" ]] && continue ;;
        complete) [[ "$STATUS" != "complete" ]] && continue ;;
        stale)
          [[ "$STATUS" != "pending" ]] && continue
          CREATED=$(jq -r '.created' "$f")
          AGE_HOURS=$(( ($(date +%s) - $(date -j -f "%Y-%m-%dT%H:%M:%SZ" "$CREATED" +%s 2>/dev/null || date -d "$CREATED" +%s)) / 3600 ))
          [[ $AGE_HOURS -lt 48 ]] && continue
          ;;
        all) ;;
      esac
      
      TITLE=$(jq -r '.title' "$f")
      FROM=$(jq -r '.from' "$f")
      TO=$(jq -r '.to' "$f")
      PRI=$(jq -r '.priority' "$f")
      echo "  [${STATUS}] ${TITLE} (${FROM}→${TO}) priority:${PRI} — $(basename "$f")"
    done
    ;;
    
  stale)
    FOUND=0
    for f in "$HANDOFF_DIR"/*.json; do
      [[ -f "$f" ]] || continue
      STATUS=$(jq -r '.status' "$f")
      [[ "$STATUS" != "pending" ]] && continue
      
      CREATED=$(jq -r '.created' "$f")
      NOW=$(date +%s)
      THEN=$(date -j -f "%Y-%m-%dT%H:%M:%SZ" "$CREATED" +%s 2>/dev/null || date -d "$CREATED" +%s 2>/dev/null || echo "$NOW")
      AGE_HOURS=$(( (NOW - THEN) / 3600 ))
      
      if [[ $AGE_HOURS -ge 48 ]]; then
        TITLE=$(jq -r '.title' "$f")
        FROM=$(jq -r '.from' "$f")
        TO=$(jq -r '.to' "$f")
        echo "⚠️  STALE (${AGE_HOURS}h): ${TITLE} (${FROM}→${TO}) — $(basename "$f")"
        FOUND=$((FOUND + 1))
      fi
    done
    
    if [[ $FOUND -eq 0 ]]; then
      echo "No stale handoffs"
    else
      echo "${FOUND} stale handoff(s) found"
      exit 1
    fi
    ;;
    
  help|*)
    echo "Usage:"
    echo "  handoff.sh create <from> <to> <title> [priority] [deadline]"
    echo "  handoff.sh pickup <handoff_file>"
    echo "  handoff.sh complete <handoff_file> [notes]"
    echo "  handoff.sh list [pending|complete|stale|all]"
    echo "  handoff.sh stale"
    ;;
esac
