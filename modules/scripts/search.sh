#!/bin/bash
# SearXNG web search wrapper
# Usage: search.sh "query" [--engines google,bing] [--max 5]
QUERY="$1"
ENGINES="${2:-}"
MAX="${3:-5}"

if [ -z "$QUERY" ]; then
  echo "Usage: search.sh \"query\" [engines] [max_results]"
  exit 1
fi

URL="http://localhost:8888/search?q=$(python3 -c "import urllib.parse; print(urllib.parse.quote('$QUERY'))")&format=json"
if [ -n "$ENGINES" ]; then
  URL="${URL}&engines=${ENGINES}"
fi

curl -s "$URL" | python3 -c "
import json,sys
d=json.load(sys.stdin)
for r in d.get('results',[])[:${MAX}]:
    title = r.get('title','')
    url = r.get('url','')
    eng = r.get('engine','')
    snippet = r.get('content','')[:150]
    print(f'[{eng}] {title}')
    print(f'  {url}')
    if snippet: print(f'  {snippet}')
    print()
"
