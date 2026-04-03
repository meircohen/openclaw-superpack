---
name: todo-driven-execution
description: Use a living todo checklist to track multi-step task progress with strict update discipline
read_when: "when executing multi-step tasks, when implementing features with 3+ steps, when you need to track progress across a complex workflow"
---

# Todo-Driven Execution

Adapted from Manus AI's todo.md protocol and Cursor's todo_write discipline. Uses a living checklist as the single source of truth for task progress.

## When to Use

- Any task with 3+ distinct steps
- Feature implementation spanning multiple files
- Research tasks requiring information from multiple sources
- Any work where losing track of progress is a risk

## Creating the Todo

1. Create a `todo.md` file (or use an internal tracking mechanism) based on your task plan.
2. Each item should be atomic, verb-led, and under 14 words.
3. Use checkbox format: `- [ ]` incomplete, `- [x]` complete.
4. Group related items under higher-level headings only when needed.
5. Prefer fewer, larger items over many tiny ones. Each should represent meaningful progress.

## Update Discipline

These rules are non-negotiable:

- **Before starting any edit**: Mark the current task as in-progress.
- **After completing each step**: Immediately mark it done before reporting progress.
- **Before reporting to user**: Reconcile the todo -- mark completed items, set next item to in-progress.
- **When skipping a task**: State a one-line justification and mark as cancelled.
- **When the plan changes significantly**: Rebuild the todo to match the new plan.

## Status Updates

When providing progress notes:

- Reference task names, not IDs.
- Never reprint the full list -- just mention what changed.
- Use correct tenses: "I'll" for future, past tense for done, present for in-progress.
- If you say you are about to do something, actually do it in the same turn.

## Completion Protocol

When all tasks are done:

1. Verify every item is checked off.
2. Remove any skipped items with justification.
3. Provide a brief summary of what was accomplished.

## Anti-Patterns

- Do NOT create todos for trivial single-step tasks.
- Do NOT include operational meta-tasks like "read the file" or "search codebase" -- only meaningful deliverable steps.
- Do NOT claim work is done without checking off the corresponding todo item first.
