#!/bin/bash

# BTC Market Intelligence Script
# Gathers price, sentiment, mining data for Meir's positions

echo "=== BTC Market Intelligence Report ==="
echo "Timestamp: $(date)"
echo ""

# Price data from CoinGecko API
echo "=== PRICE & SENTIMENT ==="
curl -s "https://api.coingecko.com/api/v3/simple/price?ids=bitcoin&vs_currencies=usd&include_24hr_change=true&include_market_cap=true" | python3 -c "
import json, sys
try:
    data = json.load(sys.stdin)
    btc = data['bitcoin']
    price = btc['usd']
    change_24h = btc['usd_24h_change']
    mcap = btc['usd_market_cap']
    print(f'Price: \${price:,.0f}')
    print(f'24h Change: {change_24h:+.2f}%')
    print(f'Market Cap: \${mcap/1e9:.1f}B')
except Exception as e:
    print(f'Price API error: {e}')
"

# Fear & Greed Index
echo ""
curl -s "https://api.alternative.me/fng/" | python3 -c "
import json, sys
try:
    data = json.load(sys.stdin)
    fng = data['data'][0]
    value = int(fng['value'])
    classification = fng['value_classification']
    print(f'Fear & Greed Index: {value}/100 ({classification})')
except Exception as e:
    print(f'F&G Index error: {e}')
"

echo ""
echo "=== MINING METRICS ==="

# Mining difficulty and hashrate from blockchain.info
curl -s "https://blockchain.info/q/getdifficulty" | python3 -c "
import sys
try:
    difficulty = float(sys.stdin.read().strip())
    print(f'Current Difficulty: {difficulty:,.0f}')
except Exception as e:
    print(f'Difficulty API error: {e}')
"

curl -s "https://blockchain.info/q/hashrate" | python3 -c "
import sys
try:
    hashrate_th = float(sys.stdin.read().strip()) / 1e12  # Convert to TH/s
    print(f'Network Hashrate: {hashrate_th:,.1f} TH/s')
except Exception as e:
    print(f'Hashrate API error: {e}')
"

# Mempool fee estimate
curl -s "https://mempool.space/api/v1/fees/recommended" | python3 -c "
import json, sys
try:
    data = json.load(sys.stdin)
    fast = data['fastestFee']
    half = data['halfHourFee']
    hour = data['hourFee']
    print(f'Mempool Fees: {fast} sat/vB (fast), {half} sat/vB (30min), {hour} sat/vB (1hr)')
except Exception as e:
    print(f'Mempool API error: {e}')
"

echo ""
echo "=== PORTFOLIO POSITIONS ==="
echo "Personal BTC: 100.735 BTC"
echo "Burton Trust BTC: ~76 BTC"
echo "Combined Holdings: ~176.735 BTC"
echo ""
echo "Report complete."