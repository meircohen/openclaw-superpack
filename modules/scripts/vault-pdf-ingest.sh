#!/usr/bin/env bash
# vault-pdf-ingest.sh — Parse PDFs from vault into searchable markdown/JSON
# Uses OpenDataLoader PDF for extraction
# Usage: bash scripts/vault-pdf-ingest.sh [path_to_pdf_or_folder]

set -euo pipefail

export PATH="/opt/homebrew/opt/openjdk@21/bin:$PATH"
VENV="$HOME/.openclaw/venvs/opendataloader"
OUTPUT_DIR="$HOME/.openclaw/workspace/vault/pdf-extracts"

mkdir -p "$OUTPUT_DIR"

# Activate venv
source "$VENV/bin/activate"

INPUT="${1:-}"

if [ -z "$INPUT" ]; then
  echo "Usage: bash scripts/vault-pdf-ingest.sh <pdf_file_or_folder>"
  echo ""
  echo "Examples:"
  echo "  bash scripts/vault-pdf-ingest.sh /path/to/file.pdf"
  echo "  bash scripts/vault-pdf-ingest.sh /path/to/folder/"
  echo "  bash scripts/vault-pdf-ingest.sh all  # process all PDFs in vault"
  exit 1
fi

if [ "$INPUT" = "all" ]; then
  echo "Scanning for all PDFs in workspace..."
  INPUT="$HOME/.openclaw/workspace"
fi

echo "=== OpenDataLoader PDF Vault Ingestion ==="
echo "Input: $INPUT"
echo "Output: $OUTPUT_DIR"
echo ""

python3 -c "
import opendataloader_pdf
import sys
import os
import glob
import time

input_path = sys.argv[1]
output_dir = sys.argv[2]

# Collect PDF files
if os.path.isdir(input_path):
    pdfs = glob.glob(os.path.join(input_path, '**/*.pdf'), recursive=True)
    pdfs = [p for p in pdfs if not '/node_modules/' in p and not '/.git/' in p]
else:
    pdfs = [input_path]

print(f'Found {len(pdfs)} PDF(s) to process')

if not pdfs:
    print('No PDFs found.')
    sys.exit(0)

# Batch convert (single JVM spawn)
start = time.time()
opendataloader_pdf.convert(
    input_path=pdfs,
    output_dir=output_dir,
    format='markdown,json'
)
elapsed = time.time() - start

print(f'')
print(f'Done! Processed {len(pdfs)} PDFs in {elapsed:.1f}s')
print(f'Output: {output_dir}')

# List outputs
mds = glob.glob(os.path.join(output_dir, '*.md'))
print(f'Markdown files: {len(mds)}')
for md in sorted(mds)[:10]:
    size = os.path.getsize(md)
    print(f'  {os.path.basename(md)} ({size:,} bytes)')
if len(mds) > 10:
    print(f'  ... and {len(mds)-10} more')
" "$INPUT" "$OUTPUT_DIR" 2>&1

deactivate
