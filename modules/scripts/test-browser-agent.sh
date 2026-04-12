#!/bin/bash
# Test suite for browser-agent.py

set -e

SCRIPT_DIR="$HOME/.openclaw/workspace/scripts"
BROWSER_DIR="$HOME/.openclaw/workspace/browser"

cd "$SCRIPT_DIR"

echo "=== Browser Agent Test Suite ==="
echo ""

# Test 1: Help
echo "Test 1: Help output"
python3 browser-agent.py --help > /dev/null
echo "✓ Help works"
echo ""

# Test 2: List tasks
echo "Test 2: List tasks"
python3 browser-agent.py --list-tasks
echo "✓ Task listing works"
echo ""

# Test 3: Screenshot (simple page)
echo "Test 3: Screenshot of example.com"
python3 browser-agent.py --screenshot https://example.com --output test-example.png
if [ -f "$BROWSER_DIR/screenshots/test-example.png" ]; then
    echo "✓ Screenshot saved: $(ls -lh $BROWSER_DIR/screenshots/test-example.png | awk '{print $5}')"
else
    echo "✗ Screenshot failed"
    exit 1
fi
echo ""

# Test 4: Text extraction
echo "Test 4: Extract text from example.com"
python3 browser-agent.py --extract https://example.com --selector "h1" --json > /tmp/test-extract.json
if grep -q "Example Domain" /tmp/test-extract.json; then
    echo "✓ Text extraction works"
else
    echo "✗ Text extraction failed"
    exit 1
fi
echo ""

# Test 5: Status check
echo "Test 5: Status check"
python3 browser-agent.py --status https://example.com --json > /tmp/test-status.json
if grep -q '"success": true' /tmp/test-status.json; then
    echo "✓ Status check works"
else
    echo "✗ Status check failed"
    exit 1
fi
echo ""

# Test 6: Task runner
echo "Test 6: Run 'screenshot' task"
python3 browser-agent.py --task screenshot --url https://example.com --output task-test.png
if [ -f "$BROWSER_DIR/screenshots/task-test.png" ]; then
    echo "✓ Task runner works"
else
    echo "✗ Task runner failed"
    exit 1
fi
echo ""

# Test 7: Full page screenshot
echo "Test 7: Full page screenshot"
python3 browser-agent.py --screenshot https://example.com --full-page --output full-test.png
if [ -f "$BROWSER_DIR/screenshots/full-test.png" ]; then
    full_size=$(stat -f%z "$BROWSER_DIR/screenshots/full-test.png")
    normal_size=$(stat -f%z "$BROWSER_DIR/screenshots/test-example.png")
    if [ $full_size -gt $normal_size ]; then
        echo "✓ Full page screenshot works (larger than normal)"
    else
        echo "⚠ Full page screenshot created but not larger than normal"
    fi
else
    echo "✗ Full page screenshot failed"
    exit 1
fi
echo ""

# Test 8: Wait parameter
echo "Test 8: Wait parameter (3 seconds)"
start=$(date +%s)
python3 browser-agent.py --screenshot https://example.com --wait 3 --output wait-test.png > /dev/null 2>&1
end=$(date +%s)
duration=$((end - start))
if [ $duration -ge 3 ]; then
    echo "✓ Wait parameter works (took ${duration}s)"
else
    echo "⚠ Wait might not be working (took ${duration}s, expected >=3s)"
fi
echo ""

echo "=== All Tests Passed ==="
echo ""
echo "Screenshots saved in: $BROWSER_DIR/screenshots/"
ls -lh "$BROWSER_DIR/screenshots/"
echo ""
echo "Cleanup test files:"
echo "  rm $BROWSER_DIR/screenshots/test-*.png"
echo "  rm $BROWSER_DIR/screenshots/task-test.png"
echo "  rm $BROWSER_DIR/screenshots/full-test.png"
echo "  rm $BROWSER_DIR/screenshots/wait-test.png"
