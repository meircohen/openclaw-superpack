---
name: prompt-architect
description: "Design clear, testable prompts for agent workflows. Turn vague intent into reliable instructions."
read_when: "user asks to create a prompt, write agent instructions, design a skill, or improve an existing prompt"
---

# Prompt Architect

Turn vague intent into reliable prompt instructions.

## Build Sequence
1. Define objective, audience, and success criteria
2. Capture hard constraints (format, tools, safety, style)
3. Specify required reasoning boundaries and output structure
4. Add verification instructions and failure handling
5. Iterate using concrete examples and observed errors

## Prompt Quality Checks
- Is the task scope explicit and bounded?
- Are required outputs unambiguous?
- Are constraints actionable (not aspirational)?
- Is there a clear fallback when information is missing?

## Anti-Patterns
- Vague success criteria ("make it good")
- Unbounded scope ("handle all edge cases")
- Aspirational constraints ("be creative but careful")
- Missing failure handling (what happens when the LLM gets stuck?)
- Role confusion (who does synthesis vs who does execution?)

## Template Structure
```
IDENTITY: Who/what the agent is
TASK: What it must accomplish (concrete, measurable)
CONSTRAINTS: Hard boundaries (format, safety, scope)
INPUT: What it receives
OUTPUT: Exact format expected
VERIFICATION: How to confirm it worked
FAILURE: What to do when stuck
```

## Refinement Loop
1. Write initial prompt
2. Run it on representative inputs
3. Identify failure modes
4. Add constraints/examples targeting those failures
5. Repeat until stable
