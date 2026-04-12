#!/bin/bash
# Usage: vault-get.sh <path> <key>
# Example: vault-get.sh openclaw/telegram bot_token
export VAULT_ADDR='http://127.0.0.1:8200'
export VAULT_TOKEN='dev-root-token'
vault kv get -field="$2" "secret/$1" 2>/dev/null
