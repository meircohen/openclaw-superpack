#!/bin/bash
# Memory Block Injection System
# Injects memory blocks before first user prompt, diffs on subsequent prompts

set -euo pipefail

WORKSPACE="$HOME/.openclaw/workspace"
BLOCKS_DIR="$WORKSPACE/memory/blocks"
STATE_DIR="$WORKSPACE/.memory-state"
SESSION_FILE="$STATE_DIR/last-session.txt"
SNAPSHOT_DIR="$STATE_DIR/snapshots"

# Create state directories
mkdir -p "$STATE_DIR" "$SNAPSHOT_DIR"

# Get current session ID (or generate one)
SESSION_ID="${SESSION_ID:-$(date +%s)}"
IS_FIRST_PROMPT="${IS_FIRST_PROMPT:-true}"

# Check if this is truly the first prompt of the session
if [ -f "$SESSION_FILE" ]; then
    LAST_SESSION=$(cat "$SESSION_FILE")
    if [ "$LAST_SESSION" = "$SESSION_ID" ]; then
        IS_FIRST_PROMPT="false"
    fi
fi

# Save current session
echo "$SESSION_ID" > "$SESSION_FILE"

inject_all_blocks() {
    echo "<memory_blocks>"
    echo "<meta>Oz's persistent memory across sessions. Last updated: $(date)</meta>"
    echo ""
    
    for block in "$BLOCKS_DIR"/*.md; do
        block_name=$(basename "$block" .md)
        echo "<$block_name>"
        cat "$block"
        echo "</$block_name>"
        echo ""
    done
    
    echo "</memory_blocks>"
    
    # Save snapshot for future diffs
    tar czf "$SNAPSHOT_DIR/$SESSION_ID.tar.gz" -C "$BLOCKS_DIR" .
}

inject_diffs() {
    # Find last snapshot
    LAST_SNAPSHOT=$(ls -t "$SNAPSHOT_DIR"/*.tar.gz 2>/dev/null | head -1 || echo "")
    
    if [ -z "$LAST_SNAPSHOT" ]; then
        # No snapshot, inject all
        inject_all_blocks
        return
    fi
    
    # Extract last snapshot to temp dir
    TEMP_DIR=$(mktemp -d)
    tar xzf "$LAST_SNAPSHOT" -C "$TEMP_DIR"
    
    # Find changes
    CHANGES_FOUND=false
    DIFF_OUTPUT="<memory_update>"
    DIFF_OUTPUT="$DIFF_OUTPUT\n<meta>Memory changes since last session</meta>\n"
    
    for block in "$BLOCKS_DIR"/*.md; do
        block_name=$(basename "$block" .md)
        old_block="$TEMP_DIR/$block_name.md"
        
        if [ ! -f "$old_block" ]; then
            # New block
            DIFF_OUTPUT="$DIFF_OUTPUT\n<$block_name status=\"new\">"
            DIFF_OUTPUT="$DIFF_OUTPUT\n$(cat "$block")"
            DIFF_OUTPUT="$DIFF_OUTPUT\n</$block_name>\n"
            CHANGES_FOUND=true
        elif ! diff -q "$block" "$old_block" >/dev/null 2>&1; then
            # Modified block - show diff
            DIFF_OUTPUT="$DIFF_OUTPUT\n<$block_name status=\"modified\">"
            DIFF_OUTPUT="$DIFF_OUTPUT\n$(diff -u "$old_block" "$block" | tail -n +3 | head -20)"
            DIFF_OUTPUT="$DIFF_OUTPUT\n</$block_name>\n"
            CHANGES_FOUND=true
        fi
    done
    
    DIFF_OUTPUT="$DIFF_OUTPUT\n</memory_update>"
    
    # Clean up
    rm -rf "$TEMP_DIR"
    
    if [ "$CHANGES_FOUND" = "true" ]; then
        echo -e "$DIFF_OUTPUT"
        # Save new snapshot
        tar czf "$SNAPSHOT_DIR/$SESSION_ID.tar.gz" -C "$BLOCKS_DIR" .
    else
        echo "<memory_update><meta>No changes since last session</meta></memory_update>"
    fi
}

# Main logic
if [ "$IS_FIRST_PROMPT" = "true" ]; then
    inject_all_blocks
else
    inject_diffs
fi
