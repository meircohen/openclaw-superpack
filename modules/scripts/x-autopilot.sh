#!/usr/bin/env bash
# x-autopilot.sh — Autonomous X content engine
# Scans target accounts, generates visual content, posts replies/quotes
# Notifies Meir on Telegram after each post
set -euo pipefail

WORKSPACE="$HOME/.openclaw/workspace"
TWITTER="$HOME/Library/Python/3.9/bin/twitter"
MEDIA_SCRIPT="$WORKSPACE/scripts/x-post-media.py"
STATE_DIR="$WORKSPACE/state"
LOG="$WORKSPACE/artifacts/x-engagement-log.jsonl"
POSTED_FILE="$STATE_DIR/x-autopilot-posted.txt"
touch "$POSTED_FILE"

# Content lanes and target accounts
AI_ACCOUNTS="gkisokay coreyganim johann_sath AlexFinn RoundtableSpace nurijanian bcherny"
ISRAEL_ACCOUNTS="Awesome_Jew_ ShaisTaub FarroYossi"
POLITICS_ACCOUNTS="libsoftiktok TuckerCarlson MarioNawfal"
WORLD_ACCOUNTS="unusual_whales CoinDesk BitcoinNews Cointelegraph elonmusk"

notify_telegram() {
    local msg="$1"
    openclaw message send --channel telegram --target 950148415 --message "$msg" 2>/dev/null || true
}

already_posted() {
    grep -q "$1" "$POSTED_FILE" 2>/dev/null
}

mark_posted() {
    echo "$1" >> "$POSTED_FILE"
}

log_engagement() {
    local tweet_id="$1" author="$2" topic="$3" reply_id="$4" category="$5" content_type="${6:-text}"
    echo "{\"timestamp\":\"$(date -u +%Y-%m-%dT%H:%M:%SZ)\",\"action\":\"autopilot_reply\",\"tweet_id\":\"$tweet_id\",\"author\":\"@$author\",\"topic\":\"$topic\",\"reply_id\":\"$reply_id\",\"category\":\"$category\",\"content_type\":\"$content_type\"}" >> "$LOG"
}

scan_account() {
    local handle="$1" lane="$2"
    local posts
    posts=$($TWITTER user-posts "$handle" --json 2>/dev/null) || return 0
    
    echo "$posts" | /usr/bin/python3 -c "
import json, sys
d = json.load(sys.stdin)
for t in d.get('data', [])[:5]:
    m = t['metrics']
    # Only high-engagement posts worth replying to
    if m['views'] < 5000: continue
    tid = t['id']
    text = t['text'][:300].replace('\n', ' ')
    likes = m['likes']
    views = m['views']
    print(f'{tid}|{likes}|{views}|{text}')
" 2>/dev/null || true
}

generate_reply() {
    local tweet_text="$1" author="$2" lane="$3"
    
    # Use openclaw agent to generate the reply with proper voice
    local prompt="You are ghostwriting a tweet reply as @MeirCohen. Voice rules: sound human not AI, lowercase energy, no em dashes (—), occasional 'lol' or 'bro', dry sarcasm, short and punchy.

Lane: $lane
Replying to @$author who said: $tweet_text

Write ONLY the reply text, nothing else. Max 260 chars. No hashtags. No quotes around it."

    local reply
    reply=$(openclaw agent --session-id "x-ghost" --message "$prompt" --model "anthropic/claude-haiku-4-5" --thinking off 2>/dev/null | tail -1) || return 1
    
    # Strip any quotes the model might add
    reply=$(echo "$reply" | sed 's/^"//;s/"$//' | sed "s/^'//;s/'$//")
    echo "$reply"
}

should_use_media() {
    local lane="$1" views="$2"
    # Use media for high-view posts and AI/world lanes
    if [ "$views" -gt 50000 ]; then echo "yes"; return; fi
    if [ "$lane" = "ai" ] && [ "$views" -gt 10000 ]; then echo "yes"; return; fi
    echo "no"
}

