# Cursor Rules Audit - Battle-Tested AI Coding Patterns

**Sources:**
- [zackiles/cursor-config](https://github.com/zackiles/cursor-config) - Comprehensive cursor config with global prompts, JS/TS standards, testing, finalization workflows
- [PatrickJS/awesome-cursorrules](https://github.com/PatrickJS/awesome-cursorrules) - Community collection of 100+ cursor rules files

**Purpose:** Extract universal AI coding rules applicable to Claude Code, Codex, and Gemini bootstrap configs.

---

## 1. AI Behavior Meta-Rules

These govern how the AI assistant should behave during coding sessions. Universally applicable across all AI coding tools.

### Communication Discipline
- **No apologies** -- fix errors, don't apologize for them
- **No summaries** -- don't summarize changes at the end of responses (the user can read the diff)
- **No filler** -- don't restate what the user said, don't add "understanding feedback"
- **No inventions** -- don't make changes beyond what was explicitly requested
- **No unnecessary confirmations** -- don't ask to confirm info already in context
- **Verify before asserting** -- never speculate or assume without evidence

### Scope Discipline
- **Minimal code changes** -- only modify sections related to the task at hand
- **Preserve existing code** -- don't remove unrelated code or functionalities
- **Don't touch comments** -- avoid changing existing comments unless they're wrong
- **No cleanup unless asked** -- avoid any kind of cleanup unless specifically instructed
- **Every change = potential for bugs** -- treat code changes as a cost, not a feature

### Error Handling Behavior
- If two consecutive errors appear, **expand debugging efforts** (add debug lines, isolate failing tests, write logs)
- If an error persists, do most troubleshooting autonomously before asking the user
- **Never fix a broken test before reading the entire code it's testing**
- **Always assume the test could be incorrect** -- tests may be outdated or misaligned

---

## 2. Code Quality Rules (Universal)

### Naming
- **Explicit over clever** -- descriptive variable/function names that reveal intent
- **No magic numbers** -- replace hardcoded values with named constants
- **Consistent casing per language:** kebab-case (files), camelCase (vars), PascalCase (classes), UPPER_SNAKE_CASE (constants)
- **Don't repeat context** -- if class is `Car`, use `horn` not `carHorn`
- **Evolve names during refactoring** -- rename related things to maintain consistency

### Structure
- **Early returns** -- avoid nested conditionals, return early to flatten logic
- **Single Responsibility** -- each function does one thing
- **2 or fewer arguments** -- if more needed, use an options object
- **Short functions** -- if a function is too long, break it up
- **Keep callers and callees close** -- related code stays together
- **Encapsulate nested conditionals into named functions** -- clarify purpose

### Comments
- **Comments explain WHY, not WHAT** -- code should be self-documenting
- **Comments are an apology for difficult code** -- not a requirement
- **Remove comments that describe obvious behavior** (`// increment counter`)
- **Preserve comments that explain business logic, security, or non-obvious behavior**
- **When updating code, update related JSDoc/docstrings** -- stale docs are worse than none
- **Remove development artifacts** -- no "temporary", "test", "debug", "TODO" comments in shipped code

### Code Minimalism
- **Less code is better** -- always prefer solutions with the fewest lines needed
- **Net-negative code contribution mindset** -- strive to remove more code than you add
- **Don't create single-use abstractions** -- inline types used once, keep functions near their single caller
- **Don't over-engineer** -- avoid robustness for robustness' sake
- **Ruthless deprecation of redundancy** -- hunt down and eliminate duplication
- **Leverage existing libraries** -- exhaust ecosystem options before writing bespoke code
- **Justify every abstraction** -- benefit must demonstrably outweigh indirection cost

---

## 3. Architecture Patterns

### Composition Over Inheritance
- Use composition of concerns instead of separation of concerns
- Group tightly related behavior and state into cohesive units
- Favor composing from minimal reusable blocks over complex extensible hierarchies

### Module Organization
- **ESM-only** -- avoid CommonJS
- **Prevent circular dependencies** -- clear module boundaries
- **Exports at the bottom** -- separate from declarations, as logic-free as possible
- **Code ordering:** remote imports > local imports > hoisted variables > methods > exports

### SOLID Principles
- **Open/Closed** -- open for extension, closed for modification
- **Liskov Substitution** -- subtypes must be substitutable for their base types
- **Interface Segregation** -- don't force clients to depend on interfaces they don't use

---

## 4. Language-Specific Rules

### TypeScript/JavaScript
- Favor modern ECMAScript: destructuring, optional chaining (`?.`), nullish coalescing (`??`), arrow functions, template literals, spread/rest
- **Use TypeScript types at boundaries** -- exported interfaces, shared types across files, third-party type imports
- **Skip TypeScript types for:** single-use internal types, obvious types, overly complex types that don't add safety
- Prefer `const` over `let`; use arrow functions for lexical scoping
- Prefer functional/immutable style -- use `map`, `reduce`, `Object.freeze()`, `structuredClone()`
- Flat promise chains over nested try/catch; use `Promise.allSettled` for concurrent error handling
- Follow existing semicolon style; default to no semicolons for new codebases

### Python
- **PEP 8 + PEP 257** -- Ruff as linter/formatter
- **Comprehensive type annotations** on all functions, methods, class members
- **Google-style docstrings** on all functions, methods, classes
- **Explicit over implicit** -- favor clear intent over clever brevity
- **Async/await for I/O** -- use `asyncio` or `concurrent.futures` for concurrency
- **functools.lru_cache / @cache** for caching where appropriate
- **pytest only** -- no unittest; typing annotations on tests

### Go
- Standard library `net/http` for APIs
- Custom error types when beneficial
- Proper status codes + JSON response formatting
- Input validation on all API endpoints
- Built-in concurrency features (goroutines, channels) for performance
- Middleware for cross-cutting concerns
- Rate limiting and auth when appropriate

---

## 5. Security Rules

- **Security-first approach** -- always consider security implications when modifying code
- **Validate at system boundaries** -- user input, external APIs, file uploads
- **Use `crypto.subtle`** for cryptographic operations (avoid third-party crypto libs)
- **Structured logging** -- JSON-based, with stack traces in dev, minimal in production
- **Don't teach bad habits** -- never show API keys in code examples, even in docs
- **Input validation on all API endpoints**
- **Rate limiting and auth** when building APIs
- **OWASP Top 10 awareness** -- guard against injection, XSS, CSRF, etc.

---

## 6. Testing Rules

### Strategy
- **Integration tests over unit tests** for backend logic (system-wide reliability)
- **Light and practical tests** -- prefer single smoke/integration tests that cover multiple parts
- **Avoid large test files** -- stay under 500 lines; 3-5 focused tests per file
- **Don't test edge cases** unless fixing a specific bug (then add regression test)
- **Avoid complicated mocking** -- simple mocks only

### Structure
- **Arrange-Act-Assert** pattern for all tests
- **Naming:** `{filename}.test.{ext}` -- placed near the code they test
- **Shared utilities** extracted to `test-utilities.{ext}`
- **Descriptive test names** -- indicate expected behavior
- **Group related tests** in describe/context blocks

### E2E Tests
- **Use `data-testid` selectors** -- never CSS/XPath selectors
- **Auto-waiting** over explicit/hardcoded waits
- **Mock external dependencies** for deterministic tests
- **Base tests on user stories** or common flows
- **Validate both success and error scenarios**

### Test Data
- Test valid inputs, invalid inputs, and edge cases
- Include null, undefined, empty arrays, unexpected types
- Use meaningful test data, not random strings

---

## 7. Pre-Implementation Research Protocol

Before writing any code, the AI should:

1. **Search for shared libraries, utilities, and patterns** -- identify what can be reused
2. **Find schemas, models, types, constants, configs** -- understand the data layer
3. **Locate coding standards** -- naming, structure, formatting conventions
4. **Identify existing tooling and scripts** -- automated processes already in place
5. **Review CI/CD pipelines** -- ensure contributions align with build/test/release
6. **Check versioning and release practices** -- how changes are documented and tagged
7. **Assess design patterns and style** -- imitate prevailing style unless severely flawed

---

## 8. Finalization / Code Review Protocol

After completing changes:

1. **Line-by-line review of all changes** -- remove redundant comments, preserve WHY comments
2. **Run all available linting/checking tools** -- resolve errors and warnings (give up after 2 attempts on simple issues)
3. **Review all changes for introduced bugs** -- check dependent code paths
4. **Search modified files for linting errors** -- including pre-existing ones
5. **Remove dead code** related to the change -- notify user of unrelated dead code
6. **Update documentation** made outdated by changes
7. **Investigate before removing "unused" variables** -- they may be unused because of a bug you introduced

---

## 9. Recovery Protocol (When AI Gets Stuck)

When repeated failures cascade into new issues:

1. **Serialize debug state** -- list checkpoints in reverse-chronological order with errors, files changed, and change summaries
2. **Attempt state restoration** -- try to recreate the working state before issues began
3. **If restoration fails** -- output the full debug log, summary of failures, and original prompt that caused the cascade

This is a useful pattern for any AI coding tool -- structured escalation when the AI is making things worse.

---

## 10. Style Consistency Rules

When working in an existing codebase:

1. **Match existing style** -- don't refactor beyond scope
2. **Match comment style** -- frequency, tone, format
3. **Follow dominant paradigm** -- functional, OOP, whatever the codebase uses
4. **Prefer existing libraries** -- don't introduce new ones
5. **Mirror module organization** -- structure new code like existing similar code
6. **Match documentation tone** -- detail level and format
7. **Follow established test patterns** -- for new test code
8. **When styles are inconsistent, ask** -- don't assume

---

## 11. Git / Commit Rules

```
<type>(<scope>): <description>

Types: feat, fix, docs, style, refactor, perf, test, chore, ci, build
Scope: domain/module-level identifiers, not file names
Description: imperative mood, one sentence

BREAKING CHANGE footer for breaking API changes
```

---

## Recommendations for Bootstrap Files

### Rules to ADD to Claude Code / Codex / Gemini configs:

**High Priority (universal, high-impact):**
1. Scope discipline block -- minimal changes, preserve existing code, no cleanup unless asked
2. Comment hygiene -- WHY not WHAT, remove redundant comments on finalization
3. Code minimalism mindset -- less code is better, justify every abstraction
4. Pre-implementation research protocol -- understand before changing
5. Finalization checklist -- line-by-line review, dead code removal, doc updates
6. Recovery protocol -- structured escalation when cascading failures occur
7. Testing strategy -- integration over unit, 3-5 tests per file, Arrange-Act-Assert

**Medium Priority (language-specific, good defaults):**
8. TypeScript types at boundaries only -- skip single-use internal types
9. Early returns over nested conditionals
10. Flat error handling -- no nested try/catch, use Promise.allSettled
11. E2E testing with data-testid selectors and auto-waiting
12. Structured JSON logging with appropriate verbosity per environment

**Already covered in our configs (skip or merge):**
- TDD iron law (we have this)
- Systematic debugging (we have this)
- Conventional commits (we have this)
- Security-first approach (we have this but could strengthen)
