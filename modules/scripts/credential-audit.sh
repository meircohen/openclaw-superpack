#!/usr/bin/env bash
set -euo pipefail

# Credential Health Check System
# Tests all API keys, CLI auth, and service access

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Counters
TOTAL=0
WORKING=0
MISSING=0
FAILED=0

# Output functions
check_start() {
    TOTAL=$((TOTAL + 1))
    printf "%-30s " "$1:"
}

check_ok() {
    WORKING=$((WORKING + 1))
    echo -e "${GREEN}✅ WORKING${NC} ${2:-}"
}

check_missing() {
    MISSING=$((MISSING + 1))
    echo -e "${YELLOW}⚠️  MISSING KEY${NC}"
}

check_fail() {
    FAILED=$((FAILED + 1))
    echo -e "${RED}❌ FAILED${NC} - $1"
}

echo "================================"
echo "Credential Health Check"
echo "$(date '+%Y-%m-%d %H:%M:%S')"
echo "================================"
echo ""

# ==========================================
# NO-AUTH APIs
# ==========================================
echo "📡 No-Auth APIs"
echo "---"

# Hebcal
check_start "Hebcal"
if result=$(curl -sf "https://www.hebcal.com/shabbat?cfg=json&geonameid=4164138" 2>&1 | jq -r .title 2>&1); then
    if [[ -n "$result" && "$result" != "null" ]]; then
        check_ok "(Shabbat times)"
    else
        check_fail "Invalid response"
    fi
else
    check_fail "Connection failed"
fi

# CoinCap
check_start "CoinCap"
if result=$(curl -sf "https://api.coincap.io/v2/assets/bitcoin" 2>&1 | jq -r .data.priceUsd 2>&1); then
    if [[ -n "$result" && "$result" != "null" ]]; then
        check_ok "(\$${result%.*})"
    else
        check_fail "Invalid response"
    fi
else
    check_fail "Connection failed"
fi

# Frankfurter
check_start "Frankfurter"
if result=$(curl -sf "https://api.frankfurter.dev/latest?from=USD&to=ILS" 2>&1 | jq -r .rates.ILS 2>&1); then
    if [[ -n "$result" && "$result" != "null" ]]; then
        check_ok "(${result} ILS)"
    else
        check_fail "Invalid response"
    fi
else
    check_fail "Connection failed"
fi

echo ""

# ==========================================
# AUTH-REQUIRED APIs
# ==========================================
echo "🔑 Auth-Required APIs"
echo "---"

# Source API keys if available
if [[ -f ~/.openclaw/.api-keys ]]; then
    source ~/.openclaw/.api-keys
else
    echo -e "${YELLOW}⚠️  ~/.openclaw/.api-keys not found - skipping API key tests${NC}"
fi

# Alpha Vantage
check_start "Alpha Vantage"
if [[ -z "${ALPHA_VANTAGE_KEY:-}" ]]; then
    check_missing
else
    if result=$(curl -sf "https://www.alphavantage.co/query?function=TIME_SERIES_INTRADAY&symbol=AAPL&interval=5min&apikey=$ALPHA_VANTAGE_KEY" 2>&1); then
        # Check for rate limit note or valid meta data
        note=$(echo "$result" | jq -r '.Note // empty' 2>/dev/null)
        meta=$(echo "$result" | jq -r '.["Meta Data"] // empty' 2>/dev/null)
        
        if [[ -n "$meta" ]]; then
            check_ok "(Stock data available)"
        elif [[ -n "$note" ]]; then
            check_fail "Rate limited: $note"
        else
            check_fail "Invalid response"
        fi
    else
        check_fail "Connection failed"
    fi
fi

# FRED (Federal Reserve Economic Data)
check_start "FRED"
if [[ -z "${FRED_KEY:-}" ]]; then
    check_missing
else
    if result=$(curl -sf "https://api.stlouisfed.org/fred/series?series_id=GDP&api_key=$FRED_KEY&file_type=json" 2>&1 | jq -r '.seriess[0].title // empty' 2>&1); then
        if [[ -n "$result" && "$result" != "null" ]]; then
            check_ok "(GDP series)"
        else
            check_fail "Invalid response"
        fi
    else
        check_fail "Connection failed"
    fi
fi

# News API
check_start "News API"
if [[ -z "${NEWS_API_KEY:-}" ]]; then
    check_missing
else
    if result=$(curl -sf "https://newsapi.org/v2/top-headlines?country=us&pageSize=1&apiKey=$NEWS_API_KEY" 2>&1 | jq -r .status 2>&1); then
        if [[ "$result" == "ok" ]]; then
            check_ok "(Headlines available)"
        else
            check_fail "Status: $result"
        fi
    else
        check_fail "Connection failed"
    fi
fi

# Wolfram Alpha
check_start "Wolfram Alpha"
if [[ -z "${WOLFRAM_APP_ID:-}" ]]; then
    check_missing
else
    if result=$(curl -sf "https://api.wolframalpha.com/v2/query?input=2%2B2&appid=$WOLFRAM_APP_ID&output=json" 2>&1 | jq -r .queryresult.success 2>&1); then
        if [[ "$result" == "true" ]]; then
            check_ok "(Query successful)"
        else
            check_fail "Query failed"
        fi
    else
        check_fail "Connection failed"
    fi
fi

