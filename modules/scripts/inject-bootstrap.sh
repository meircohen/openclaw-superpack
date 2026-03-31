#!/bin/bash
# Inject mesh bootstrap rules into each system's config/context files.
#
# Usage:
#     bash mesh/inject-bootstrap.sh              # Inject all
#     bash mesh/inject-bootstrap.sh --dry-run    # Show what would be injected
#     bash mesh/inject-bootstrap.sh --remove     # Remove injected rules

set -euo pipefail

MESH_DIR="$(cd "$(dirname "$0")" && pwd)"
BOOTSTRAP_DIR="$MESH_DIR/bootstrap"
WORKSPACE="$(dirname "$MESH_DIR")"
HOME_DIR="$HOME"

MARKER_START="<!-- MESH BOOTSTRAP START -->"
MARKER_END="<!-- MESH BOOTSTRAP END -->"

DRY_RUN=false
REMOVE=false

if [ "${1:-}" = "--dry-run" ]; then
    DRY_RUN=true
elif [ "${1:-}" = "--remove" ]; then
    REMOVE=true
fi

inject_file() {
    local source="$1"
    local target="$2"
    local label="$3"

    if [ ! -f "$source" ]; then
        echo "  [skip] Source not found: $source"
        return
    fi

    if [ ! -f "$target" ]; then
        echo "  [skip] Target not found: $target"
        return
    fi

    if $REMOVE; then
        if grep -q "$MARKER_START" "$target"; then
            sed -i.bak "/$MARKER_START/,/$MARKER_END/d" "$target"
            rm -f "$target.bak"
            echo "  [removed] $label from $target"
        else
            echo "  [skip] No mesh bootstrap in $target"
        fi
        return
    fi

    if $DRY_RUN; then
        echo "  [would inject] $label -> $target"
        return
    fi

    # Remove old injection first
    if grep -q "$MARKER_START" "$target"; then
        sed -i.bak "/$MARKER_START/,/$MARKER_END/d" "$target"
        rm -f "$target.bak"
    fi

    # Append bootstrap content
    {
        echo ""
        echo "$MARKER_START"
        cat "$source"
        echo ""
        echo "$MARKER_END"
    } >> "$target"

    echo "  [injected] $label -> $target"
}

echo "[inject-bootstrap] AI Mesh Bootstrap Injection"
echo ""

# 1. Claude Code -- inject into workspace CLAUDE.md or ~/.claude/CLAUDE.md
CLAUDE_TARGETS=(
    "$HOME_DIR/.claude/CLAUDE.md"
)
for target in "${CLAUDE_TARGETS[@]}"; do
    if [ -f "$target" ]; then
        inject_file "$BOOTSTRAP_DIR/CLAUDE-CODE-MESH.md" "$target" "Claude Code mesh awareness"
        break
    fi
done

# 2. Codex -- inject into ~/.codex/instructions.md if it exists
CODEX_TARGET="$HOME_DIR/.codex/instructions.md"
if [ -f "$CODEX_TARGET" ]; then
    inject_file "$BOOTSTRAP_DIR/CODEX-MESH.md" "$CODEX_TARGET" "Codex mesh awareness"
else
    echo "  [info] Codex instructions file not found at $CODEX_TARGET"
    echo "         Create it and re-run, or manually add mesh/bootstrap/CODEX-MESH.md"
fi

# 3. Gemini -- inject into ~/.gemini/instructions.md if it exists
GEMINI_TARGET="$HOME_DIR/.gemini/GEMINI.md"
if [ -f "$GEMINI_TARGET" ]; then
    inject_file "$BOOTSTRAP_DIR/GEMINI-MESH.md" "$GEMINI_TARGET" "Gemini mesh awareness"
else
    # Try alternative paths
    for alt in "$HOME_DIR/.gemini/instructions.md" "$HOME_DIR/.gemini/system.md"; do
        if [ -f "$alt" ]; then
            inject_file "$BOOTSTRAP_DIR/GEMINI-MESH.md" "$alt" "Gemini mesh awareness"
            break
        fi
    done
    echo "  [info] Gemini instructions file not found"
    echo "         Create ~/.gemini/GEMINI.md and re-run, or manually add mesh/bootstrap/GEMINI-MESH.md"
fi

# 4. Orchestrator -- inject rules into shared context
ORCHESTRATOR_TARGETS=(
    "$WORKSPACE/shared/ROUTING.md"
    "$WORKSPACE/shared/DECISIONS.md"
)
for target in "${ORCHESTRATOR_TARGETS[@]}"; do
    if [ -f "$target" ]; then
        inject_file "$BOOTSTRAP_DIR/OPENCLAW-MESH-RULES.md" "$target" "Orchestrator mesh rules"
        break
    fi
done

echo ""
if $DRY_RUN; then
    echo "[inject-bootstrap] Dry run complete. No files were modified."
elif $REMOVE; then
    echo "[inject-bootstrap] Removal complete."
else
    echo "[inject-bootstrap] Injection complete."
    echo "  Each system will now be aware of the mesh on next startup."
fi
