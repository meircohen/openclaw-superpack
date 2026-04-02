#!/bin/bash
# X Engagement Monitor
# Watches key accounts for reply opportunities

set -o pipefail

WORKSPACE="$HOME/.openclaw/workspace"
TMP_DIR="/tmp/x-engagement-$$"
mkdir -p "$TMP_DIR"

# Cleanup on exit
trap "rm -rf $TMP_DIR" EXIT

# Key accounts to monitor
KEY_ACCOUNTS=(
    "libsoftiktok"
    "Awesome_Jew_"
    "smartviewai"
    "NotPhilSledge"
    "CRISPRKING"
)

# Keywords that trigger engagement opportunity
TECH_KEYWORDS=("AI" "tech" "data center" "censorship" "coding" "developer" "Israel" "Iran" "Bitcoin" "crypto" "mining")

echo "🔍 Scanning key accounts for engagement opportunities..."

for ACCOUNT in "${KEY_ACCOUNTS[@]}"; do
    echo "  Checking @$ACCOUNT..."
    
    # Get recent timeline - save to file to avoid subshell weirdness
    /Users/meircohen/Library/Python/3.9/bin/twitter user-posts "$ACCOUNT" --max 5 --json > "$TMP_DIR/${ACCOUNT}.json" 2>/dev/null || {
        echo "    ⚠️  Failed to fetch timeline, skipping..."
        continue
    }
    
    # Check for tech keywords
    for KEYWORD in "${TECH_KEYWORDS[@]}"; do
        if grep -qi "$KEYWORD" "$TMP_DIR/${ACCOUNT}.json"; then
            echo "    ✨ Found '$KEYWORD' mention in @$ACCOUNT timeline"
            
            # Extract matching tweet content
            grep -i "$KEYWORD" -A 5 -B 2 "$TMP_DIR/${ACCOUNT}.json" 2>/dev/null | head -15 > "$TMP_DIR/${ACCOUNT}_match.txt"
            
            echo "----------------------------------------"
            cat "$TMP_DIR/${ACCOUNT}_match.txt"
            echo "----------------------------------------"
            echo ""
            echo "💡 Engagement opportunity detected!"
            echo "   Account: @$ACCOUNT"
            echo "   Keyword: $KEYWORD"
            echo ""
            
            # Log opportunity
            {
                echo "=== $(date) ==="
                echo "Account: @$ACCOUNT"
                echo "Keyword: $KEYWORD"
                cat "$TMP_DIR/${ACCOUNT}_match.txt"
                echo ""
            } >> "$WORKSPACE/artifacts/x-engagement-opportunities.log"
            
            break  # One opportunity per account per run
        fi
    done
done

echo ""
echo "✅ Scan complete. Check artifacts/x-engagement-opportunities.log for targets."
