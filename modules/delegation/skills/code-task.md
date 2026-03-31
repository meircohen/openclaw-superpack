# Skill: Code Task

You are implementing a coding task. Follow the bug-fix protocol: understand, reproduce, test, fix, verify.

## Inputs
Brief includes: `repo`, `scope`, `tests`, `agent`, `branch`, `pr`, `timeout`, `context_files`.

## Steps

### 1. Understand the scope
Read the `scope` field carefully. If `context_files` are provided, read those too. Understand:
- What needs to change?
- What's the expected behavior?
- What are the boundaries? (don't touch anything outside scope)

### 2. Set up the workspace
```bash
cd {repo}
git status
# If branch specified:
git checkout -b {branch} 2>/dev/null || git checkout {branch}
```

### 3. Write a failing test FIRST
**This is mandatory if `tests: true` (the default).**
- Write a test that demonstrates the expected behavior
- Run it -- it should FAIL (proving the bug/missing feature exists)
- If you can't write a test, document why and proceed carefully

```bash
# Run the test command from the brief, or infer:
npm test  # or pytest, or go test, etc.
```

### 4. Implement the fix/feature
- Make the minimal change that makes the test pass
- Don't refactor unrelated code
- Don't add features not in scope
- If you need to modify more than 3 files, pause and verify you're not scope-creeping

### 5. Run tests
```bash
{test_command}
```
ALL tests must pass -- both your new test and all existing tests.

### 6. Verify the change
- Read your diff: `git diff`
- Does every change serve the scope?
- Any leftover debug code? Console.logs? TODO comments?
- Does the code follow the repo's existing style?

### 7. Commit
```bash
git add -A
git commit -m "descriptive commit message"
```

### 8. Open PR (if requested)
```bash
gh pr create --title "Brief description" --body "What changed and why"
```

### Agent Selection (if `agent: auto`)
- Simple fix (1-2 files, clear scope): Use yourself (no sub-agent needed)
- Medium complexity (3-5 files, tests needed): Codex
  ```bash
  codex --model o4-mini --approval-mode auto-edit "scope description"
  ```
- High complexity (architecture, many files): Claude Code
  ```bash
  claude --print --permission-mode bypassPermissions "scope description"
  ```

## Common Pitfalls
- **Verify dependencies first.** `which node`, `which python`, check package.json exists.
- **Don't skip the test.** "It's a simple change" is how regressions happen.
- **No scope creep.** If you notice other issues, log them -- don't fix them.
- **Config > 1 file for a simple concept = over-engineering.**
- **Check for existing tests** before writing new ones. Don't duplicate.

## Success = All of these are true:
- [ ] Failing test written BEFORE the fix (if tests enabled)
- [ ] All tests pass (new + existing)
- [ ] `git diff` shows only in-scope changes
- [ ] No debug code left behind
- [ ] Committed (and PR opened if requested)
- [ ] Total time within timeout
