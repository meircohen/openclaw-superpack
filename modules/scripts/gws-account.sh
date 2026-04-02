#!/bin/bash
# gws Account Switcher
# Usage: source scripts/gws-account.sh [meir|nechie]

set -euo pipefail

ACCOUNT="${1:-meir}"

case "$ACCOUNT" in
    meir|meircohen)
        # Use default encrypted credentials
        unset GOOGLE_WORKSPACE_CLI_CREDENTIALS_FILE
        echo "✅ Using Meir's account (meircohen@gmail.com)"
        echo "   Default credentials: ~/Library/Application Support/gws/credentials.enc"
        ;;
    nechie|nickycohen)
        # Use Nechie's exported credentials
        export GOOGLE_WORKSPACE_CLI_CREDENTIALS_FILE="$HOME/.gws/nechie-credentials.json"
        echo "✅ Using Nechie's account (nickycohen@gmail.com)"
        echo "   Credentials: ~/.gws/nechie-credentials.json"
        ;;
    *)
        echo "❌ Unknown account: $ACCOUNT"
        echo "Usage: source scripts/gws-account.sh [meir|nechie]"
        return 1
        ;;
esac

# Verify it works
echo ""
echo "Testing account..."
gws gmail users getProfile --params '{"userId": "me"}' 2>&1 | jq -r '.emailAddress' || echo "Failed to verify"
