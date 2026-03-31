#!/bin/bash
# AI Mesh Shell Aliases — Installs mesh shortcuts into ~/.zshrc
#
# Usage:
#     bash mesh/install-aliases.sh          # Install aliases
#     bash mesh/install-aliases.sh --remove # Remove aliases

set -euo pipefail

ZSHRC="$HOME/.zshrc"
MESH_DIR="$(cd "$(dirname "$0")" && pwd)"
MARKER_START="# >>> AI Mesh Aliases >>>"
MARKER_END="# <<< AI Mesh Aliases <<<"

ALIASES=$(cat <<'ALIASES_BLOCK'
# >>> AI Mesh Aliases >>>
# Installed by mesh/install-aliases.sh

# Auto-route and execute
mesh() {
    if [ $# -eq 0 ]; then
        echo "Usage: mesh <task>          — auto-route and execute"
        echo "       mesh research <q>    — force research route"
        echo "       mesh code <task>     — force coding route"
        echo "       mesh reason <task>   — force reasoning route"
        echo "       mesh cost            — show today's spend"
        echo "       mesh health          — run health check"
        echo "       mesh stats           — show usage analytics"
        echo "       mesh queue <cmd>     — manage task queue"
        echo "       mesh intercept <t>   — check cost before running"
        echo "       mesh refresh         — refresh capabilities"
        echo "       mesh learn <cmd>     — learning system"
        return 0
    fi

    local MESH_DIR="MESH_DIR_PLACEHOLDER"
    local cmd="$1"
    shift

    case "$cmd" in
        research)
            python3 "$MESH_DIR/dispatch.py" --system perplexity-browser "$*"
            ;;
        code)
            python3 "$MESH_DIR/dispatch.py" --system claude-code "$*"
            ;;
        reason)
            python3 "$MESH_DIR/dispatch.py" --system codex "$*"
            ;;
        cost)
            python3 "$MESH_DIR/cost.py" "$@"
            ;;
        health)
            python3 "$MESH_DIR/health.py" "$@"
            ;;
        stats)
            python3 "$MESH_DIR/stats.py" "$@"
            ;;
        queue)
            python3 "$MESH_DIR/task_queue.py" "$@"
            ;;
        intercept)
            python3 "$MESH_DIR/intercept.py" "$*"
            ;;
        refresh)
            python3 "$MESH_DIR/refresh.py" "$@"
            ;;
        learn)
            python3 "$MESH_DIR/learn.py" "$@"
            ;;
        route)
            python3 "$MESH_DIR/router.py" "$*"
            ;;
        dispatch)
            python3 "$MESH_DIR/dispatch.py" "$@"
            ;;
        add-system)
            python3 "$MESH_DIR/add-system.py" "$@"
            ;;
        *)
            # Auto-route: intercept first, then dispatch
            python3 "$MESH_DIR/intercept.py" "$cmd $*"
            local exit_code=$?
            if [ $exit_code -eq 2 ]; then
                echo ""
                read -p "Proceed anyway? [y/N] " -n 1 -r
                echo
                if [[ ! $REPLY =~ ^[Yy]$ ]]; then
                    echo "[mesh] Aborted. Use the suggested alternative."
                    return 0
                fi
            fi
            python3 "$MESH_DIR/dispatch.py" "$cmd $*"
            ;;
    esac
}

ALIASES_BLOCK
)

remove_aliases() {
    if [ ! -f "$ZSHRC" ]; then
        echo "[mesh] No ~/.zshrc found"
        return
    fi

    if grep -q "$MARKER_START" "$ZSHRC"; then
        # Remove everything between markers (inclusive)
        sed -i.bak "/$MARKER_START/,/$MARKER_END/d" "$ZSHRC"
        rm -f "$ZSHRC.bak"
        echo "[mesh] Aliases removed from ~/.zshrc"
    else
        echo "[mesh] No mesh aliases found in ~/.zshrc"
    fi
}

install_aliases() {
    # Create ~/.zshrc if it doesn't exist
    touch "$ZSHRC"

    # Remove old aliases first
    if grep -q "$MARKER_START" "$ZSHRC"; then
        echo "[mesh] Removing old aliases..."
        remove_aliases
    fi

    # Replace placeholder with actual path
    local final_aliases="${ALIASES//MESH_DIR_PLACEHOLDER/$MESH_DIR}"

    # Append new aliases
    echo "" >> "$ZSHRC"
    echo "$final_aliases" >> "$ZSHRC"
    echo "$MARKER_END" >> "$ZSHRC"

    echo "[mesh] Aliases installed in ~/.zshrc"
    echo "[mesh] Run 'source ~/.zshrc' or open a new terminal to use them."
    echo ""
    echo "Available commands:"
    echo "  mesh 'task'              — auto-route and execute"
    echo "  mesh research 'query'    — force research route"
    echo "  mesh code 'task'         — force coding route"
    echo "  mesh reason 'task'       — force reasoning route"
    echo "  mesh cost                — show today's spend"
    echo "  mesh cost --week         — weekly cost view"
    echo "  mesh cost --month        — monthly cost view"
    echo "  mesh health              — run health check"
    echo "  mesh stats               — show usage analytics"
    echo "  mesh queue add 'task'    — add task to queue"
    echo "  mesh queue list          — show pending tasks"
    echo "  mesh queue run           — process queue"
    echo "  mesh intercept 'task'    — check cost before running"
    echo "  mesh refresh             — refresh capabilities"
    echo "  mesh learn analyze       — show learning analysis"
}

# Main
if [ "${1:-}" = "--remove" ]; then
    remove_aliases
else
    install_aliases
fi
