---
name: linear-pm
description: Manage Linear issues, projects, and team workflows via CLI
read_when: "user wants to create, update, or manage Linear issues, projects, cycles, or team workflows"
---

# Linear Project Management

Manage Linear issues, projects, and teams using the `linear` CLI or GraphQL API.

## Setup

```bash
# Install Linear CLI
npm install -g @linear/cli
# Or use the API directly with curl
export LINEAR_API_KEY="lin_api_..."
```

## Common Operations

### Create an issue
```bash
linear issue create --title "Fix login timeout" --team "ENG" --priority "urgent" --label "bug"
```

### List and search issues
```bash
linear issue list --team "ENG" --state "In Progress"
linear issue list --assignee "me" --state "Todo"
```

### Update an issue
```bash
linear issue update <ISSUE_ID> --state "In Progress" --assignee "me"
linear issue update <ISSUE_ID> --priority "high" --label "frontend"
```

### GraphQL API (when CLI is insufficient)
```bash
curl -X POST https://api.linear.app/graphql \
  -H "Authorization: $LINEAR_API_KEY" \
  -H "Content-Type: application/json" \
  -d '{
    "query": "{ issues(filter: { state: { name: { eq: \"In Progress\" } } }) { nodes { id title assignee { name } priority } } }"
  }'
```

### Create from PR context
When working on a PR, create tracking issues:
1. Parse the PR description for requirements
2. Create sub-issues for each deliverable
3. Link back to the PR in issue comments

## Workflow Integration

- **Before coding**: Check assigned issues, pick from backlog
- **During development**: Move issue to "In Progress", add branch reference
- **After PR merge**: Move issue to "Done", link PR
- **Bug reports**: Create with reproduction steps, severity, and affected area

## Priority Mapping
- **Urgent (1)**: Production down, data loss
- **High (2)**: Major feature broken, blocking others
- **Medium (3)**: Default for planned work
- **Low (4)**: Nice-to-have, polish items
