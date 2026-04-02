#!/usr/bin/env bash
set -euo pipefail

# Financial State Refresh Script
# Auto-updates: BTC prices, market data, timestamps
# Flags: Stale manual fields (JPM, LOC, DAF, mortgage)

WORKSPACE="/Users/meircohen/.openclaw/workspace"
STATE_FILE="$WORKSPACE/financial-state.json"
TEMP_FILE="$(mktemp)"

# Ensure jq is available
if ! command -v jq &> /dev/null; then
    echo "Error: jq is required but not installed"
    exit 1
fi

# Read existing state
if [[ ! -f "$STATE_FILE" ]]; then
    echo "Error: $STATE_FILE not found"
    exit 1
fi

STATE=$(cat "$STATE_FILE")

# Get current date
NOW=$(date -u +"%Y-%m-%dT%H:%M:%SZ")
TODAY=$(date +"%Y-%m-%d")

# Calculate staleness (days since as_of date)
AS_OF=$(echo "$STATE" | jq -r '.as_of')
if [[ "$OSTYPE" == "darwin"* ]]; then
    AS_OF_EPOCH=$(date -j -f "%Y-%m-%d" "$AS_OF" +%s 2>/dev/null || echo 0)
    TODAY_EPOCH=$(date +%s)
else
    AS_OF_EPOCH=$(date -d "$AS_OF" +%s 2>/dev/null || echo 0)
    TODAY_EPOCH=$(date +%s)
fi
STALE_DAYS=$(( (TODAY_EPOCH - AS_OF_EPOCH) / 86400 ))

# Fetch BTC price
echo "Fetching BTC price..."
BTC_DATA=$(curl -sf --max-time 10 "https://api.coincap.io/v2/assets/bitcoin" 2>/dev/null || echo '{}')
BTC_PRICE=$(echo "$BTC_DATA" | jq -r '.data.priceUsd // "0"')
BTC_CHANGE_24H=$(echo "$BTC_DATA" | jq -r '.data.changePercent24Hr // "0"')

BTC_FETCH_SUCCESS=false
if [[ "$BTC_PRICE" != "0" ]] && [[ "$BTC_PRICE" != "null" ]]; then
    BTC_FETCH_SUCCESS=true
else
    echo "⚠️  Warning: Failed to fetch BTC price (network issue), preserving existing data"
    BTC_PRICE=$(echo "$STATE" | jq -r '.btc.price_usd // 0')
    BTC_CHANGE_24H=$(echo "$STATE" | jq -r '.btc.change_24h_pct // 0')
fi

# Calculate BTC holdings values
PERSONAL_BTC=$(echo "$STATE" | jq -r '.btc.personal_btc')
PERSONAL_BTC_VALUE=$(echo "$BTC_PRICE * $PERSONAL_BTC" | bc -l | xargs printf "%.0f")

# Burton Trust BTC calculation: ~$5.26M at ~$68.5K = ~76.78 BTC
BURTON_BTC_APPROX=76.78
BURTON_BTC_VALUE=$(echo "$BTC_PRICE * $BURTON_BTC_APPROX" | bc -l | xargs printf "%.0f")

# Fetch Fear & Greed Index (alternative.me API)
echo "Fetching Fear & Greed Index..."
FNG_DATA=$(curl -sf --max-time 10 "https://api.alternative.me/fng/?limit=1" 2>/dev/null || echo '{}')
FNG_VALUE=$(echo "$FNG_DATA" | jq -r '.data[0].value // "0"')
FNG_CLASS=$(echo "$FNG_DATA" | jq -r '.data[0].value_classification // "unknown"')

FNG_FETCH_SUCCESS=false
if [[ "$FNG_VALUE" != "0" ]] && [[ "$FNG_VALUE" != "null" ]]; then
    FNG_FETCH_SUCCESS=true
else
    echo "⚠️  Warning: Failed to fetch Fear & Greed Index, preserving existing data"
    FNG_VALUE=$(echo "$STATE" | jq -r '.btc.fear_greed_index // 0')
    FNG_CLASS=$(echo "$STATE" | jq -r '.btc.fear_greed_class // "unknown"')
fi

# Build staleness report as JSON array
if [[ $STALE_DAYS -gt 30 ]]; then
    STALE_FIELDS_JSON='["investments", "banking", "daf", "loc", "mortgage"]'
else
    STALE_FIELDS_JSON='[]'
fi

# Update JSON with new data and metadata
echo "$STATE" | jq --arg now "$NOW" \
    --arg today "$TODAY" \
    --arg btc_price "$BTC_PRICE" \
    --arg btc_change "$BTC_CHANGE_24H" \
    --arg personal_value "$PERSONAL_BTC_VALUE" \
    --arg burton_value "$BURTON_BTC_VALUE" \
    --arg fng "$FNG_VALUE" \
    --arg fng_class "$FNG_CLASS" \
    --arg stale_days "$STALE_DAYS" \
    --argjson stale_fields "$STALE_FIELDS_JSON" \
    '
    .btc.price_usd = ($btc_price | tonumber) |
    .btc.change_24h_pct = ($btc_change | tonumber) |
    .btc.personal_btc_value = ($personal_value | tonumber) |
    .btc.burton_trust_btc_value = ($burton_value | tonumber) |
    .btc.burton_trust_btc_approx = 76.78 |
    .btc.fear_greed_index = ($fng | tonumber) |
    .btc.fear_greed_class = $fng_class |
    ._meta = {
        last_auto_refresh: $now,
        refreshed_fields: ["btc_price", "btc_market_data"],
        stale_fields: $stale_fields,
        stale_days: ($stale_days | tonumber),
        stale_since: .as_of,
        notes: "Manual update required for: investments, banking, daf, loc, mortgage"
    }
    ' > "$TEMP_FILE"

# Validate JSON
if jq empty "$TEMP_FILE" 2>/dev/null; then
    mv "$TEMP_FILE" "$STATE_FILE"
    echo "✅ Financial state refreshed successfully"
else
    echo "❌ Error: Generated invalid JSON"
    rm "$TEMP_FILE"
    exit 1
fi

# Print summary
echo ""
echo "📊 Refresh Summary"
echo "=================="

# Show what was actually refreshed
REFRESHED=()
if [[ "$BTC_FETCH_SUCCESS" == "true" ]]; then
    REFRESHED+=("BTC price")
fi
if [[ "$FNG_FETCH_SUCCESS" == "true" ]]; then
    REFRESHED+=("Fear & Greed")
fi

if [[ ${#REFRESHED[@]} -gt 0 ]]; then
    echo "✅ Refreshed: ${REFRESHED[*]}"
else
    echo "⚠️  No new data fetched (network issue or API down)"
fi

echo "BTC price: \$$(printf '%0.2f' "$BTC_PRICE"), 24h change: ${BTC_CHANGE_24H}%"
echo "Fear & Greed: $FNG_CLASS ($FNG_VALUE)"
echo "Personal BTC: \$$(printf '%0.0f' "$PERSONAL_BTC_VALUE") (${PERSONAL_BTC} BTC)"
echo "Burton Trust BTC: \$$(printf '%0.0f' "$BURTON_BTC_VALUE") (~${BURTON_BTC_APPROX} BTC)"

if [[ $STALE_DAYS -gt 0 ]]; then
    echo ""
    echo "⚠️  Stale Data (${STALE_DAYS} days since ${AS_OF}):"
    if [[ $STALE_DAYS -gt 30 ]]; then
        echo "   - JPM investments, banking, DAF, LOC, mortgage (CRITICAL: >30 days)"
    else
        echo "   - Manual fields aging but < 30 days"
    fi
fi
