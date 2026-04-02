#!/bin/bash
# Daily Memory Maintenance
# Run once per day (first heartbeat after 8am)
# Reviews daily notes → updates memory blocks

set -euo pipefail

WORKSPACE="$HOME/.openclaw/workspace"
BLOCKS_DIR="$WORKSPACE/memory/blocks"
DAILY_DIR="$WORKSPACE/memory"

# Get yesterday's date
YESTERDAY=$(date -v-1d +%Y-%m-%d 2>/dev/null || date -d '1 day ago' +%Y-%m-%d)
YESTERDAY_FILE="$DAILY_DIR/$YESTERDAY.md"

echo "🔄 Daily Memory Maintenance for $YESTERDAY"
echo ""

if [ ! -f "$YESTERDAY_FILE" ]; then
    echo "⚠️  No daily notes found for $YESTERDAY"
    echo "   File expected: $YESTERDAY_FILE"
    exit 0
fi

# Check file size
FILE_SIZE=$(wc -c < "$YESTERDAY_FILE")
if [ "$FILE_SIZE" -lt 100 ]; then
    echo "⚠️  Daily notes too small ($FILE_SIZE bytes) - skipping"
    exit 0
fi

echo "📄 Processing daily notes ($FILE_SIZE bytes)"
echo ""

# Extract completed tasks
echo "✅ Extracting completions..."
COMPLETIONS=$(grep -E "(✅|DEPLOYED|complete|implemented|built)" "$YESTERDAY_FILE" | head -10 || echo "")

if [ -n "$COMPLETIONS" ]; then
    echo "Found completions:"
    echo "$COMPLETIONS" | sed 's/^/  - /'
    echo ""
    
    # Append to active_guidance Recent Completions
    echo "  → Updating active_guidance..."
    TEMP_FILE=$(mktemp)
    
    # Read current active_guidance
    cat "$BLOCKS_DIR/active_guidance.md" > "$TEMP_FILE"
    
    # If no Recent Completions section, add it
    if ! grep -q "## Recent Completions" "$TEMP_FILE"; then
        echo "" >> "$TEMP_FILE"
        echo "## Recent Completions" >> "$TEMP_FILE"
    fi
    
    # Add new completions
    echo "$COMPLETIONS" | while read -r line; do
        if [ -n "$line" ]; then
            # Clean up line (remove markdown, timestamps)
            CLEAN_LINE=$(echo "$line" | sed 's/^[*-] //; s/^###\? //; s/ ([0-9:-]* [AP]M)//')
            echo "- $CLEAN_LINE ($YESTERDAY)" >> "$TEMP_FILE"
        fi
    done
    
    # Update block
    cat > /tmp/active_guidance_update.txt << EOF
$(grep -A 999 "^##" "$TEMP_FILE" | grep -v "^# Active")
EOF
    bash "$WORKSPACE/scripts/update-memory-block.sh" active_guidance /tmp/active_guidance_update.txt
fi

# Extract new patterns
echo ""
echo "🔍 Scanning for new patterns..."
NEW_PATTERNS=$(grep -iE "(pattern|learned|discovered|found that)" "$YESTERDAY_FILE" | head -5 || echo "")

if [ -n "$NEW_PATTERNS" ]; then
    echo "Found patterns:"
    echo "$NEW_PATTERNS" | sed 's/^/  - /'
    echo ""
    echo "  → Consider updating session_patterns.md or preferences.md manually"
fi

# Move completed items from pending to recent
echo ""
echo "📋 Checking pending items..."
if [ -f "$BLOCKS_DIR/pending_items.md" ]; then
    ACTIVE_TASKS=$(sed -n '/^## Active Tasks/,/^##/p' "$BLOCKS_DIR/pending_items.md" | grep "^-" || echo "")
    
    if [ -n "$ACTIVE_TASKS" ]; then
        echo "Active tasks:"
        echo "$ACTIVE_TASKS" | sed 's/^/  /'
        
        # Check if any are marked complete in yesterday's notes
        while read -r task; do
            TASK_NAME=$(echo "$task" | sed 's/^- //' | sed 's/ (.*)//')
            if grep -qi "$TASK_NAME.*✅\|$TASK_NAME.*complete\|$TASK_NAME.*deployed" "$YESTERDAY_FILE"; then
                echo "  → Found completed: $TASK_NAME"
            fi
        done <<< "$ACTIVE_TASKS"
    fi
fi

# Check for new tools added
echo ""
echo "🔧 Checking for new tools..."
NEW_TOOLS=$(grep -iE "(installed|added.*tool|new.*cli)" "$YESTERDAY_FILE" | head -3 || echo "")

if [ -n "$NEW_TOOLS" ]; then
    echo "Found new tools:"
    echo "$NEW_TOOLS" | sed 's/^/  - /'
    echo ""
    echo "  → Consider updating tool_usage.md with decision tree entry"
fi

echo ""
echo "✅ Daily maintenance complete"
echo ""
echo "📊 Memory block status:"
ls -lh "$BLOCKS_DIR" | tail -n +2 | awk '{printf "  %-25s %8s\n", $9, $5}'
