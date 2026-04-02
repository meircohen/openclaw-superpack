#!/bin/bash
set -euo pipefail

# propagate-improvement.sh — Register and propagate improvements across agents
# Usage: ./propagate-improvement.sh <type> <description> <files...>
#   type: universal | shared | role-specific
#   description: what changed and why
#   files: space-separated list of files that were changed
#
# Example: ./propagate-improvement.sh universal "Better error recovery" AGENTS.md config/error-patterns.json

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
NC='\033[0m'

TYPE="${1:?Usage: propagate-improvement.sh <universal|shared|role-specific> <description> <files...>}"
DESC="${2:?Missing description}"
shift 2
FILES=("$@")

REGISTRY="$HOME/.openclaw/workspace/improvements/registry.json"
DATE=$(date +%Y-%m-%d)
MAC_USER="meircohen"
REB_HOST="$MAC_USER@100.126.105.8"  # Reb via Tailscale

echo -e "${CYAN}[propagate]${NC} Registering improvement: $DESC"
echo -e "${CYAN}[propagate]${NC} Type: $TYPE | Files: ${FILES[*]}"

# Register in registry.json
python3 -c "
import json, sys
with open('$REGISTRY') as f:
    reg = json.load(f)

imp = reg.get('improvements', [])
next_id = f'imp-{len(imp)+1:03d}'

entry = {
    'id': next_id,
    'date': '$DATE',
    'type': '$TYPE',
    'description': '$DESC',
    'files_changed': sys.argv[1:],
    'applied_to': ['oz'],
    'pending': []
}

if '$TYPE' == 'universal':
    entry['pending'] = ['homebot', 'reb']
elif '$TYPE' == 'shared':
    entry['pending'] = ['homebot']

imp.append(entry)
reg['improvements'] = imp
with open('$REGISTRY', 'w') as f:
    json.dump(reg, f, indent=2)

print(f'Registered as {next_id}')
" "${FILES[@]}"

# If universal, attempt to propagate to Reb
if [ "$TYPE" = "universal" ]; then
    echo -e "${YELLOW}[propagate]${NC} Universal improvement — propagating to Reb..."
    
    for FILE in "${FILES[@]}"; do
        SRC="$HOME/.openclaw/workspace/$FILE"
        if [ -f "$SRC" ]; then
            echo -e "  Syncing $FILE to Reb..."
            scp -o ConnectTimeout=10 "$SRC" "$REB_HOST:/home/$MAC_USER/.openclaw/workspace/$FILE" 2>/dev/null && \
                echo -e "  ${GREEN}✅ $FILE synced${NC}" || \
                echo -e "  ${RED}⚠️ $FILE failed to sync${NC}"
        fi
    done
    
    echo -e "${GREEN}[propagate]${NC} Update Reb's registry..."
    scp -o ConnectTimeout=10 "$REGISTRY" "$REB_HOST:/home/$MAC_USER/.openclaw/workspace/improvements/registry.json" 2>/dev/null && \
        echo -e "${GREEN}✅ Registry synced to Reb${NC}" || \
        echo -e "${RED}⚠️ Registry sync failed${NC}"
fi

echo -e "${GREEN}[propagate]${NC} Done."
