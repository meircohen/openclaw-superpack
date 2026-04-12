#!/bin/bash
# Wrapper for Todoist CLI that sources API token

if [ -f ~/.openclaw/.api-keys ]; then
  source ~/.openclaw/.api-keys
fi

if [ -z "$TODOIST_API_TOKEN" ]; then
  echo "Error: TODOIST_API_TOKEN not set"
  echo "Get token from: https://todoist.com/prefs/integrations"
  echo "Add to ~/.openclaw/.api-keys: export TODOIST_API_TOKEN=your_token"
  exit 1
fi

# Call actual Todoist CLI with all args
todoist "$@"
