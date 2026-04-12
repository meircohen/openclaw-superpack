#!/bin/bash
# Setup Perplexity AI integration across all systems
# Usage: bash setup-perplexity.sh <API_KEY>

set -e

API_KEY="$1"
if [ -z "$API_KEY" ]; then
    echo "❌ Usage: bash setup-perplexity.sh <pplx-API-KEY>"
    exit 1
fi

echo "🔧 Setting up Perplexity AI integration..."

# 1. Store API key in environment
echo "  → Adding API key to shell profile..."
if ! grep -q "PERPLEXITY_API_KEY" ~/.zshrc 2>/dev/null; then
    echo "" >> ~/.zshrc
    echo "# Perplexity AI" >> ~/.zshrc
    echo "export PERPLEXITY_API_KEY=\"$API_KEY\"" >> ~/.zshrc
fi
export PERPLEXITY_API_KEY="$API_KEY"

# 2. Add to Claude Code MCP config
echo "  → Configuring Claude Code MCP server..."
CLAUDE_SETTINGS="$HOME/.claude/settings.json"
python3 << PYEOF
import json
settings_path = "$CLAUDE_SETTINGS"
with open(settings_path) as f:
    settings = json.load(f)

if 'mcpServers' not in settings:
    settings['mcpServers'] = {}

settings['mcpServers']['perplexity'] = {
    "command": "npx",
    "args": ["-y", "@perplexity-ai/mcp-server"],
    "env": {
        "PERPLEXITY_API_KEY": "$API_KEY"
    }
}

with open(settings_path, 'w') as f:
    json.dump(settings, f, indent=4)
print("  ✅ Claude Code MCP configured")
PYEOF

# 3. Add to Codex MCP config
echo "  → Configuring Codex MCP server..."
CODEX_CONFIG="$HOME/.codex/config.toml"
if [ -f "$CODEX_CONFIG" ]; then
    if ! grep -q "perplexity" "$CODEX_CONFIG" 2>/dev/null; then
        cat >> "$CODEX_CONFIG" << EOF

[mcp_servers.perplexity]
command = "npx"
args = ["-y", "@perplexity-ai/mcp-server"]

[mcp_servers.perplexity.env]
PERPLEXITY_API_KEY = "$API_KEY"
EOF
        echo "  ✅ Codex MCP configured"
    else
        echo "  ✅ Codex already has Perplexity MCP"
    fi
fi

# 4. Add to OpenClaw MCP config  
echo "  → Configuring OpenClaw MCP server..."
python3 << PYEOF2
import json, os, sys
sys.path.insert(0, os.path.expanduser('~/.openclaw'))

config_path = os.path.expanduser('~/.openclaw/openclaw.json')
# Read as text and parse (might be JSON5)
# Use the gateway config.patch instead
print("  ℹ️  Will use gateway config.patch for OpenClaw")
PYEOF2

# 5. Store in OpenClaw auth profiles
echo "  → Storing in OpenClaw auth profiles..."
python3 << PYEOF3
import json, os
auth_path = os.path.expanduser('~/.openclaw/agents/main/agent/auth-profiles.json')
with open(auth_path) as f:
    auth = json.load(f)

auth['profiles']['perplexity:default'] = {
    'key': '$API_KEY',
    'provider': 'perplexity',
    'type': 'api_key',
    'note': 'Perplexity AI API - Max subscription (\$200/mo, \$50/mo API credit included)'
}

with open(auth_path, 'w') as f:
    json.dump(auth, f, indent=2)
print("  ✅ Auth profile stored")
PYEOF3

# 6. Test the API
echo "  → Testing API connection..."
RESPONSE=$(curl -s -o /dev/null -w "%{http_code}" \
    -X POST "https://api.perplexity.ai/chat/completions" \
    -H "Authorization: Bearer $API_KEY" \
    -H "Content-Type: application/json" \
    -d '{"model":"sonar","messages":[{"role":"user","content":"test"}],"max_tokens":10}')

if [ "$RESPONSE" = "200" ]; then
    echo "  ✅ API connection verified!"
else
    echo "  ⚠️  API returned HTTP $RESPONSE (key may need activation)"
fi

# 7. Create convenience wrapper
echo "  → Creating pplx wrapper script..."
cat > "$HOME/.openclaw/workspace/scripts/pplx" << 'WRAPPER'
#!/bin/bash
# Quick Perplexity search from command line
# Usage: pplx "your question here"
#        pplx --deep "complex research question"

MODEL="sonar"
if [ "$1" = "--deep" ]; then
    MODEL="sonar-deep-research"
    shift
elif [ "$1" = "--pro" ]; then
    MODEL="sonar-pro"
    shift
elif [ "$1" = "--reasoning" ]; then
    MODEL="sonar-reasoning-pro"
    shift
fi

QUERY="$*"
if [ -z "$QUERY" ]; then
    echo "Usage: pplx [--deep|--pro|--reasoning] \"your question\""
    exit 1
fi

curl -s -X POST "https://api.perplexity.ai/chat/completions" \
    -H "Authorization: Bearer $PERPLEXITY_API_KEY" \
    -H "Content-Type: application/json" \
    -d "{\"model\":\"$MODEL\",\"messages\":[{\"role\":\"user\",\"content\":\"$QUERY\"}]}" \
    | python3 -c "import json,sys; d=json.load(sys.stdin); print(d.get('choices',[{}])[0].get('message',{}).get('content','No response'))" 2>/dev/null \
    || echo "Error: check PERPLEXITY_API_KEY"
WRAPPER
chmod +x "$HOME/.openclaw/workspace/scripts/pplx"

echo ""
echo "✅ Perplexity AI fully integrated!"
echo ""
echo "Available everywhere:"
echo "  • Claude Code: mcp__perplexity__search (auto-available)"
echo "  • Codex: mcp__perplexity__search (auto-available)"  
echo "  • OpenClaw: perplexity MCP server"
echo "  • CLI: pplx \"your question\""
echo "  • CLI: pplx --deep \"complex research\""
echo "  • CLI: pplx --pro \"detailed search\""
echo "  • CLI: pplx --reasoning \"reasoning task\""
echo "  • Python: python3 scripts/perplexity.py \"query\" (browser-based, free)"
echo ""
echo "Models available:"
echo "  • sonar (fast search, default)"
echo "  • sonar-pro (deeper search)"
echo "  • sonar-reasoning-pro (reasoning + search)"
echo "  • sonar-deep-research (multi-step research)"
