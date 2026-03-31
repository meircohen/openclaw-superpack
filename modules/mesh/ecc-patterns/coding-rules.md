# ECC Coding Rules Reference

Consolidated from ECC common and Python rule sets.
Actionable rules for our Python-heavy setup.

---

## Coding Style

### Immutability (CRITICAL)

ALWAYS create new objects, NEVER mutate existing ones.
- Immutable data prevents hidden side effects, makes debugging easier, enables safe concurrency.
- Python: use `@dataclass(frozen=True)` and `NamedTuple` for immutable structures.

### File Organization

MANY SMALL FILES > FEW LARGE FILES:
- 200-400 lines typical, 800 max
- High cohesion, low coupling
- Organize by feature/domain, not by type
- Extract utilities from large modules

### Error Handling

- Handle errors explicitly at every level
- Never silently swallow errors
- User-friendly messages in UI-facing code, detailed context server-side
- Python: catch specific exceptions, never bare `except: pass`. Use context managers (`with`).

### Input Validation

- Validate all user input before processing
- Use schema-based validation (Pydantic, marshmallow, etc.)
- Fail fast with clear error messages
- Never trust external data

### Code Quality Checklist

- [ ] Code is readable and well-named
- [ ] Functions are small (<50 lines, <5 parameters)
- [ ] Files are focused (<800 lines)
- [ ] No deep nesting (>4 levels -- use early returns)
- [ ] Proper error handling
- [ ] No hardcoded values (use constants or config)
- [ ] No mutation (immutable patterns used)

---

## Python-Specific Style

### Standards
- Follow PEP 8
- Type annotations on ALL function signatures
- Use `black` for formatting, `isort` for imports, `ruff` for linting

### Immutable Patterns

```python
from dataclasses import dataclass

@dataclass(frozen=True)
class User:
    name: str
    email: str

from typing import NamedTuple

class Point(NamedTuple):
    x: float
    y: float
```

### Pythonic Patterns
- List comprehensions over C-style loops
- `isinstance()` not `type() ==`
- `Enum` not magic numbers
- `"".join()` not string concatenation in loops
- `def f(x=None)` not `def f(x=[])` (no mutable default args)
- `value is None` not `value == None`
- Never shadow builtins (`list`, `dict`, `str`)
- `print()` is for debugging only -- use `logging` in production

### Protocol Pattern (Duck Typing)

```python
from typing import Protocol

class Repository(Protocol):
    def find_by_id(self, id: str) -> dict | None: ...
    def save(self, entity: dict) -> dict: ...
```

### Dataclasses as DTOs

```python
@dataclass
class CreateUserRequest:
    name: str
    email: str
    age: int | None = None
```

### Context Managers and Generators
- Use `with` for all resource management (files, connections, locks)
- Use generators for lazy evaluation and memory-efficient iteration

---

## Testing

### Minimum Coverage: 80%

Three test types, ALL required:
1. **Unit** -- individual functions, utilities
2. **Integration** -- API endpoints, database operations
3. **E2E** -- critical user flows

### TDD Workflow (MANDATORY)

1. Write test first (RED)
2. Run test -- it should FAIL
3. Write minimal implementation (GREEN)
4. Run test -- it should PASS
5. Refactor (IMPROVE)
6. Verify coverage (80%+)

### Python Testing

- Framework: **pytest**
- Coverage: `pytest --cov=src --cov-report=term-missing`
- Categorize with `pytest.mark`: `@pytest.mark.unit`, `@pytest.mark.integration`
- Diagnostic: `mypy .`, `ruff check .`, `black --check .`, `bandit -r .`

### Edge Cases You MUST Test

1. Null/None input
2. Empty collections/strings
3. Invalid types
4. Boundary values (min/max)
5. Error paths (network failures, DB errors)
6. Race conditions
7. Large data (10k+ items)
8. Special characters (Unicode, SQL chars)

### Anti-Patterns to Avoid

- Testing implementation details instead of behavior
- Tests depending on each other (shared state)
- Weak assertions that pass without verifying anything
- Not mocking external dependencies

---

## Security

### Mandatory Checks Before ANY Commit

- [ ] No hardcoded secrets (API keys, passwords, tokens)
- [ ] All user inputs validated
- [ ] SQL injection prevention (parameterized queries)
- [ ] XSS prevention (sanitized output)
- [ ] CSRF protection enabled
- [ ] Authentication/authorization verified
- [ ] Rate limiting on all endpoints
- [ ] Error messages don't leak sensitive data

### Secret Management

- NEVER hardcode secrets in source code
- Use environment variables or a secret manager
- Validate required secrets at startup
- Rotate any secrets that may have been exposed

```python
import os
from dotenv import load_dotenv

load_dotenv()
api_key = os.environ["OPENAI_API_KEY"]  # Raises KeyError if missing
```

