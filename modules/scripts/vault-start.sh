#!/bin/bash
# Start Vault in dev mode if not already running
export PATH="/opt/homebrew/bin:/usr/local/bin:$PATH"
export VAULT_ADDR="http://127.0.0.1:8200"
# NOTE: Dev mode = in-memory storage. Secrets don't persist across restarts.
# For production, switch to file backend. See ~/.openclaw/modules/vault/README.md

if ! curl -sf http://127.0.0.1:8200/v1/sys/health > /dev/null 2>&1; then
    echo "Starting Vault dev server..."
    export VAULT_DEV_ROOT_TOKEN_ID=dev-root-token
    mkdir -p ~/.openclaw/modules/vault/logs
    nohup /opt/homebrew/bin/vault server -dev -dev-listen-address="127.0.0.1:8200" > ~/.openclaw/modules/vault/logs/vault.log 2>&1 &
    echo $! > ~/.openclaw/modules/vault/vault.pid
    sleep 2
    if curl -sf http://127.0.0.1:8200/v1/sys/health > /dev/null 2>&1; then
        echo "Vault started successfully (PID: $(cat ~/.openclaw/modules/vault/vault.pid))"
    else
        echo "ERROR: Vault failed to start"
        exit 1
    fi
else
    echo "Vault already running"
fi
