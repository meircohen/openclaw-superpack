#!/usr/bin/env bash
# pdf-chat.sh — Extract PDF content and pipe to AI for Q&A
# Usage: bash scripts/pdf-chat.sh <pdf_path> [question]
# If no question provided, just extracts and displays the content

set -euo pipefail

export PATH="/opt/homebrew/opt/openjdk@21/bin:$PATH"
VENV="$HOME/.openclaw/venvs/opendataloader"
EXTRACT_DIR="/tmp/pdf-chat-extract"

mkdir -p "$EXTRACT_DIR"

PDF="${1:-}"
QUESTION="${2:-}"

if [ -z "$PDF" ]; then
  echo "Usage: bash scripts/pdf-chat.sh <pdf_path> [question]"
  echo ""
  echo "Examples:"
  echo "  bash scripts/pdf-chat.sh report.pdf"
  echo "  bash scripts/pdf-chat.sh report.pdf 'What are the key findings?'"
  exit 1
fi

source "$VENV/bin/activate"

echo "Extracting: $(basename "$PDF")"

python3 -c "
import opendataloader_pdf
import sys

opendataloader_pdf.convert(
    input_path=[sys.argv[1]],
    output_dir=sys.argv[2],
    format='markdown'
)
" "$PDF" "$EXTRACT_DIR" 2>&1 | grep -v "^INFO:\|^WARNING:\|^Mar "

# Get the markdown filename
BASENAME=$(basename "$PDF" .pdf)
MD_FILE="$EXTRACT_DIR/${BASENAME}.md"

if [ ! -f "$MD_FILE" ]; then
  echo "Error: extraction failed, no markdown output"
  exit 1
fi

SIZE=$(wc -c < "$MD_FILE")
LINES=$(wc -l < "$MD_FILE")
echo "Extracted: ${LINES} lines, ${SIZE} bytes"
echo ""

if [ -z "$QUESTION" ]; then
  echo "=== EXTRACTED CONTENT ==="
  cat "$MD_FILE"
else
  echo "Content extracted. Question: $QUESTION"
  echo "(Pipe to your preferred AI tool or use within OpenClaw session)"
  echo ""
  echo "--- PDF Content ---"
  cat "$MD_FILE"
  echo ""
  echo "--- Question ---"
  echo "$QUESTION"
fi

deactivate