### Python Security Scanning

```bash
bandit -r src/   # Static security analysis
```

### Python-Specific Security Risks (CRITICAL)

| Pattern | Fix |
|---------|-----|
| f-strings in SQL queries | Parameterized queries |
| Unvalidated input in shell commands | subprocess with list args |
| User-controlled file paths | normpath + reject `..` |
| `eval()` / `exec()` with user input | Never |
| `yaml.load()` without SafeLoader | `yaml.safe_load()` |
| `pickle.loads()` on untrusted data | Use JSON instead |
| Hardcoded secrets | `os.environ[]` |
| MD5/SHA1 for security purposes | Use bcrypt/argon2 for passwords |

### Security Response Protocol

1. STOP immediately
2. Use security-reviewer agent
3. Fix CRITICAL issues before continuing
4. Rotate any exposed secrets
5. Review entire codebase for similar issues

---

## Performance

### Model Selection Strategy

- **Haiku**: Lightweight/frequent tasks (doc updates, simple generation) -- 3x cost savings
- **Sonnet**: Main development work, orchestration, complex coding
- **Opus**: Complex architectural decisions, deep reasoning, research

### Context Window Management

Avoid last 20% of context window for large-scale refactoring or multi-file work.
Lower sensitivity: single-file edits, utilities, docs, simple bug fixes.

### Build Troubleshooting

1. Use build-error-resolver agent
2. Analyze error messages
3. Fix incrementally
4. Verify after each fix

---

## Git Workflow

### Commit Message Format

```
<type>: <description>

<optional body>
```

Types: `feat`, `fix`, `refactor`, `docs`, `test`, `chore`, `perf`, `ci`

### PR Workflow

1. Analyze full commit history (not just latest)
2. `git diff [base-branch]...HEAD` to see all changes
3. Comprehensive PR summary
4. Include test plan
5. Push with `-u` flag for new branches

---

## Development Workflow

### Feature Implementation Pipeline

0. **Research and Reuse** (mandatory before any new implementation)
   - GitHub code search first (`gh search repos`, `gh search code`)
   - Library docs second (Context7 or vendor docs)
   - Check package registries (PyPI, npm, etc.) before writing utility code
   - Prefer adopting proven approaches over net-new code

1. **Plan First** -- planner agent, generate planning docs, identify risks
2. **TDD Approach** -- tdd-guide agent, RED-GREEN-REFACTOR, 80%+ coverage
3. **Code Review** -- code-reviewer agent immediately after writing code
4. **Commit and Push** -- conventional commits format
5. **Pre-Review Checks** -- CI passing, conflicts resolved, branch up to date

---

## Code Review Standards

### When to Review (MANDATORY)

- After writing or modifying code
- Before commits to shared branches
- Security-sensitive code (auth, payments, user data)
- Architectural changes
- Before merging PRs

### Severity Levels

| Level | Action |
|-------|--------|
| CRITICAL | BLOCK -- must fix before merge |
| HIGH | WARN -- should fix before merge |
| MEDIUM | INFO -- consider fixing |
| LOW | NOTE -- optional |

### Approval Criteria

- **Approve**: No CRITICAL or HIGH issues
- **Warning**: HIGH issues only (merge with caution)
- **Block**: CRITICAL issues found

---

## Agent Orchestration

### Parallel Execution

ALWAYS use parallel task execution for independent operations:
- Launch multiple agents simultaneously for security analysis, performance review, type checking
- Never run sequentially when tasks are independent

### Multi-Perspective Analysis

For complex problems, use split-role sub-agents:
- Factual reviewer, senior engineer, security expert, consistency reviewer, redundancy checker

---

## Hooks

### Hook Types
- **PreToolUse**: Before tool execution (validation, parameter modification)
- **PostToolUse**: After tool execution (auto-format, checks)
- **Stop**: When session ends (final verification)

### Python Hooks
- Auto-format with black/ruff after editing .py files
- Run mypy/pyright type checking after editing .py files
- Warn about print() statements (use logging instead)

### Auto-Accept Permissions
- Enable for trusted, well-defined plans
- Disable for exploratory work
- Never use dangerously-skip-permissions
- Configure `allowedTools` in settings instead

---

## Common Patterns

### Skeleton Projects
1. Search for battle-tested skeleton projects before building from scratch
2. Evaluate with parallel agents (security, extensibility, relevance, planning)
3. Clone best match, iterate within proven structure

### Repository Pattern
- Standard interface: findAll, findById, create, update, delete
- Business logic depends on abstract interface, not storage mechanism
- Enables easy swapping and testing with mocks

### API Response Format
- Consistent envelope: success indicator, data payload, error message, pagination metadata
