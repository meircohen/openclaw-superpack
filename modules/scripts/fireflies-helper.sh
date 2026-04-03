#!/bin/bash
# Fireflies API helper functions

source ~/.openclaw/.api-keys

if [ -z "$FIREFLIES_API_KEY" ]; then
  echo "Error: FIREFLIES_API_KEY not set in ~/.openclaw/.api-keys"
  exit 1
fi

API_URL="https://api.fireflies.ai/graphql"

# List recent meetings
list_meetings() {
  local limit=${1:-10}
  curl -s -X POST "$API_URL" \
    -H "Authorization: Bearer $FIREFLIES_API_KEY" \
    -H "Content-Type: application/json" \
    -d "{\"query\": \"query { transcripts(limit: $limit) { id title date } }\"}" | \
    jq -r '.data.transcripts[] | "\(.date) | \(.title) | \(.id)"'
}

# Get transcript by ID
get_transcript() {
  local meeting_id="$1"
  if [ -z "$meeting_id" ]; then
    echo "Usage: get_transcript <meeting_id>"
    return 1
  fi
  
  curl -s -X POST "$API_URL" \
    -H "Authorization: Bearer $FIREFLIES_API_KEY" \
    -H "Content-Type: application/json" \
    -d "{\"query\": \"query { transcript(id: \\\"$meeting_id\\\") { title date sentences { speaker_name text } } }\"}"
}

# Search meetings with person
search_person() {
  local name="$1"
  if [ -z "$name" ]; then
    echo "Usage: search_person <name>"
    return 1
  fi
  
  curl -s -X POST "$API_URL" \
    -H "Authorization: Bearer $FIREFLIES_API_KEY" \
    -H "Content-Type: application/json" \
    -d '{"query": "query { transcripts(limit: 50) { id title date } }"}' | \
    jq -r ".data.transcripts[] | select(.title | contains(\"$name\"))"
}

# Extract action items (simple pattern matching)
extract_actions() {
  local meeting_id="$1"
  if [ -z "$meeting_id" ]; then
    echo "Usage: extract_actions <meeting_id>"
    return 1
  fi
  
  get_transcript "$meeting_id" | \
    jq -r '.data.transcript.sentences[] | "\(.speaker_name): \(.text)"' | \
    grep -i "I'll\|we need to\|follow up\|action item\|todo\|task"
}

# Show usage
usage() {
  cat << USAGE
Fireflies Helper Script

Commands:
  list_meetings [limit]     List recent meetings (default: 10)
  get_transcript <id>       Get full transcript by meeting ID
  search_person <name>      Find meetings with specific person
  extract_actions <id>      Extract action items from meeting

Examples:
  $0 list_meetings 20
  $0 search_person George
  $0 get_transcript 01KJG0MFN6ZA43FFSV0DDRJYV5
  $0 extract_actions 01KJG0MFN6ZA43FFSV0DDRJYV5
USAGE
}

# Main dispatch
case "${1:-}" in
  list_meetings) list_meetings "${2:-10}" ;;
  get_transcript) get_transcript "$2" ;;
  search_person) search_person "$2" ;;
  extract_actions) extract_actions "$2" ;;
  *) usage ;;
esac
