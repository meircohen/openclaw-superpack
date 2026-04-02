---
name: subagent-briefing
description: How to write effective sub-agent prompts that produce deep work instead of shallow generic output
read_when: "writing prompts for sub-agents, delegating tasks to agents, spawning Task/Agent tool calls, or designing multi-agent workflows"
---

# Subagent Briefing

Guidelines for writing prompts that produce high-quality sub-agent work.

## Core Principle

Brief the agent like a smart colleague who just walked into the room. It hasn't seen the conversation, doesn't know what you've tried, doesn't understand why this task matters.

## What to Include

- **What** you're trying to accomplish and **why**
- What you've already learned or ruled out
- Enough context about the surrounding problem that the agent can make judgment calls (not just follow narrow instructions)
- If you need a short response, say so ("report in under 200 words")

## Two Delegation Modes

**Lookups**: Hand over the exact command. The agent runs it and returns the result.

**Investigations**: Hand over the question. Prescribed steps become dead weight when the premise is wrong. Let the agent explore.

## Never Delegate Understanding

Do NOT write:
- "based on your findings, fix the bug"
- "based on the research, implement it"
- "figure out what's wrong and fix it"

These push synthesis onto the agent instead of doing it yourself. Write prompts that prove YOU understood: include file paths, line numbers, what specifically to change.

## Terse Prompts = Shallow Work

Command-style prompts produce shallow, generic results. The more context you provide, the better the agent's judgment calls.

## Examples

**Good -- investigation with context:**
```
Audit what's left before this branch can ship. Check: uncommitted changes,
commits ahead of main, whether tests exist, whether the GrowthBook gate is
wired up, whether CI-relevant files changed. Report a punch list -- done vs.
missing. Under 200 words.
```

**Good -- independent review with full briefing:**
```
Review migration 0042_user_schema.sql for safety. Context: we're adding a
NOT NULL column to a 50M-row table. Existing rows get a backfill default.
I want a second opinion on whether the backfill approach is safe under
concurrent writes -- I've checked locking behavior but want independent
verification. Report: is this safe, and if not, what specifically breaks?
```

**Bad -- delegating understanding:**
```
Look at the code and fix whatever is wrong.
```

## Anti-Patterns

- Duplicating work the sub-agent is doing (don't search yourself if you delegated search)
- Fabricating results while waiting for a sub-agent to return
- Spawning sub-agents for trivial tasks that a single tool call would handle
- Chaining sub-agents when sequential reasoning is needed (synthesis belongs with you)