generate_infographic_reply() {
    local tweet_text="$1" author="$2"
    
    # Create a quick notebook and generate infographic
    local title="Response to @$author"
    local nb_json
    nb_json=$(notebooklm create "$title" --json 2>/dev/null) || return 1
    local nb_id
    nb_id=$(echo "$nb_json" | /usr/bin/python3 -c "import json,sys; print(json.load(sys.stdin)['notebook']['id'])" 2>/dev/null) || return 1
    
    notebooklm use "$nb_id" >/dev/null 2>&1
    
    local tmpfile=$(mktemp /tmp/nb-XXXXX.md)
    cat > "$tmpfile" << SRCEOF
# Context: @$author posted
$tweet_text

Create a compelling, data-driven infographic that adds value to this conversation. Include real statistics, comparisons, or frameworks. Make it shareable and informative.
SRCEOF
    
    notebooklm source add "$tmpfile" >/dev/null 2>&1
    rm -f "$tmpfile"
    
    notebooklm generate infographic --json >/dev/null 2>&1
    
    # Wait up to 3 min
    for i in $(seq 1 12); do
        sleep 15
        local status
        status=$(notebooklm artifact list 2>&1 | grep -i "completed" || true)
        if [ -n "$status" ]; then
            local outfile="$WORKSPACE/x-autopilot-infographic-$(date +%s).png"
            notebooklm download infographic "$outfile" >/dev/null 2>&1
            if [ -f "$outfile" ]; then
                echo "$outfile"
                return 0
            fi
        fi
    done
    return 1
}

post_reply() {
    local tweet_id="$1" reply_text="$2" media_file="${3:-}"
    
    if [ -n "$media_file" ] && [ -f "$media_file" ]; then
        /usr/bin/python3 "$MEDIA_SCRIPT" "$reply_text" "$media_file" --reply-to "$tweet_id" 2>&1
    else
        $TWITTER post "$reply_text" --reply-to "$tweet_id" 2>&1
    fi
}

# ── Main Loop ──────────────────────────────────────────────

POSTS_THIS_RUN=0
MAX_POSTS=4  # Don't spam

echo "🤖 X Autopilot starting at $(date)"

for lane_info in "ai|$AI_ACCOUNTS" "israel|$ISRAEL_ACCOUNTS" "politics|$POLITICS_ACCOUNTS" "world|$WORLD_ACCOUNTS"; do
    lane="${lane_info%%|*}"
    accounts="${lane_info#*|}"
    
    [ "$POSTS_THIS_RUN" -ge "$MAX_POSTS" ] && break
    
    for handle in $accounts; do
        [ "$POSTS_THIS_RUN" -ge "$MAX_POSTS" ] && break
        
        echo "📡 Scanning @$handle ($lane)..."
        
        while IFS='|' read -r tid likes views text; do
            [ -z "$tid" ] && continue
            already_posted "$tid" && continue
            [ "$POSTS_THIS_RUN" -ge "$MAX_POSTS" ] && break
            
            echo "  Found: $tid ($likes L, $views V)"
            
            # Generate reply
            reply=$(generate_reply "$text" "$handle" "$lane" 2>/dev/null) || continue
            [ -z "$reply" ] && continue
            
            # Decide on media
            media_file=""
            use_media=$(should_use_media "$lane" "$views")
            if [ "$use_media" = "yes" ]; then
                echo "  🎨 Generating infographic..."
                media_file=$(generate_infographic_reply "$text" "$handle" 2>/dev/null) || media_file=""
            fi
            
            # Post it
            echo "  📤 Posting reply..."
            result=$(post_reply "$tid" "$reply" "$media_file" 2>&1)
            
            if echo "$result" | grep -q "success\|✅\|url:"; then
                reply_id=$(echo "$result" | grep -oE '[0-9]{19,}' | tail -1)
                mark_posted "$tid"
                POSTS_THIS_RUN=$((POSTS_THIS_RUN + 1))
                
                content_type="text"
                [ -n "$media_file" ] && content_type="infographic"
                log_engagement "$tid" "$handle" "$text" "$reply_id" "$lane" "$content_type"
                
                # Notify Meir
                notify_msg="🤖 X Autopilot posted ($lane)

↩️ Reply to @$handle ($views views):
\"$reply\"

🔗 https://x.com/i/status/$reply_id"
                [ -n "$media_file" ] && notify_msg="$notify_msg
📎 With infographic attached"
                
                notify_telegram "$notify_msg"
                
                echo "  ✅ Posted: $reply_id"
                sleep 5  # Rate limit buffer
            else
                echo "  ❌ Failed: $result"
            fi
            
        done <<< "$(scan_account "$handle" "$lane")"
    done
done

echo "🏁 Autopilot done. $POSTS_THIS_RUN posts this run."
