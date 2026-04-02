#!/usr/bin/env bash
# corrections.sh — Log agent corrections for feedback loops
# Usage: 
#   bash scripts/corrections.sh log <agent> <category> "<what_happened>" "<correction>"
#   bash scripts/corrections.sh list [agent]
#   bash scripts/corrections.sh stats
#   bash scripts/corrections.sh inject <agent>  → outputs correction context for delegation prompts
#
# Categories: tone, accuracy, scope, format, judgment, safety

set -euo pipefail

WORKSPACE="/Users/meircohen/.openclaw/workspace"
CORRECTIONS_DIR="$WORKSPACE/shared/corrections"
mkdir -p "$CORRECTIONS_DIR"

ACTION="${1:-help}"

case "$ACTION" in
  log)
    AGENT="${2:?Usage: corrections.sh log <agent> <category> <what> <correction>}"
    CATEGORY="${3:?Missing category (tone|accuracy|scope|format|judgment|safety)}"
    WHAT="${4:?Missing description of what happened}"
    CORRECTION="${5:?Missing the correction/fix}"
    
    FILE="$CORRECTIONS_DIR/${AGENT}.jsonl"
    ENTRY=$(jq -cn \
      --arg agent "$AGENT" \
      --arg category "$CATEGORY" \
      --arg what "$WHAT" \
      --arg correction "$CORRECTION" \
      --arg ts "$(date -u +"%Y-%m-%dT%H:%M:%SZ")" \
      '{timestamp: $ts, agent: $agent, category: $category, what: $what, correction: $correction}')
    
    echo "$ENTRY" >> "$FILE"
    
    # Also append to the agent's human-readable corrections.md
    AGENT_MD="$CORRECTIONS_DIR/${AGENT}.md"
    if [[ ! -f "$AGENT_MD" ]]; then
      cat > "$AGENT_MD" << EOF
# Corrections: ${AGENT}
*Auto-generated feedback log. Injected into delegation prompts.*

EOF
    fi
    
    echo "- **$(date +%Y-%m-%d)** [${CATEGORY}]: ${WHAT} → **Fix:** ${CORRECTION}" >> "$AGENT_MD"
    echo "Logged correction for ${AGENT} (${CATEGORY})"
    ;;
    
  list)
    AGENT="${2:-}"
    if [[ -n "$AGENT" ]]; then
      cat "$CORRECTIONS_DIR/${AGENT}.md" 2>/dev/null || echo "No corrections for $AGENT"
    else
      for f in "$CORRECTIONS_DIR"/*.md; do
        [[ -f "$f" ]] || continue
        echo "=== $(basename "$f" .md) ==="
        tail -5 "$f"
        echo ""
      done
    fi
    ;;
    
  stats)
    echo "=== Correction Stats ==="
    for f in "$CORRECTIONS_DIR"/*.jsonl; do
      [[ -f "$f" ]] || continue
      AGENT=$(basename "$f" .jsonl)
      TOTAL=$(wc -l < "$f" | tr -d ' ')
      CATS=$(while IFS= read -r line; do echo "$line" | jq -r '.category // empty' 2>/dev/null; done < "$f" | sort | uniq -c | sort -rn | head -3 | awk '{print $2"("$1")"}' | tr '\n' ', ' | sed 's/,$//')
      echo "  ${AGENT}: ${TOTAL} corrections — top: ${CATS}"
    done
    ;;
    
  inject)
    # Output correction context suitable for injection into a delegation prompt
    AGENT="${2:?Usage: corrections.sh inject <agent>}"
    FILE="$CORRECTIONS_DIR/${AGENT}.jsonl"
    if [[ ! -f "$FILE" ]]; then
      echo "# No prior corrections for this agent"
      exit 0
    fi
    
    # Get last 10 corrections (most recent = most relevant)
    echo "## Prior Corrections (DO NOT REPEAT)"
    echo ""
    tail -10 "$FILE" | while IFS= read -r line; do
      [[ -z "$line" ]] && continue
      CAT=$(echo "$line" | jq -r '.category // "unknown"' 2>/dev/null) || continue
      WHAT=$(echo "$line" | jq -r '.what // "?"' 2>/dev/null)
      FIX=$(echo "$line" | jq -r '.correction // "?"' 2>/dev/null)
      echo "- [${CAT}] ${WHAT} → ${FIX}"
    done
    ;;
    
  help|*)
    echo "Usage:"
    echo "  corrections.sh log <agent> <category> <what> <correction>"
    echo "  corrections.sh list [agent]"
    echo "  corrections.sh stats"
    echo "  corrections.sh inject <agent>"
    echo ""
    echo "Categories: tone, accuracy, scope, format, judgment, safety"
    ;;
esac