# Have I Been Pwned
check_start "HIBP"
if [[ -z "${HIBP_KEY:-}" ]]; then
    check_missing
else
    # Test with a known breached test email
    if result=$(curl -sf -H "hibp-api-key: $HIBP_KEY" \
        "https://haveibeenpwned.com/api/v3/breachedaccount/test@example.com" 2>&1); then
        # Any response (even 404) means auth worked
        check_ok "(Auth valid)"
    else
        check_fail "Auth failed"
    fi
fi

echo ""

# ==========================================
# CLI TOOLS
# ==========================================
echo "🛠️  CLI Authentication"
echo "---"

# GitHub CLI
check_start "GitHub (gh)"
if ! command -v gh &> /dev/null; then
    check_fail "gh not installed"
else
    if gh auth status 2>&1 | head -1 | grep -q "Logged in"; then
        user=$(gh api user -q .login 2>/dev/null || echo "unknown")
        check_ok "(@${user})"
    else
        check_fail "Not authenticated"
    fi
fi

# Google CLI (gog)
check_start "Google (gog)"
if ! command -v gog &> /dev/null; then
    check_fail "gog not installed"
else
    if gog auth status 2>&1 | grep -q "authenticated" || gog gmail messages search 'test' --max 1 2>&1 | grep -qv "error"; then
        check_ok "(Gmail accessible)"
    else
        check_fail "Not authenticated"
    fi
fi

# AWS CLI
check_start "AWS"
if ! command -v aws &> /dev/null; then
    check_fail "aws not installed"
else
    if result=$(aws sts get-caller-identity 2>&1 | head -3); then
        if echo "$result" | grep -q "UserId"; then
            account=$(echo "$result" | jq -r .Account 2>/dev/null || echo "unknown")
            check_ok "(Account: ${account})"
        else
            check_fail "Not authenticated"
        fi
    else
        check_fail "AWS CLI error"
    fi
fi

# Wrangler (Cloudflare)
check_start "Wrangler"
if ! command -v wrangler &> /dev/null; then
    check_fail "wrangler not installed"
else
    if result=$(wrangler whoami 2>&1); then
        if echo "$result" | grep -q "You are logged in"; then
            check_ok "(Cloudflare)"
        else
            check_fail "Not authenticated"
        fi
    else
        check_fail "Wrangler error"
    fi
fi

# Tailscale
check_start "Tailscale"
if ! command -v tailscale &> /dev/null; then
    check_fail "tailscale not installed"
else
    if result=$(tailscale status --json 2>&1 | jq -r .Self.HostName 2>&1); then
        if [[ -n "$result" && "$result" != "null" ]]; then
            check_ok "(${result})"
        else
            check_fail "Not connected"
        fi
    else
        check_fail "Tailscale error"
    fi
fi

echo ""

# ==========================================
# VAULT
# ==========================================
echo "🔐 HashiCorp Vault"
echo "---"

check_start "Vault Status"
if ! command -v vault &> /dev/null; then
    check_fail "vault not installed"
else
    if result=$(vault status 2>&1); then
        if echo "$result" | grep -q "Sealed.*false"; then
            check_ok "(Unsealed)"
            
            # Try to list secrets
            check_start "Vault Secrets"
            if vault kv list secret/ &>/dev/null; then
                count=$(vault kv list -format=json secret/ 2>/dev/null | jq '. | length' 2>/dev/null || echo "?")
                check_ok "(${count} secrets)"
            else
                check_fail "Cannot list secrets"
            fi
        else
            check_fail "Vault sealed or unreachable"
        fi
    else
        check_fail "Vault error"
    fi
fi

echo ""

# ==========================================
# X/TWITTER
# ==========================================
echo "🐦 X/Twitter"
echo "---"

check_start "X API"
if [[ -f ~/.openclaw/.x-env ]]; then
    source ~/.openclaw/.x-env
    
    if [[ -z "${X_BEARER_TOKEN:-}" ]]; then
        check_missing
    else
        # Test with a simple user lookup
        if result=$(curl -sf -H "Authorization: Bearer $X_BEARER_TOKEN" \
            "https://api.twitter.com/2/users/by/username/twitter" 2>&1); then
            if echo "$result" | jq -e .data &>/dev/null; then
                check_ok "(API v2 accessible)"
            else
                error=$(echo "$result" | jq -r .title 2>/dev/null || echo "Unknown error")
                check_fail "$error"
            fi
        else
            check_fail "Connection failed"
        fi
    fi
else
    check_fail "~/.openclaw/.x-env not found"
fi

echo ""
echo "================================"
echo "Summary"
echo "================================"
echo -e "Total credentials: ${TOTAL}"
echo -e "${GREEN}✅ Working: ${WORKING}${NC}"
echo -e "${YELLOW}⚠️  Missing: ${MISSING}${NC}"
echo -e "${RED}❌ Failed: ${FAILED}${NC}"
echo ""

if [[ $FAILED -eq 0 && $MISSING -eq 0 ]]; then
    echo -e "${GREEN}🎉 All credentials healthy!${NC}"
    exit 0
elif [[ $FAILED -eq 0 ]]; then
    echo -e "${YELLOW}⚠️  Some credentials missing but none failed${NC}"
    exit 0
else
    echo -e "${RED}⚠️  Some credentials need attention${NC}"
    exit 1
fi
