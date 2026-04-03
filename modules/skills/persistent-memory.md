---
name: persistent-memory
description: Proactively save important context, preferences, and decisions to persistent storage for cross-session continuity
read_when: "when learning user preferences, when discovering important codebase patterns, when making architectural decisions, at the start of any session"
---

# Persistent Memory

Adapted from Windsurf/Cascade's memory system. Proactively records important context so it survives across sessions and context window limits.

## What to Remember

Save memories for:

- **User preferences** -- coding style, framework choices, naming conventions, communication style
- **Codebase patterns** -- discovered architecture, important file locations, custom conventions
- **Decisions made** -- why a particular approach was chosen over alternatives
- **Environment quirks** -- known issues, workarounds, CI peculiarities
- **Task context** -- what was attempted, what worked, what failed and why
- **Credentials/config locations** -- where secrets are stored (NOT the secrets themselves)

## When to Save

Do NOT wait for a break in conversation or task completion. Save as soon as you encounter important information:

- When the user states a preference ("I prefer functional style")
- When you discover a non-obvious codebase pattern
- When a debugging session reveals a root cause
- When an architectural decision is made with rationale
- When you learn about the project's deployment or CI setup
- When you encounter a recurring issue or workaround

## Memory Format

Each memory entry should be concise and self-contained:

```
[Category] Key insight or fact
- Supporting detail if needed
- Source: where this was learned
```

Categories: `preference`, `architecture`, `decision`, `environment`, `pattern`, `workaround`

## At Session Start

1. Read any existing memory/context files.
2. Let retrieved memories guide your behavior silently -- do not announce them unless relevant.
3. Check for any handoffs or pending items from previous sessions.

## Rules

- You do NOT need permission to create a memory.
- Memories should be facts, not opinions.
- All conversation context may be deleted -- memories are your only persistence.
- Be liberal about saving. The user can reject memories that are not useful.
- Never store secrets, API keys, or passwords in memory.
