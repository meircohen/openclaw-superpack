#!/usr/bin/env bash
# x-notebooklm-post.sh - Generate NotebookLM content and post to X
# Usage: bash x-notebooklm-post.sh "topic or file path" [type: audio|infographic|mind-map]
set -euo pipefail

TOPIC="${1:?Usage: x-notebooklm-post.sh 'topic or file' [audio|infographic|mind-map]}"
TYPE="${2:-audio}"
WORKSPACE="$HOME/.openclaw/workspace"
TWITTER_CLI="$HOME/Library/Python/3.9/bin/twitter"
TIMESTAMP=$(date +%s)

echo "📝 Creating notebook for: $TOPIC"

# If topic is a file path, use it as source
if [ -f "$TOPIC" ]; then
    TITLE=$(basename "$TOPIC" | sed 's/\.[^.]*$//')
    NB_JSON=$(notebooklm create "$TITLE" --json 2>&1)
    NB_ID=$(echo "$NB_JSON" | /usr/bin/python3 -c "import json,sys; print(json.load(sys.stdin)['notebook']['id'])")
    echo "📎 Adding source file: $TOPIC"
    notebooklm use "$NB_ID" >/dev/null 2>&1
    notebooklm source add "$TOPIC" >/dev/null 2>&1
else
    # Create notebook with topic as title, add topic text as a note
    NB_JSON=$(notebooklm create "$TOPIC" --json 2>&1)
    NB_ID=$(echo "$NB_JSON" | /usr/bin/python3 -c "import json,sys; print(json.load(sys.stdin)['notebook']['id'])")
    notebooklm use "$NB_ID" >/dev/null 2>&1
    # Add the topic as a note source
    TMPFILE=$(mktemp /tmp/nb-source-XXXXX.md)
    echo "# $TOPIC" > "$TMPFILE"
    echo "" >> "$TMPFILE"
    echo "Write a deep, engaging exploration of this topic. Cover the key insights, controversies, and practical implications. Make it interesting and accessible." >> "$TMPFILE"
    notebooklm source add "$TMPFILE" >/dev/null 2>&1
    rm -f "$TMPFILE"
fi

echo "🎨 Generating $TYPE..."
GEN_OUTPUT=$(notebooklm generate "$TYPE" --json 2>&1)
TASK_ID=$(echo "$GEN_OUTPUT" | /usr/bin/python3 -c "import json,sys; d=json.load(sys.stdin); print(d.get('task_id',''))" 2>/dev/null || echo "")

if [ -z "$TASK_ID" ]; then
    echo "⚠️ No task ID, checking if already generated..."
    TASK_ID=$(echo "$GEN_OUTPUT" | grep -o '[a-f0-9-]\{36\}' | head -1 || true)
fi

echo "⏳ Waiting for generation (task: $TASK_ID)..."
# Poll until done (max 10 min)
for i in $(seq 1 40); do
    sleep 15
    STATUS=$(notebooklm artifact list 2>&1 | tail -3 | head -1)
    if echo "$STATUS" | grep -q "completed"; then
        echo "✅ Generation complete!"
        break
    fi
    echo "  still generating... ($((i*15))s)"
done

# Download
OUTPUT_FILE="$WORKSPACE/x-nb-${TYPE}-${TIMESTAMP}"
case "$TYPE" in
    audio)
        OUTPUT_FILE="${OUTPUT_FILE}.wav"
        notebooklm download audio "$OUTPUT_FILE" 2>&1
        # Convert to mp3 for X
        MP3_FILE="${OUTPUT_FILE%.wav}.mp3"
        ffmpeg -i "$OUTPUT_FILE" -codec:a libmp3lame -q:a 2 "$MP3_FILE" -y 2>/dev/null
        OUTPUT_FILE="$MP3_FILE"
        ;;
    infographic|mind-map)
        OUTPUT_FILE="${OUTPUT_FILE}.png"
        notebooklm download "$TYPE" "$OUTPUT_FILE" 2>&1
        ;;
esac

if [ ! -f "$OUTPUT_FILE" ]; then
    echo "❌ Download failed"
    exit 1
fi

echo "📤 File ready: $OUTPUT_FILE ($(du -h "$OUTPUT_FILE" | cut -f1))"
echo "$OUTPUT_FILE"
