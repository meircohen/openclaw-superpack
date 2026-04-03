---
name: code-minimalism
description: Anti-bloat coding rules -- no unnecessary additions, no premature abstractions, no compatibility hacks, no defensive over-engineering
read_when: "writing code, implementing features, fixing bugs, refactoring, or reviewing code for unnecessary complexity"
---

# Code Minimalism

Rules for writing code that solves the actual problem without adding speculative complexity.

## No Unnecessary Additions

Do not add features, refactor code, or make "improvements" beyond what was asked.
- A bug fix does not need surrounding code cleaned up
- A simple feature does not need extra configurability
- Do not add docstrings, comments, or type annotations to code you didn't change
- Only add comments where the logic isn't self-evident

## No Premature Abstractions

Do not create helpers, utilities, or abstractions for one-time operations. Do not design for hypothetical future requirements.
- The right amount of complexity is what the task actually requires
- Three similar lines of code is better than a premature abstraction
- No speculative abstractions, but no half-finished implementations either

## No Compatibility Hacks

Avoid backwards-compatibility noise:
- No renaming unused `_vars`
- No re-exporting types for compatibility
- No `// removed` comments for removed code
- If something is unused, delete it completely

## No Unnecessary Error Handling

Do not add error handling, fallbacks, or validation for scenarios that can't happen.
- Trust internal code and framework guarantees
- Only validate at system boundaries (user input, external APIs)
- Do not use feature flags or backwards-compatibility shims when you can just change the code

## Security (the exception)

DO be careful about security -- avoid command injection, XSS, SQL injection, and OWASP top 10. If you notice insecure code, fix it immediately. This is the one place where "extra" protection is always warranted.

## Read Before Modifying

Do not propose changes to code you haven't read. If asked about or asked to modify a file, read it first. Understand existing code before suggesting modifications.

## Ambitious Tasks Are Fine

Do not refuse tasks for being "too complex." Defer to user judgment about scope. You are capable of completing ambitious work.

## The Test

For every line you're about to write, ask: "Did the user ask for this?" If no, don't write it.
