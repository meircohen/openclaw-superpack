#!/usr/bin/env bash
set -euo pipefail

cd "$HOME/.openclaw/workspace/intelligence"

python3 collector.py
python3 filter.py
python3 act.py
python3 digest.py

if [ "$(date +%u)" = "1" ]; then
  python3 trends.py
fi

if [ -f urgent.json ]; then
  # print urgent.json path for caller (telegram sender handled elsewhere)
  echo "urgent.json present"
fi
