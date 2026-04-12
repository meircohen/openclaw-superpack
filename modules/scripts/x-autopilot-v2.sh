#!/usr/bin/env bash
# x-autopilot-v2.sh — Fast autonomous X content engine
# Uses python directly for reply generation instead of openclaw agent
set +e  # don't exit on errors, we handle them

WORKSPACE="$HOME/.openclaw/workspace"
TWITTER="$HOME/Library/Python/3.9/bin/twitter"
MEDIA_SCRIPT="$WORKSPACE/scripts/x-post-media.py"
STATE_DIR="$WORKSPACE/state"
LOG="$WORKSPACE/artifacts/x-engagement-log.jsonl"
POSTED_FILE="$STATE_DIR/x-autopilot-posted.txt"
mkdir -p "$STATE_DIR"
touch "$POSTED_FILE"

# Rotate lanes each run
HOUR=$(date +%H)
case $((HOUR % 4)) in
    0) LANE="ai"; ACCOUNTS="gkisokay coreyganim johann_sath AlexFinn RoundtableSpace bcherny" ;;
    1) LANE="israel"; ACCOUNTS="Awesome_Jew_ ShaisTaub FarroYossi" ;;
    2) LANE="politics"; ACCOUNTS="libsoftiktok TuckerCarlson MarioNawfal" ;;
    3) LANE="world"; ACCOUNTS="unusual_whales CoinDesk BitcoinNews Cointelegraph elonmusk" ;;
esac

# Shabbos guard
SHABBOS_CHECK=$(bash "$WORKSPACE/scripts/time-awareness.sh" check-shabbos 2>/dev/null || echo "unknown")
if echo "$SHABBOS_CHECK" | grep -qi "shabbos\|true"; then
    echo "🕯️ Shabbos detected. No posting."
    exit 0
fi

echo "🤖 X Autopilot v2 | Lane: $LANE | $(date)"

POSTS=0
MAX=3

for handle in $ACCOUNTS; do
    [ "$POSTS" -ge "$MAX" ] && break
    
    echo "📡 @$handle..."
    
    # Get recent high-engagement posts
    TWEETS=$($TWITTER user-posts "$handle" --json 2>/dev/null | /usr/bin/python3 -c "
import json, sys
d = json.load(sys.stdin)
for t in d.get('data', [])[:3]:
    m = t['metrics']
    if m['views'] < 5000: continue
    text = t['text'][:280].replace('\n', ' ').replace('|', ' ')
    print(f'{t[\"id\"]}|{m[\"likes\"]}|{m[\"views\"]}|{text}')
" 2>/dev/null) || continue
    
    while IFS='|' read -r tid likes views text; do
        [ -z "$tid" ] && continue
        grep -q "$tid" "$POSTED_FILE" 2>/dev/null && continue
        [ "$POSTS" -ge "$MAX" ] && break
        
        echo "  💬 $tid ($likes L, $views V)"
        
        # Generate reply using Gemini
        source "$HOME/.openclaw/.api-keys"
        export GEMINI_API_KEY
        export X_LANE="$LANE"
        export X_HANDLE="$handle"
        export X_TEXT="$text"
        REPLY=$(/usr/bin/python3 -c '
import json, urllib.request, os
key = os.environ["GEMINI_API_KEY"]
lane = os.environ["X_LANE"]
handle = os.environ["X_HANDLE"]
text = os.environ["X_TEXT"]
url = f"https://generativelanguage.googleapis.com/v1beta/models/gemini-2.5-flash:generateContent?key={key}"
prompt = f"ghostwrite a tweet reply as @MeirCohen.\n\nvoice: human not AI, lowercase ok, no em dashes (never use the character —), dry sarcasm, punchy. max 250 chars. no hashtags. no quotes around it. no preamble. just the reply text.\n\nlane: {lane}\nreplying to @{handle}: {text}\n\nreply:"
body = json.dumps({"contents":[{"parts":[{"text": prompt}]}],"generationConfig":{"maxOutputTokens":200,"temperature":1.0}})
req = urllib.request.Request(url, data=body.encode(), headers={"Content-Type":"application/json"})
try:
    resp = urllib.request.urlopen(req, timeout=15)
    d = json.loads(resp.read())
    t = d["candidates"][0]["content"]["parts"][0]["text"].strip().strip(chr(34)).strip(chr(39))
    # Truncate to 280 chars
    if len(t) > 270: t = t[:267] + "..."
    print(t)
except Exception as e:
    import sys; print(f"ERR: {e}", file=sys.stderr)
' 2>/dev/null) || continue
        
        [ -z "$REPLY" ] && continue
        
        echo "  📝 $REPLY"
        
        # Post it
        RESULT=$($TWITTER post "$REPLY" --reply-to "$tid" 2>&1) || continue
        
        if echo "$RESULT" | grep -q "success"; then
            REPLY_ID=$(echo "$RESULT" | grep -oE 'id: [0-9]+' | head -1 | cut -d' ' -f2)
            [ -z "$REPLY_ID" ] && REPLY_ID=$(echo "$RESULT" | grep -oE '[0-9]{19,}' | head -1)
            
            echo "$tid" >> "$POSTED_FILE"
            POSTS=$((POSTS + 1))
            
            echo "{\"timestamp\":\"$(date -u +%Y-%m-%dT%H:%M:%SZ)\",\"action\":\"autopilot\",\"tweet_id\":\"$tid\",\"author\":\"@$handle\",\"reply_id\":\"$REPLY_ID\",\"lane\":\"$LANE\",\"reply\":\"$REPLY\"}" >> "$LOG"
            
            # Notify
            openclaw message send --channel telegram --target 950148415 \
                --message "🤖 Autopilot ($LANE)

↩️ @$handle ($views views):
\"$(echo "$REPLY" | head -c 200)\"

🔗 https://x.com/i/status/$REPLY_ID" 2>/dev/null &
            
            echo "  ✅ $REPLY_ID"
            sleep 3
        fi
        
    done <<< "$TWEETS"
done

echo "🏁 Done: $POSTS posts"
