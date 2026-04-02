---
name: n8n-workflow-proxy
description: Delegate API calls to n8n workflows via webhooks for credential isolation and observability
read_when: "user wants n8n integration, credential isolation, webhook proxy pattern, or secure API delegation"
---

# n8n Workflow Proxy

Delegate all external API interactions to n8n workflows via webhooks. The agent never touches credentials.

## Why This Pattern

- **Security**: API keys live in n8n's credential store, not in .env
- **Observability**: Every workflow is visually inspectable in n8n's UI
- **Performance**: Deterministic sub-tasks run as workflows, not LLM calls
- **Lockable**: Once tested, lock workflows so the agent cannot modify them

## Architecture

```
Agent  --webhook call-->  n8n Workflow  --API call-->  External Service
       (no credentials)   (locked, keys)               (Slack, etc)
```

## Setup

### Docker Stack (recommended)
```bash
git clone https://github.com/caprihan/openclaw-n8n-stack.git
cd openclaw-n8n-stack && cp .env.template .env
# Add Anthropic API key to .env
docker-compose up -d
```

### Agent Instructions

Add to your AGENTS.md:
```
When interacting with external APIs:
1. NEVER store API keys in environment or skill files
2. Check if an n8n workflow exists for this integration
3. If not, create one via n8n API with a webhook trigger
4. Notify user to add credentials and lock the workflow
5. Call webhook URL with JSON payload for all future calls

Naming: openclaw-{service}-{action}
Example: openclaw-slack-send-message

Call format:
curl -X POST http://n8n:5678/webhook/{workflow-name} \
  -H "Content-Type: application/json" \
  -d '{"channel": "#general", "message": "Hello"}'
```

## Workflow Lifecycle

1. Agent designs the workflow
2. Agent builds it in n8n via API (with webhook trigger)
3. User adds credentials in n8n UI
4. User locks the workflow
5. Agent calls the webhook from now on

## Key Rules

- Build, test, then LOCK -- without locking, agent can silently modify workflows
- n8n has 400+ integrations -- most services already have nodes
- Every execution is logged with input/output data (free audit trail)
