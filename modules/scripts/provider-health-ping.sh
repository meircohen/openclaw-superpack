#!/bin/bash
# provider-health-ping.sh — Lightweight health check (no LLM, just HTTP pings)
# Use this for frequent checks. Reserve full LLM health check for daily runs.
# Created: 2026-04-05 by Gemma 4 subconscious optimization

echo "=== Provider Health Ping ($(date)) ==="

check() {
  local name="$1" url="$2"
  code=$(curl -s -o /dev/null -w "%{http_code}" --max-time 5 "$url" 2>/dev/null)
  if [ "$code" = "200" ] || [ "$code" = "401" ] || [ "$code" = "403" ]; then
    echo "  ✅ $name (HTTP $code)"
  else
    echo "  ❌ $name (HTTP $code or timeout)"
  fi
}

check "OpenClaw Gateway" "http://localhost:18789/health"
check "Ollama (Gemma 4)" "http://localhost:11434/api/tags"
check "Anthropic API" "https://api.anthropic.com/v1/messages"
check "OpenAI API" "https://api.openai.com/v1/models"
check "Google AI" "https://generativelanguage.googleapis.com/v1beta/models"

# Check CLI tools
for cmd in claude codex gemini; do
  if command -v $cmd &>/dev/null; then
    echo "  ✅ $cmd CLI (installed)"
  else
    echo "  ❌ $cmd CLI (not found)"
  fi
done

echo "=== Done ($(date)) ==="
