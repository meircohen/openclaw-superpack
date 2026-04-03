#!/usr/bin/env bash
# File.io - Ephemeral file sharing (auto-deletes after download)
# API Docs: https://www.file.io/
# Usage: bash fileio.sh upload <filepath> [expiry]
# Usage: bash fileio.sh info <key>

set -euo pipefail

PRETTY=0
[[ "${1:-}" == "--pretty" ]] && PRETTY=1 && shift

action="${1:-}"
[[ -z "$action" ]] && {
  echo "Usage: $0 [upload <filepath> [expiry]|info <key>]" >&2
  echo "Examples:" >&2
  echo "  $0 upload document.pdf 1w" >&2
  echo "  $0 upload image.png" >&2
  echo "  $0 info abc123def" >&2
  echo "Expiry: 1d, 1w, 1m, 1y (default: 14d)" >&2
  exit 1
}

case "$action" in
  upload)
    [[ -z "${2:-}" ]] && echo "Error: filepath required" >&2 && exit 1
    [[ ! -f "$2" ]] && echo "Error: file not found: $2" >&2 && exit 1
    filepath="$2"
    expiry="${3:-14d}"
    
    response=$(curl -sS -f -F "file=@${filepath}" "https://file.io/?expires=${expiry}" 2>&1) || {
      echo "Error: Upload failed" >&2
      exit 1
    }
    ;;
  info)
    [[ -z "${2:-}" ]] && echo "Error: file key required" >&2 && exit 1
    key="$2"
    
    response=$(curl -sS -f "https://file.io/${key}/info" 2>&1) || {
      echo "Error: Info request failed" >&2
      exit 1
    }
    ;;
  *)
    echo "Error: Unknown action: $action" >&2
    exit 1
    ;;
esac

success=$(echo "$response" | jq -r '.success // false')
[[ "$success" != "true" ]] && {
  message=$(echo "$response" | jq -r '.message // "Unknown error"')
  echo "Error: $message" >&2
  exit 1
}

if [[ $PRETTY -eq 1 ]]; then
  echo "$response" | jq '.'
else
  echo "$response" | jq -c '.'
fi
