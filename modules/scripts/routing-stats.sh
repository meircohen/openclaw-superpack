#!/bin/bash
# Quick routing statistics dashboard
# Usage: bash routing-stats.sh

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
python3 "$SCRIPT_DIR/routing-stats.py"