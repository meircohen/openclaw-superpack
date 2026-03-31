#!/bin/bash
# OpenClaw Intelligence System — One-command setup
# Run once: bash init.sh
# ─────────────────────────────────────────────────────────────

set -e
INTEL_DIR="$HOME/.openclaw/workspace/intelligence"
PLIST_SRC="$INTEL_DIR/com.openclaw.intelligence.plist"
PLIST_DST="$HOME/Library/LaunchAgents/com.openclaw.intelligence.plist"

echo "🧠 OpenClaw Intelligence System — Setup"
echo "─────────────────────────────────────────"

# 1. Check Python
PYTHON=$(which python3)
PY_VERSION=$($PYTHON --version 2>&1)
echo "✅ Python: $PY_VERSION ($PYTHON)"

# 2. Install dependencies
echo "📦 Installing dependencies..."
$PYTHON -m pip install --quiet feedparser httpx pyyaml 2>/dev/null || {
    echo "   pip install failed — trying pip3..."
    pip3 install --quiet feedparser httpx pyyaml
}
echo "✅ Dependencies ready"

# 3. Update plist with correct Python path
sed -i '' "s|/usr/bin/python3|$PYTHON|g" "$PLIST_SRC"
echo "✅ Plist updated with Python path: $PYTHON"

# 4. Install launchd job
cp "$PLIST_SRC" "$PLIST_DST"
launchctl unload "$PLIST_DST" 2>/dev/null || true
launchctl load "$PLIST_DST"
echo "✅ launchd job installed and loaded"

# 5. Run collector once manually to verify
echo ""
echo "🔄 Running first collection (dry run)..."
cd "$INTEL_DIR"
$PYTHON collector.py --dry-run 2>&1 | head -40
echo ""

echo "─────────────────────────────────────────"
echo "✅ Setup complete!"
echo ""
echo "Next steps:"
echo "  1. Run live collection:    cd $HOME/.openclaw/workspace/intelligence && python3 collector.py"
echo "  2. Run filter:             python3 filter.py"
echo "  3. Generate digest:        python3 digest.py --stdout"
echo "  4. Start calibration:      python3 review.py"
echo "  5. Check logs:             tail -f /tmp/openclaw-intelligence.log"
echo ""
echo "The system will now run automatically every 6 hours."
echo "After 3 days, run 'python3 review.py --stats' to calibrate thresholds."
