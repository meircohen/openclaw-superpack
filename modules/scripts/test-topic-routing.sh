#!/bin/bash
# test-topic-routing.sh
# Test the topic classifier with sample messages

set -euo pipefail

echo "🧪 Testing Telegram Topic Routing"
echo ""

test_cases=(
  "BTC just hit 71K, should we move treasury funds?|📊 Financial"
  "Mission Control DNS is broken, getting 502 errors|🏗️ Infrastructure"
  "Meeting with Eli about ZettaPOW partnership|💼 Business"
  "What time is Shabbos candle lighting this week?|🕊️ Torah/Personal"
  "Can you add a new skill to OpenClaw?|🤖 OpenClaw Meta"
  "Reminder to call Mom|📝 Inbox"
  "JPM portfolio update shows 14.8% return|📊 Financial"
  "Reb VM disk is 100% full|🏗️ Infrastructure"
  "Draft email to CBIZ about tax filing|💼 Business"
  "Prayer times for tomorrow|🕊️ Torah/Personal"
  "Oz heartbeat failed with timeout|🤖 OpenClaw Meta"
  "Buy milk|📝 Inbox"
)

passed=0
failed=0

for test in "${test_cases[@]}"; do
  message="${test%|*}"
  expected="${test#*|}"
  
  result=$(node scripts/telegram-topic-router.js "$message" | grep "Topic:" | cut -d' ' -f2-3)
  
  if [[ "$result" == "$expected" ]]; then
    echo "✅ PASS: \"$message\" → $result"
    ((passed++))
  else
    echo "❌ FAIL: \"$message\""
    echo "   Expected: $expected"
    echo "   Got: $result"
    ((failed++))
  fi
done

echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "Results: $passed passed, $failed failed"
echo ""

if [[ $failed -eq 0 ]]; then
  echo "✅ All tests passed! Topic routing working correctly."
  exit 0
else
  echo "⚠️  Some tests failed. Review keyword lists in scripts/telegram-topic-router.js"
  exit 1
fi
