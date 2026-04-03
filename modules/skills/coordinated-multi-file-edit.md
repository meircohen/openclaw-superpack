---
name: coordinated-multi-file-edit
description: Safely make the same or related change across many files using regex-driven coordination
read_when: "when refactoring across multiple files, when renaming symbols, when updating patterns across a codebase, when making bulk changes"
---

# Coordinated Multi-File Edit

Adapted from Devin AI's find_and_edit pattern and Cursor's code style discipline. Provides a protocol for making related changes across many files without missing locations or introducing inconsistencies.

## When to Use

- Renaming a function, class, or variable across the codebase
- Updating an API pattern (e.g., changing auth middleware)
- Migrating from one library to another
- Applying a code convention change across files
- Any change that touches 3+ files with a similar pattern

## Protocol

### 1. Discovery Phase

Before editing anything:

- Search for ALL locations that need to change using multiple search strategies.
- Use both exact string matching and regex patterns.
- Check imports, type definitions, test files, documentation, and config files.
- Use go-to-references / find-all-references when available.
- Think: "What references will break if I make this change?"

### 2. Catalog All Locations

Create an explicit list of every file and line that needs to change:

```
Files to edit:
- src/auth/middleware.ts (lines 12, 45) -- definition
- src/routes/users.ts (line 8) -- import, (line 23) -- usage
- tests/auth.test.ts (lines 5, 18, 32) -- test references
- docs/api.md (line 44) -- documentation reference
```

### 3. Define the Change Pattern

Write a clear, concise description of the change:
- What the old pattern looks like
- What the new pattern should look like
- Any conditions where the change should NOT be applied

### 4. Execute Changes

- Make changes in dependency order: definitions first, then usages, then tests, then docs.
- For identical changes across files, batch them when possible.
- After all edits, verify by searching for both the OLD pattern (should be gone) and NEW pattern (should be present).

### 5. Verify Completeness

- Search for the old pattern one more time -- any remaining hits are missed locations.
- Run linter/type checker to catch broken references.
- Run tests to catch behavioral regressions.

## Code Style Rules During Edits

From Cursor's code_style protocol:

- Match existing code style and formatting in each file.
- Use meaningful variable names (no single-character names).
- Use guard clauses and early returns.
- Never catch errors without meaningful handling.
- Do not reformat unrelated code.
- Do not add comments that simply restate what the code does.

## Anti-Patterns

- Editing the first few files you find and assuming you are done.
- Not checking test files and documentation.
- Making the change inconsistently across files (different naming in different places).
- Reformatting unrelated code while making the targeted change.
