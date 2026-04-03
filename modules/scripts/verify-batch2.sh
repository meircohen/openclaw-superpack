#!/usr/bin/env bash
# Verification script for Batch 2 API integrations

set -euo pipefail
cd "$(dirname "$0")"

echo "=== Testing Batch 2 API Scripts ==="
echo

declare -a tests=(
  "wikipedia.sh:summary Bitcoin"
  "sunrise-sunset.sh:today"
  "nasa-apod.sh:today"
  "currency-api.sh:latest usd"
  "openlibrary.sh:search Foundation"
)

passed=0
failed=0

for test in "${tests[@]}"; do
  script="${test%%:*}"
  args="${test#*:}"
  
  echo -n "Testing $script ... "
  
  if bash "$script" $args > /dev/null 2>&1; then
    echo "✅ PASSED"
    ((passed++))
  else
    echo "❌ FAILED"
    ((failed++))
  fi
done

echo
echo "Results: $passed passed, $failed failed"
