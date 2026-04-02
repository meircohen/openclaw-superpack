#!/bin/bash
# Monitor for responses related to Brookfield plans retrieval

export GOG_ACCOUNT=meircohen@gmail.com
RESULTS_DIR="/Users/meircohen/.openclaw/workspace/brookfield-plans-results"
mkdir -p "$RESULTS_DIR"

echo "📧 Monitoring for Brookfield plans responses..."

# Check for responses from key contacts
check_responses() {
    local contact=$1
    local label=$2
    
    echo "Checking: $label ($contact)..."
    
    # Search last 7 days
    gog gmail search "from:$contact newer_than:7d" --limit 5 > "$RESULTS_DIR/responses-$label.txt" 2>&1
    
    if [ -s "$RESULTS_DIR/responses-$label.txt" ]; then
        echo "✅ Found messages from $label"
        # Check if any have attachments (likely PDFs)
        if grep -q "attachment" "$RESULTS_DIR/responses-$label.txt" 2>/dev/null; then
            echo "🎯 ATTACHMENT FOUND from $label - downloading..."
            # Extract message IDs and download attachments
            grep "ID" "$RESULTS_DIR/responses-$label.txt" | while read -r line; do
                msg_id=$(echo "$line" | awk '{print $1}')
                gog gmail read "$msg_id" --json > "$RESULTS_DIR/message-$msg_id.json" 2>&1
            done
        fi
    else
        echo "⏳ No response yet from $label"
    fi
}

# Monitor key contacts
check_responses "Gcarbonell@gjcarch.com" "architect"
check_responses "ari@peakrealtor.net" "realtor"
check_responses "*@mg3*" "mg3-developer"
check_responses "*@brookman*" "brookman-fels"
check_responses "*title*" "title-company"

# Search for any email with keywords
echo ""
echo "🔍 Searching for landscape/survey related emails..."
gog gmail search "landscape OR survey OR planting OR site plan subject:(brookfield OR preserve)" newer_than:7d --limit 10 \
    > "$RESULTS_DIR/keyword-search.txt" 2>&1

# Check for HOA communications
echo "🏘️  Checking for HOA communications..."
gog gmail search "from:*@preserve* OR from:*association* subject:(brookfield OR 5756)" newer_than:30d --limit 10 \
    > "$RESULTS_DIR/hoa-search.txt" 2>&1

echo ""
echo "✅ Monitoring complete!"
echo "📁 Results saved to: $RESULTS_DIR"

# Summary
total_responses=$(find "$RESULTS_DIR" -name "responses-*.txt" -type f 2>/dev/null | wc -l | tr -d ' ')
echo "📊 Checked $total_responses contact categories"

# Check if we found anything actionable
if grep -q "attachment" "$RESULTS_DIR"/responses-*.txt 2>/dev/null; then
    echo "🎉 ATTACHMENTS FOUND - Check $RESULTS_DIR for downloaded files"
    exit 0
elif grep -q "ID" "$RESULTS_DIR"/responses-*.txt 2>/dev/null; then
    echo "📩 Responses found but no attachments yet"
    exit 1
else
    echo "⏳ Still waiting for responses"
    exit 2
fi
