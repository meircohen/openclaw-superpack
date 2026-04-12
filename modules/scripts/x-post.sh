#!/usr/bin/env bash
set -euo pipefail

# Wrapper to post to X via official API using scripts/x-post.py
# Usage:
#   scripts/x-post.sh "text"
#   scripts/x-post.sh --reply-to <tweetId> "text"
#   scripts/x-post.sh --json "text"

cd "$(dirname "$0")/.."

if ! command -v python3 >/dev/null 2>&1; then
  echo "python3 not found" >&2
  exit 2
fi

exec python3 ./scripts/x-post.py "$@"
