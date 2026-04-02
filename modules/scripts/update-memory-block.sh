#!/bin/bash
# Update a specific memory block
# Usage: update-memory-block.sh <block_name> <content_or_file>

set -euo pipefail

WORKSPACE="$HOME/.openclaw/workspace"
BLOCKS_DIR="$WORKSPACE/memory/blocks"

if [ $# -lt 2 ]; then
    echo "Usage: $0 <block_name> <content_or_file>"
    echo ""
    echo "Available blocks:"
    ls -1 "$BLOCKS_DIR" | sed 's/\.md$//'
    exit 1
fi

BLOCK_NAME="$1"
BLOCK_FILE="$BLOCKS_DIR/$BLOCK_NAME.md"
INPUT="$2"

# Check if input is a file or content
if [ -f "$INPUT" ]; then
    CONTENT=$(cat "$INPUT")
else
    CONTENT="$INPUT"
fi

# Update block
echo "# ${BLOCK_NAME//_/ }" > "$BLOCK_FILE"
echo "**Last Updated:** $(date +%Y-%m-%d\ %H:%M\ EST)" >> "$BLOCK_FILE"
echo "" >> "$BLOCK_FILE"
echo "$CONTENT" >> "$BLOCK_FILE"

echo "✅ Updated $BLOCK_NAME"
echo "   File: $BLOCK_FILE"

# Regenerate summary
echo "  📄 Regenerating MEMORY.summary.md..."
cat > "$WORKSPACE/MEMORY.summary.md" << EOF
# MEMORY — Curated Long-Term Memory
*Generated from blocks: $(date +%Y-%m-%d\ %H:%M\ EST)*

This file is auto-generated from structured memory blocks in \`memory/blocks/\`.
For full detail, see individual block files.

---

EOF

for block in "$BLOCKS_DIR"/*.md; do
    cat "$block" >> "$WORKSPACE/MEMORY.summary.md"
    echo "" >> "$WORKSPACE/MEMORY.summary.md"
    echo "---" >> "$WORKSPACE/MEMORY.summary.md"
    echo "" >> "$WORKSPACE/MEMORY.summary.md"
done

echo "✅ Summary regenerated"
