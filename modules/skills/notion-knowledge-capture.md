---
name: notion-knowledge-capture
description: Transform conversations and findings into structured Notion pages
read_when: "user wants to save information to Notion, document findings in Notion, or capture knowledge in a wiki"
---

# Notion Knowledge Capture

Transform conversations, research, and findings into structured Notion documentation.

## Prerequisites
- Notion MCP server connected (check with `mcp__claude_ai_Notion__notion-search`)
- Or Notion API key: `export NOTION_API_KEY="ntn_..."`

## Capture Workflow

### 1. Determine the Right Location
```
Search existing pages first:
- Use notion-search to find related pages
- Check if a parent page/database already exists for this topic
- Don't create duplicates
```

### 2. Structure the Content

Use this template for knowledge pages:

```markdown
# [Topic Title]

## Summary
[2-3 sentence overview of what this captures]

## Key Findings
- Finding 1 with context
- Finding 2 with context

## Details
[Expanded information organized by subtopic]

## Action Items
- [ ] Next step 1
- [ ] Next step 2

## Sources / References
- Where this information came from
- Links to related pages

## Metadata
- Captured: [date]
- Context: [what prompted this capture]
- Status: Draft / Reviewed / Final
```

### 3. Create the Page

Using MCP tools:
```
1. notion-search: Find the target parent page/database
2. notion-create-pages: Create the new page with structured content
3. notion-create-comment: Add context about why this was captured
```

Using API directly:
```bash
curl -X POST 'https://api.notion.com/v1/pages' \
  -H "Authorization: Bearer $NOTION_API_KEY" \
  -H "Notion-Version: 2022-06-28" \
  -H "Content-Type: application/json" \
  -d '{ "parent": { "page_id": "..." }, "properties": { "title": [{"text": {"content": "Page Title"}}] }, "children": [...] }'
```

### 4. Link and Organize
- Add bidirectional links to related pages
- Tag with relevant properties if in a database
- Update any index/overview pages

## When to Capture
- Decisions made during development
- Architecture rationale (ADRs)
- Research findings from investigations
- Runbooks for operational procedures
- Meeting outcomes and action items
- Bug post-mortems and root cause analyses
