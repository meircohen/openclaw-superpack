#!/usr/bin/env bash
# Example usage patterns for API integrations
# These examples show real-world use cases for agent workflows

set -euo pipefail

SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
cd "$SCRIPT_DIR"

echo "📚 OpenClaw API Integration Examples"
echo "====================================="
echo ""

# Example 1: Morning brief for daily digest
echo "1️⃣  Morning Brief (News + Markets + Jewish Calendar)"
echo "---------------------------------------------------"
echo ""
echo "Current Shabbos times:"
bash hebcal.sh shabbat --pretty | jq -r '.items[] | "\(.title) at \(.date)"'
echo ""

echo "Today's Hebrew date:"
bash hebcal.sh today | jq -r '"Hebrew: \(.hebrew) | Gregorian: \(.date)"'
echo ""

echo "---"
echo ""

# Example 2: Financial dashboard
echo "2️⃣  Financial Dashboard"
echo "----------------------"
echo ""
echo "Currency rates (USD base):"
bash frankfurter.sh latest USD EUR,GBP,ILS,JPY | jq -r '.rates | to_entries[] | "\(.key): \(.value)"'
echo ""

echo "Market data (requires Alpha Vantage key):"
bash alpha-vantage.sh quote AAPL 2>/dev/null | jq -r 'if . then "AAPL: $\(.["05. price"]) (change: \(.["09. change"]))" else "API key needed" end' || echo "  → Get free key: https://www.alphavantage.co/support/#api-key"
echo ""

echo "---"
echo ""

# Example 3: Research workflow
echo "3️⃣  Company Research Workflow"
echo "----------------------------"
echo ""
echo "SEC filings for AAPL:"
bash sec-edgar.sh search AAPL | jq -r '.[:3] | .[] | "- \(.name) (CIK: \(.cik))"'
echo ""

echo "Ask WolframAlpha (requires key):"
bash wolfram.sh "Apple Inc market cap" 2>/dev/null | jq -r '.result[] | .text' || echo "  → Get free App ID: https://products.wolframalpha.com/api"
echo ""

echo "---"
echo ""

# Example 4: Time-aware operations
echo "4️⃣  Time-Aware Operation Check"
echo "-----------------------------"
echo ""
bash hebcal.sh zmanim | jq -r '"Dawn (Alot HaShachar): \(.times.dawn)\nSunrise: \(.times.sunrise)\nSunset: \(.times.sunset)\nNightfall (Tzeit): \(.times.tzeit)"'
echo ""

IS_SHABBOS=$(bash ../../time-awareness.sh is-shabbos && echo "yes" || echo "no")
echo "Currently Shabbos: $IS_SHABBOS"
echo ""

echo "---"
echo ""

# Example 5: Economic indicators for investment analysis
echo "5️⃣  Economic Indicators (requires FRED key)"
echo "-------------------------------------------"
echo ""
bash fred.sh dashboard 2>/dev/null | jq -r 'to_entries[] | "\(.key): \(.value.observations[0].value) (as of \(.value.observations[0].date))"' || echo "  → Get free FRED key: https://fred.stlouisfed.org/docs/api/api_key.html"
echo ""

echo "---"
echo ""

echo "✅ Examples complete!"
echo ""
echo "💡 Tip: Use '--pretty' flag for formatted JSON output"
echo "   Example: bash hebcal.sh --pretty shabbat"
