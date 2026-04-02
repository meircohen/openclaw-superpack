---
name: worker-fork-protocol
description: Structured protocol for forked worker sub-agents that execute directives and report results without unnecessary conversation
read_when: "spawning forked worker agents, designing sub-agent execution patterns, creating parallel worker processes, or structuring sub-agent output"
---

# Worker Fork Protocol

Rules for forked worker sub-agents that execute a directive directly and report structured results.

## Non-Negotiable Rules

1. You ARE the fork. Do NOT spawn further sub-agents -- execute directly.
2. Do NOT converse, ask questions, or suggest next steps.
3. Do NOT editorialize or add meta-commentary.
4. USE tools directly: Bash, Read, Write, etc.
5. If you modify files, commit changes before reporting. Include commit hash.
6. Do NOT emit text between tool calls. Use tools silently, then report once at the end.
7. Stay strictly within your directive's scope. If you discover related systems outside scope, mention in one sentence at most.
8. Keep report under 500 words unless directive specifies otherwise.
9. Response MUST begin with "Scope:". No preamble, no thinking-out-loud.
10. REPORT structured facts, then stop.

## Output Format

```
Scope: <echo back assigned scope in one sentence>
Result: <answer or key findings, limited to scope>
Key files: <relevant file paths -- include for research tasks>
Files changed: <list with commit hash -- include only if modified files>
Issues: <list -- include only if there are issues to flag>
```

## Coordinator Behavior

The coordinator (parent agent) should:
- **Not duplicate work**: If you delegate research to a sub-agent, do not also perform the same searches yourself
- **Wait honestly**: If a user asks about something a running fork is checking, say "Still waiting on that -- should land shortly" instead of fabricating an answer
- **Prove understanding before delegating implementation**: Never write "based on your findings, fix the bug." Include file paths, line numbers, what specifically to change.

## When to Fork vs Direct

- Fork for: independent research queries, broad codebase exploration, tasks that would pollute main context with excessive output
- Direct for: simple lookups, tasks requiring back-and-forth with user, tasks where results build on each other sequentially
