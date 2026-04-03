#!/usr/bin/env bash
# Demo script showing Batch 2 API integrations in action

set -euo pipefail
cd "$(dirname "$0")"

echo "╔════════════════════════════════════════════════════════════╗"
echo "║   OpenClaw API Integrations - Batch 2 Demo                ║"
echo "╚════════════════════════════════════════════════════════════╝"
echo

# 1. Wikipedia Summary
echo "📚 Wikipedia Summary (Bitcoin):"
bash wikipedia.sh summary Bitcoin 2>/dev/null | jq -r '.extract' | head -c 200
echo "..."
echo

# 2. Sunrise/Sunset Times
echo "🌅 Sunrise & Sunset (Surfside, FL):"
bash sunrise-sunset.sh today 2>/dev/null | jq -r '.results | "Sunrise: \(.sunrise) | Sunset: \(.sunset)"'
echo

# 3. NASA APOD
echo "🌌 NASA Astronomy Picture of the Day:"
bash nasa-apod.sh today 2>/dev/null | jq -r '"Title: \(.title)\nDate: \(.date)"'
echo

# 4. Currency Conversion
echo "💱 Currency Conversion (100 USD → EUR):"
bash currency-api.sh convert 100 usd eur 2>/dev/null | jq -r '"Rate: \(.rate) | Result: €\(.result)"'
echo

# 5. Book Search
echo "📖 Book Search (Foundation):"
bash openlibrary.sh search "Foundation Asimov" 2>/dev/null | jq -r '.docs[0] | "Title: \(.title)\nAuthor: \(.author_name[0])\nYear: \(.first_publish_year)"'
echo

echo "✅ All Batch 2 APIs demonstrated successfully!"
echo
echo "Available commands:"
echo "  coincap.sh, currency-api.sh, opensanctions.sh,"
echo "  mozilla-observatory.sh, ipapi.sh, sunrise-sunset.sh,"
echo "  nasa-apod.sh, fileio.sh, openlibrary.sh, wikipedia.sh"
echo
echo "Run any script with --help or no args for usage info."
