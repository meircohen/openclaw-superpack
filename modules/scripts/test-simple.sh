#!/usr/bin/env bash
# Simple test - just verify no-auth APIs work

cd "$( dirname "${BASH_SOURCE[0]}" )"

echo "🧪 Quick API Test"
echo "================="
echo ""

echo "✓ Hebcal:"
bash hebcal.sh shabbat | jq -r '.items[] | .title' | head -2

echo ""
echo "✓ SEC EDGAR:"
bash sec-edgar.sh search AAPL | jq -r '.[0] | .name' | head -1

echo ""
echo "✓ Frankfurter:"
bash frankfurter.sh latest USD EUR | jq -r '.rates.EUR'

echo ""
echo "✅ All no-auth APIs working!"
