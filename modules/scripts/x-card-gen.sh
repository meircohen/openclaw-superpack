#!/bin/bash
# Generate Twitter media card from template
# Usage: bash x-card-gen.sh output.png "BADGE" "Headline" "v1" "l1" "v2" "l2" "v3" "l3" "v4" "l4" "author" "subtitle" "timestamp"

OUTPUT="$1"
BADGE="$2"
HEADLINE="$3"
S1V="$4"; S1L="$5"
S2V="$6"; S2L="$7"
S3V="$8"; S3L="$9"
S4V="${10}"; S4L="${11}"
AUTHOR="${12}"
LIVE="${13}"
TIMESTAMP="${14:-$(date '+%b %d, %Y · %I:%M %p ET')}"

TEMPLATE_DIR="$(dirname "$0")"
TMPHTML="/tmp/x-card-$(date +%s).html"

sed -e "s|BADGE_TEXT|$BADGE|g" \
    -e "s|HEADLINE_TEXT|$HEADLINE|g" \
    -e "s|STAT1_VALUE|$S1V|g" -e "s|STAT1_LABEL|$S1L|g" \
    -e "s|STAT2_VALUE|$S2V|g" -e "s|STAT2_LABEL|$S2L|g" \
    -e "s|STAT3_VALUE|$S3V|g" -e "s|STAT3_LABEL|$S3L|g" \
    -e "s|STAT4_VALUE|$S4V|g" -e "s|STAT4_LABEL|$S4L|g" \
    -e "s|AUTHOR_TEXT|$AUTHOR|g" \
    -e "s|LIVE_TEXT|$LIVE|g" \
    -e "s|TIMESTAMP_TEXT|$TIMESTAMP|g" \
    "$TEMPLATE_DIR/x-media-card.html" > "$TMPHTML"

"/Applications/Google Chrome.app/Contents/MacOS/Google Chrome" \
  --headless=new \
  --disable-gpu \
  --screenshot="$OUTPUT" \
  --window-size=1200,675 \
  --hide-scrollbars \
  --default-background-color=0 \
  "file://$TMPHTML" 2>/dev/null

rm -f "$TMPHTML"
echo "Generated: $OUTPUT"
