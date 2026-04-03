#!/usr/bin/env bash
# Open Library - Book search, metadata, covers
# API Docs: https://openlibrary.org/developers/api
# Usage: bash openlibrary.sh [search <query>|isbn <isbn>|author <name>]

set -euo pipefail

PRETTY=0
[[ "${1:-}" == "--pretty" ]] && PRETTY=1 && shift

action="${1:-}"
[[ -z "$action" ]] && {
  echo "Usage: $0 [search <query>|isbn <isbn>|author <name>]" >&2
  echo "Examples:" >&2
  echo "  $0 search 'Foundation Asimov'" >&2
  echo "  $0 isbn 9780553293357" >&2
  echo "  $0 author 'Isaac Asimov'" >&2
  exit 1
}

case "$action" in
  search)
    [[ -z "${2:-}" ]] && echo "Error: search query required" >&2 && exit 1
    query=$(echo "$*" | cut -d' ' -f2- | sed 's/ /+/g')
    url="https://openlibrary.org/search.json?q=${query}"
    ;;
  isbn)
    [[ -z "${2:-}" ]] && echo "Error: ISBN required" >&2 && exit 1
    isbn="$2"
    url="https://openlibrary.org/api/books?bibkeys=ISBN:${isbn}&format=json&jscmd=data"
    ;;
  author)
    [[ -z "${2:-}" ]] && echo "Error: author name required" >&2 && exit 1
    author=$(echo "$*" | cut -d' ' -f2- | sed 's/ /+/g')
    url="https://openlibrary.org/search.json?author=${author}"
    ;;
  *)
    echo "Error: Unknown action: $action" >&2
    exit 1
    ;;
esac

response=$(curl -sS -f "$url" 2>&1) || {
  echo "Error: API request failed" >&2
  exit 1
}

if [[ $PRETTY -eq 1 ]]; then
  echo "$response" | jq '.'
else
  echo "$response" | jq -c '.'
fi
