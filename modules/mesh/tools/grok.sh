#!/usr/bin/env bash
# grok.sh — CLI wrapper for xAI Grok API (OpenAI-compatible)
#
# Usage:
#   grok 'prompt'                    # Default: grok-4-fast (2M context)
#   grok --code 'prompt'             # grok-code-fast-1 (fast coding)
#   grok --long 'prompt'             # grok-4-fast (2M context, explicit)
#   grok --model grok-4 'prompt'     # Specific model
#   grok --json 'prompt'             # JSON output mode
#   echo 'file contents' | grok 'analyze this'  # Pipe stdin as context
#   grok --system 'You are...' 'prompt'  # Custom system prompt
#
# Environment:
#   XAI_API_KEY — required (or reads from auth-profiles.json)

set -euo pipefail

# --- Config ---
XAI_ENDPOINT="https://api.x.ai/v1/chat/completions"
DEFAULT_MODEL="grok-4-fast"
CODE_MODEL="grok-code-fast-1"
MAX_TOKENS=4096
TEMPERATURE=0.7

# --- Resolve API key ---
resolve_api_key() {
    if [[ -n "${XAI_API_KEY:-}" ]]; then
        echo "$XAI_API_KEY"
        return
    fi

    # Try reading from auth-profiles.json
    local auth_file="$HOME/.openclaw/auth-profiles.json"
    if [[ -f "$auth_file" ]] && command -v python3 &>/dev/null; then
        local key
        key=$(python3 -c "
import json, sys
try:
    with open('$auth_file') as f:
        data = json.load(f)
    profiles = data.get('profiles', data)
    for k, v in profiles.items():
        if 'xai' in k.lower():
            print(v.get('api_key', v.get('key', '')))
            sys.exit(0)
except Exception:
    pass
" 2>/dev/null)
        if [[ -n "$key" ]]; then
            echo "$key"
            return
        fi
    fi

    echo >&2 "Error: XAI_API_KEY not set and not found in auth-profiles.json"
    exit 1
}

# --- Parse args ---
MODEL="$DEFAULT_MODEL"
SYSTEM_PROMPT=""
JSON_MODE=false
PROMPT=""

while [[ $# -gt 0 ]]; do
    case "$1" in
        --code)
            MODEL="$CODE_MODEL"
            TEMPERATURE=0.3
            shift
            ;;
        --long)
            MODEL="grok-4-fast"
            shift
            ;;
        --model)
            MODEL="$2"
            shift 2
            ;;
        --system)
            SYSTEM_PROMPT="$2"
            shift 2
            ;;
        --json)
            JSON_MODE=true
            shift
            ;;
        --max-tokens)
            MAX_TOKENS="$2"
            shift 2
            ;;
        --temperature)
            TEMPERATURE="$2"
            shift 2
            ;;
        -h|--help)
            cat <<'HELP'
grok — CLI wrapper for xAI Grok API

Usage:
  grok 'prompt'                      Send prompt to grok-4-fast (2M context)
  grok --code 'prompt'               Send to grok-code-fast-1 (fast coding)
  grok --long 'prompt'               Explicit 2M context mode
  grok --model MODEL 'prompt'        Use specific model
  grok --system 'system msg' 'prompt'  Custom system prompt
  grok --json 'prompt'               JSON output mode
  grok --max-tokens N 'prompt'       Set max output tokens (default: 4096)
  grok --temperature T 'prompt'      Set temperature (default: 0.7)
  echo 'data' | grok 'analyze this'  Pipe stdin as context

Models:
  grok-4           256K context, balanced
  grok-4-fast      2M context (!), fast inference (DEFAULT)
  grok-4.20-beta   2M context, latest features
  grok-3           131K context, legacy
  grok-code-fast-1 131K context, code-optimized, cheapest

Environment:
  XAI_API_KEY      API key (or auto-read from auth-profiles.json)
HELP
            exit 0
            ;;
        *)
            PROMPT="$1"
            shift
            ;;
    esac
done

if [[ -z "$PROMPT" ]] && [[ -t 0 ]]; then
    echo >&2 "Error: No prompt provided. Use: grok 'your prompt here'"
    exit 1
fi

API_KEY=$(resolve_api_key)

# --- Build messages ---
MESSAGES="[]"

if [[ -n "$SYSTEM_PROMPT" ]]; then
    MESSAGES=$(python3 -c "
import json, sys
msgs = [{'role': 'system', 'content': sys.argv[1]}]
print(json.dumps(msgs))
" "$SYSTEM_PROMPT")
fi

# Read stdin if piped
STDIN_CONTENT=""
if [[ ! -t 0 ]]; then
    STDIN_CONTENT=$(cat)
fi

# Build user message
USER_CONTENT="$PROMPT"
if [[ -n "$STDIN_CONTENT" ]]; then
    if [[ -n "$PROMPT" ]]; then
        USER_CONTENT="$PROMPT

---
Context from stdin:
$STDIN_CONTENT"
    else
        USER_CONTENT="$STDIN_CONTENT"
    fi
fi

# --- Build request ---
REQUEST=$(python3 -c "
import json, sys

messages = json.loads(sys.argv[1])
messages.append({'role': 'user', 'content': sys.argv[2]})

payload = {
    'model': sys.argv[3],
    'messages': messages,
    'max_tokens': int(sys.argv[4]),
    'temperature': float(sys.argv[5]),
    'stream': False,
}

print(json.dumps(payload))
" "$MESSAGES" "$USER_CONTENT" "$MODEL" "$MAX_TOKENS" "$TEMPERATURE")

# --- Call API ---
RESPONSE=$(curl -s -w "\n%{http_code}" \
    -X POST "$XAI_ENDPOINT" \
    -H "Content-Type: application/json" \
    -H "Authorization: Bearer $API_KEY" \
    -d "$REQUEST")

HTTP_CODE=$(echo "$RESPONSE" | tail -1)
BODY=$(echo "$RESPONSE" | sed '$d')

if [[ "$HTTP_CODE" -ne 200 ]]; then
    echo >&2 "Error: API returned HTTP $HTTP_CODE"
    echo >&2 "$BODY"
    exit 1
fi

# --- Extract response ---
if [[ "$JSON_MODE" == "true" ]]; then
    echo "$BODY"
else
    python3 -c "
import json, sys
try:
    data = json.loads(sys.argv[1])
    content = data['choices'][0]['message']['content']
    print(content)

    # Print usage to stderr
    usage = data.get('usage', {})
    if usage:
        inp = usage.get('prompt_tokens', 0)
        out = usage.get('completion_tokens', 0)
        print(f'\n--- [{sys.argv[2]}] {inp} in / {out} out tokens ---', file=sys.stderr)
except Exception as e:
    print(f'Error parsing response: {e}', file=sys.stderr)
    print(sys.argv[1])
" "$BODY" "$MODEL"
fi
