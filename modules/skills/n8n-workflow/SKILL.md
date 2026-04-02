---
name: n8n-workflow
description: Build n8n automation workflows with webhooks, HTTP, database, and AI nodes
read_when: "user wants to build n8n workflows, automate tasks with n8n, or configure n8n nodes"
---

# n8n Workflow Automation

Build automation workflows in n8n connecting webhooks, APIs, databases, and AI.

## Core Concepts

- **Nodes**: Individual operations (HTTP Request, Code, IF, etc.)
- **Connections**: Data flow between nodes
- **Triggers**: What starts a workflow (Webhook, Schedule, Event)
- **Expressions**: `{{ $json.fieldName }}` to reference data

## Common Workflow Patterns

### Webhook to API
```
Webhook (POST) -> Set (transform) -> HTTP Request (external API) -> Respond to Webhook
```

### Scheduled Data Sync
```
Schedule Trigger (every hour) -> HTTP Request (source API) -> Code (transform) -> Postgres (upsert)
```

### AI Processing Pipeline
```
Webhook -> OpenAI (analyze text) -> IF (sentiment check) -> Slack (notify) / Airtable (log)
```

### Error Handling
```
[Main flow] -> Error Trigger -> Slack (alert) + Postgres (log error)
```

## Expression Syntax
```
{{ $json.email }}                    // Current node data
{{ $('Node Name').item.json.id }}   // Data from specific node
{{ $now.toISO() }}                  // Current timestamp
{{ $input.all() }}                  // All input items
{{ $json.items.length }}            // Array length
```

## Code Node (JavaScript)
```javascript
// Transform items
const items = $input.all();
return items.map(item => ({
  json: {
    name: item.json.name.toUpperCase(),
    processed: true,
    timestamp: new Date().toISOString(),
  }
}));
```

## Code Node (Python)
```python
# Note: limited library access in n8n Python
items = _input.all()
return [{"json": {"name": item.json["name"].upper()}} for item in items]
```

## Key Nodes Reference

| Node | Use Case |
|------|----------|
| Webhook | Receive external HTTP requests |
| Schedule Trigger | Run on cron schedule |
| HTTP Request | Call any REST API |
| Code | Custom JavaScript/Python logic |
| IF | Conditional branching |
| Switch | Multi-path routing |
| Merge | Combine data from branches |
| Loop Over Items | Process items one at a time |
| Set | Add/modify fields |
| Postgres/MySQL | Database operations |
| Slack/Email | Notifications |

## Best Practices
1. Always add error handling nodes
2. Use the Set node to clean data between API calls
3. Add a Respond to Webhook node if the caller needs a response
4. Use sub-workflows for reusable logic
5. Test with manual execution before activating
6. Pin test data on nodes during development
