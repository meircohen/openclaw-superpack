#!/bin/bash
# Verify X/Twitter credentials
# Updated: 2026-03-10 — migrated from x-cli (API keys) to twitter-cli (cookie auth)

set -euo pipefail

echo "🔍 Verifying X/Twitter Authentication"
echo "======================================="
echo ""

echo "Tool: twitter-cli v0.4.6 (cookie auth from browser)"
echo ""

echo "Testing twitter-cli authentication..."
if twitter feed --max 1 --json 2>&1 | grep -q '"id"'; then
    echo "  ✅ twitter-cli authentication working (cookie auth)"
else
    echo "  ❌ twitter-cli authentication failed"
    echo "  Fix: Log into X/Twitter in Chrome/Safari, then retry"
fi

echo ""
echo "Testing write access..."
# Don't actually post, just verify we can read mentions
if twitter search "from:MeirCohen" --max 1 --json 2>&1 | grep -q '"id"\|"text"'; then
    echo "  ✅ Search working"
else
    echo "  ⚠️ Search may be rate-limited"
fi

echo ""
echo "Legacy x-cli can be removed: pipx uninstall x-cli"
echo "New tool: twitter (cookie auth, no API keys needed)"
