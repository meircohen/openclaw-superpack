---
name: think-before-act
description: Mandatory structured thinking at critical decision points before taking action
read_when: "before git operations, before transitioning from reading to editing code, before claiming work is done, when stuck or facing unexpected failures"
---

# Think Before Act

Adapted from Devin AI's mandatory think-tool protocol. Forces structured reasoning at high-stakes moments instead of rushing to action.

## When You MUST Think

Use an explicit reasoning block (internal or written) in these mandatory situations:

1. **Before git/GitHub decisions** -- choosing which branch to base off, whether to create a new PR or update existing, any non-trivial git operation you must get right.
2. **Before transitioning from reading to editing** -- pause and ask: Have I gathered all necessary context? Found all locations to edit? Inspected references, types, and relevant definitions?
3. **Before reporting completion** -- critically examine your work. Did you fulfill the full request and intent? Did you run all expected verification steps (lint, test, build)? For multi-location edits, did you hit every site?
4. **When there is no clear next step** -- do not pick a random action. Reason through options.
5. **When facing unexpected failures** -- step back and think big picture about what you have done so far and where the issue really stems from, rather than diving into code changes.
6. **After test/lint/CI failure** -- think about root cause before touching code. The failure may not be where you think.
7. **When viewing screenshots or visual output** -- spend extra time interpreting what you actually see in context of the task.
8. **When a search returns no results** -- think about alternative search terms, file patterns, or naming conventions before concluding something does not exist.

## Think Block Structure

When thinking, follow this structure:

1. **Observations** -- What do I know so far? What have I tried?
2. **Alignment check** -- Does this align with the user's objective and intent?
3. **Options** -- What are the possible next steps? What are the tradeoffs?
4. **Decision** -- Which option do I choose and why?
5. **Risks** -- What could go wrong? What am I assuming?

## Rules

- You may think without taking any other action. Thinking by itself is a valid turn.
- Never skip the pre-completion think. It catches the most mistakes.
- If you have tried multiple approaches and nothing works, your think block should synthesize all attempts before trying again.
- Thinking is free. Action mistakes are expensive. Bias toward thinking more, not less.
