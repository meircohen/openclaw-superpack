#!/bin/bash
# fix-mc-dns.sh — Automated DNS fix for mc.bigcohen.org
# Updates DNS from Cloudflare Pages to Cloudflare Tunnel

set -euo pipefail

ZONE_ID="e4ced4d95a92118e15ca8995ab280d3e"
SUBDOMAIN="mc"
TUNNEL_TARGET="7993ed34-f64b-41a8-85c0-49122d5ff292.cfargotunnel.com"
FULL_DOMAIN="mc.bigcohen.org"

# Check for Cloudflare API token
if [[ -z "${CLOUDFLARE_API_TOKEN:-}" ]]; then
  echo "❌ Error: CLOUDFLARE_API_TOKEN not set"
  echo "Source ~/.openclaw/.api-keys or set it manually"
  exit 1
fi

echo "🔐 Verifying API token..."
TOKEN_CHECK=$(curl -s "https://api.cloudflare.com/client/v4/user/tokens/verify" \
  -H "Authorization: Bearer $CLOUDFLARE_API_TOKEN")

if ! echo "$TOKEN_CHECK" | jq -e '.success' > /dev/null 2>&1; then
  echo "❌ Token verification failed:"
  echo "$TOKEN_CHECK" | jq -r '.errors[] | "  \(.message)"'
  exit 1
fi

echo "✅ Token valid"
echo ""

echo "🔍 Fetching current DNS record for $FULL_DOMAIN..."

# Get existing DNS record
RECORD_JSON=$(curl -s -X GET \
  "https://api.cloudflare.com/client/v4/zones/$ZONE_ID/dns_records?name=$FULL_DOMAIN" \
  -H "Authorization: Bearer $CLOUDFLARE_API_TOKEN" \
  -H "Content-Type: application/json")

# Check for API errors
if ! echo "$RECORD_JSON" | jq -e '.success' > /dev/null 2>&1; then
  echo "❌ API Error:"
  echo "$RECORD_JSON" | jq -r '.errors[] | "  \(.message)"'
  exit 1
fi

# Extract record ID and current target
RECORD_ID=$(echo "$RECORD_JSON" | jq -r '.result[0].id // empty')
CURRENT_TARGET=$(echo "$RECORD_JSON" | jq -r '.result[0].content // "NOT_FOUND"')
CURRENT_TYPE=$(echo "$RECORD_JSON" | jq -r '.result[0].type // "NOT_FOUND"')
PROXIED=$(echo "$RECORD_JSON" | jq -r '.result[0].proxied // false')

if [[ -z "$RECORD_ID" ]]; then
  echo "❌ No DNS record found for $FULL_DOMAIN"
  echo "Expected record to exist. Check Cloudflare dashboard."
  exit 1
fi

echo "✅ Found record:"
echo "   Type: $CURRENT_TYPE"
echo "   Target: $CURRENT_TARGET"
echo "   Proxied: $PROXIED"
echo ""

# Check if already pointing to tunnel
if [[ "$CURRENT_TARGET" == "$TUNNEL_TARGET" ]]; then
  echo "✅ DNS already points to tunnel: $TUNNEL_TARGET"
  echo "   No changes needed."
  exit 0
fi

# Confirm update
echo "⚠️  About to update DNS:"
echo "   FROM: $CURRENT_TARGET"
echo "   TO:   $TUNNEL_TARGET"
echo ""
read -p "Continue? (y/N) " -n 1 -r
echo ""

if [[ ! $REPLY =~ ^[Yy]$ ]]; then
  echo "Aborted."
  exit 0
fi

# Update DNS record
echo "🔧 Updating DNS record..."

UPDATE_JSON=$(curl -s -X PATCH \
  "https://api.cloudflare.com/client/v4/zones/$ZONE_ID/dns_records/$RECORD_ID" \
  -H "Authorization: Bearer $CLOUDFLARE_API_TOKEN" \
  -H "Content-Type: application/json" \
  --data "{
    \"type\": \"CNAME\",
    \"name\": \"$SUBDOMAIN\",
    \"content\": \"$TUNNEL_TARGET\",
    \"proxied\": true,
    \"ttl\": 1
  }")

# Check update result
if echo "$UPDATE_JSON" | jq -e '.success' > /dev/null 2>&1; then
  echo "✅ DNS updated successfully!"
  echo ""
  echo "New configuration:"
  echo "$UPDATE_JSON" | jq -r '.result | "   Type: \(.type)\n   Name: \(.name)\n   Target: \(.content)\n   Proxied: \(.proxied)"'
  echo ""
  echo "⏳ DNS propagation may take 1-2 minutes."
  echo ""
  echo "Test with:"
  echo "   curl -sI https://$FULL_DOMAIN/_next/static/chunks/0a483cefec54818a.css | head -1"
  echo "   Should return: HTTP/2 200 OK"
else
  echo "❌ Update failed:"
  echo "$UPDATE_JSON" | jq -r '.errors[] | "  \(.message)"'
  exit 1
fi

# Optional: Test after short delay
echo ""
read -p "Test now? (will wait 10s for propagation) (y/N) " -n 1 -r
echo ""

if [[ $REPLY =~ ^[Yy]$ ]]; then
  echo "⏳ Waiting 10 seconds for DNS propagation..."
  sleep 10
  
  echo "🧪 Testing CSS endpoint..."
  HTTP_STATUS=$(curl -sI "https://$FULL_DOMAIN/_next/static/chunks/0a483cefec54818a.css" | head -1)
  
  echo "   $HTTP_STATUS"
  
  if echo "$HTTP_STATUS" | grep -q "200 OK"; then
    echo "✅ Success! Site is now working."
  elif echo "$HTTP_STATUS" | grep -q "502"; then
    echo "⚠️  Still returning 502. DNS may need more time to propagate."
    echo "   Wait another minute and test again."
  else
    echo "⚠️  Unexpected response. Check manually:"
    echo "   https://$FULL_DOMAIN"
  fi
fi

echo ""
echo "Done."
