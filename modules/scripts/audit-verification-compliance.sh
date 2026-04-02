#!/usr/bin/env bash
# audit-verification-compliance.sh - Check if I'm actually verifying before claiming success

set -euo pipefail

WORKSPACE="/Users/meircohen/.openclaw/workspace"
YESTERDAY=$(date -v-1d +%Y-%m-%d)
MEMORY_FILE="$WORKSPACE/memory/daily/$YESTERDAY.md"

echo "🔍 Verification Compliance Audit for $YESTERDAY"
echo ""

if [ ! -f "$MEMORY_FILE" ]; then
    echo "⚠️  No memory file found for $YESTERDAY"
    echo "📁 Looking for: $MEMORY_FILE"
    exit 0
fi

# Find claims of success
CLAIMS=$(grep -n "launched\|completed\|✅\|running\|executed\|moved.*files\|sent.*email" "$MEMORY_FILE" | wc -l | xargs)

# Find verification outputs
VERIFICATIONS=$(grep -n "verified\|VERIFIED\|spot-check\|ps aux.*grep\|verify-operation.sh" "$MEMORY_FILE" | wc -l | xargs)

echo "📊 Statistics:"
echo "  - Success claims: $CLAIMS"
echo "  - Verifications: $VERIFICATIONS"

if [ "$CLAIMS" -eq 0 ]; then
    echo ""
    echo "✅ No success claims found (nothing to verify)"
    exit 0
fi

# Calculate compliance
if [ "$VERIFICATIONS" -ge "$CLAIMS" ]; then
    COMPLIANCE=100
else
    COMPLIANCE=$((VERIFICATIONS * 100 / CLAIMS))
fi

echo "  - Compliance: $COMPLIANCE%"
echo ""

# Find violations (claims without nearby verification)
echo "🔍 Checking for unverified claims..."
echo ""

VIOLATIONS=0

# Extract line numbers of claims
grep -n "launched\|completed\|✅.*[Rr]unning\|✅.*[Ee]xecuted\|moved.*files\|sent.*email" "$MEMORY_FILE" | while IFS=: read -r line_num text; do
    # Check if there's a verification within 10 lines
    start=$((line_num - 2))
    end=$((line_num + 8))
    
    if sed -n "${start},${end}p" "$MEMORY_FILE" | grep -q "verified\|VERIFIED\|spot-check\|ps aux.*grep\|verify-operation.sh"; then
        # Verification found nearby
        continue
    else
        # Violation found
        VIOLATIONS=$((VIOLATIONS + 1))
        echo "❌ Line $line_num: $(echo "$text" | head -c 80)..."
    fi
done

echo ""
if [ "$VIOLATIONS" -eq 0 ]; then
    echo "✅ No unverified claims found"
else
    echo "⚠️  Found $VIOLATIONS unverified claims"
    echo ""
    echo "📋 Action required:"
    echo "  1. Review these claims in $MEMORY_FILE"
    echo "  2. Add verification to response templates"
    echo "  3. Update docs/AUTO-VERIFICATION.md if needed"
fi

echo ""
echo "🎯 Target: >95% compliance"
if [ "$COMPLIANCE" -ge 95 ]; then
    echo "✅ PASSING"
else
    echo "❌ FAILING - Need to improve verification discipline"
fi
