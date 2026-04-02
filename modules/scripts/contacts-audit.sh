#!/usr/bin/env bash
# Contact Registry Audit Script
# Scans memory files for people, compares against contacts-registry.json

set -euo pipefail

WORKSPACE="${WORKSPACE:-$HOME/.openclaw/workspace}"
REGISTRY="$WORKSPACE/config/knowledge/contacts-registry.json"
MEMORY_DIR="$WORKSPACE/memory"
MEMORY_FILE="$WORKSPACE/MEMORY.md"

# Color codes for output
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m' # No Color

# Check if registry exists
if [[ ! -f "$REGISTRY" ]]; then
    echo -e "${RED}Error: contacts-registry.json not found at $REGISTRY${NC}"
    exit 1
fi

# Extract registered names (case-insensitive comparison)
registered_names=$(jq -r '.contacts[].name' "$REGISTRY" | tr '[:upper:]' '[:lower:]')

# Find capitalized two-word names in memory files
# Pattern: [A-Z][a-z]+ [A-Z][a-z]+ (basic NER)
temp_names=$(mktemp)

# Scan MEMORY.md
if [[ -f "$MEMORY_FILE" ]]; then
    grep -oE '\b[A-Z][a-z]+\s+[A-Z][a-z]+\b' "$MEMORY_FILE" | sort | uniq -c | sort -rn >> "$temp_names" || true
fi

# Scan all memory/*.md files
if [[ -d "$MEMORY_DIR" ]]; then
    find "$MEMORY_DIR" -name "*.md" -type f -exec grep -oE '\b[A-Z][a-z]+\s+[A-Z][a-z]+\b' {} \; | sort | uniq -c | sort -rn >> "$temp_names" || true
fi

# Process findings
potential_contacts=()
while IFS= read -r line; do
    count=$(echo "$line" | awk '{print $1}')
    name=$(echo "$line" | sed 's/^[[:space:]]*[0-9]*[[:space:]]*//')
    name_lower=$(echo "$name" | tr '[:upper:]' '[:lower:]')
    
    # Only consider names mentioned 2+ times
    if [[ $count -ge 2 ]]; then
        # Check if already registered (case-insensitive)
        if ! echo "$registered_names" | grep -qi "^${name_lower}$"; then
            # Filter out common false positives (locations, companies, projects, technical terms)
            case "$name" in
                # Locations
                "South Florida"|"New York"|"Palm Beach"|"Lakewood NJ"|"North Carolina"|"Cooper City"|"Fort Lauderdale"|"China Grove"|"East Main"|"Hollywood Blvd"|"Emerald Hills"|"Brookfield Circle"|"Cumberland Crossing"|"Woodland Dr"|"Evergreen Ave"|"Evergreen Avenue"|"Blue Ridge"|"Broward County")
                    continue ;;
                # Organizations/Schools
                "Apple Notes"|"Burton Trust"|"Inner Circle"|"Yeshiva Toras"|"Yeshiva Chofetz"|"Bais Yaakov"|"Home Assistant"|"Google Drive"|"Google Cloud"|"Google Workspace"|"Google Sheet"|"Google Wifi"|"Duke Energy"|"Morgan Stanley"|"State Farm"|"Spirit Airlines"|"Penn Mutual"|"Tesla Florida")
                    continue ;;
                # Projects/Technical Terms
                "Rabbi Leff"|"Agent Room"|"Claude Code"|"Gemini Flash"|"Gemini Pro"|"Oz Voice"|"Master Plan"|"Model Registry"|"Revenue Ops"|"Smart Router"|"Skill Graphs"|"Time Awareness"|"Smart Spawn"|"Cloudflare Pages"|"Claude Max"|"Visual Explainer"|"Token Budget"|"Gateway Status"|"Memory System"|"Knowledge Base"|"System Status"|"System Health"|"Daily Notes"|"Active Tasks"|"Next Steps"|"Key Lessons"|"Action Items"|"Success Rate"|"Agent Health"|"Cron Health"|"Model Cost"|"Tech Stack"|"Business Model"|"Core Services"|"Message Bus"|"Memory Files")
                    continue ;;
                # Generic Terms
                "This Week"|"Next Actions"|"Lessons Learned"|"In Progress"|"Evening Session"|"Critical Issues"|"High Priority"|"Recent Wins"|"Known Issues"|"Key Files"|"Active Work"|"Time Machine"|"Overall Assessment"|"Current Status"|"Current State"|"Major Project"|"Recent Activity"|"Open Loops"|"Active Priorities"|"Last Review"|"Net Worth")
                    continue ;;
                *)
                    potential_contacts+=("$name (mentioned $count times)")
                    ;;
            esac
        fi
    fi
done < "$temp_names"

rm -f "$temp_names"

# Count registered contacts
total_registered=$(jq '.meta.total_contacts' "$REGISTRY")

# Display results
echo -e "${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${GREEN}Contact Registry Audit${NC}"
echo -e "${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo ""
echo -e "📊 ${total_registered} contacts registered"
echo -e "🔍 ${#potential_contacts[@]} potential new contacts found"
echo ""

if [[ ${#potential_contacts[@]} -gt 0 ]]; then
    echo -e "${YELLOW}Potential contacts not in registry:${NC}"
    for contact in "${potential_contacts[@]}"; do
        echo "  • $contact"
    done
    echo ""
    echo -e "${YELLOW}Review these names and add to contacts-registry.json if appropriate.${NC}"
else
    echo -e "${GREEN}✓ No new contacts detected. Registry is up to date.${NC}"
fi

echo ""
echo -e "${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
