# Verification: Code Task

Run these checks BEFORE reporting completion.

## Checks

### 1. Tests pass
```bash
cd {repo}
{test_command}
```
- [ ] Exit code is 0
- [ ] All tests pass (new AND existing)
- [ ] If `tests: true` -- at least one NEW test was written
- [ ] New test FAILS without the fix (revert and check, or confirm from git history)

### 2. Scope discipline
```bash
git diff --stat
```
- [ ] Only files within scope were modified
- [ ] No unrelated refactoring
- [ ] No new dependencies added without justification
- [ ] If > 3 files changed, each change is justified by the scope

### 3. Code quality
```bash
git diff
```
- [ ] No debug code (console.log, print(), debugger, TODO)
- [ ] No commented-out code
- [ ] Follows existing code style (indentation, naming, patterns)
- [ ] No hardcoded secrets, paths, or credentials

### 4. Git state
```bash
git status
git log --oneline -3
```
- [ ] All changes committed
- [ ] Commit message is descriptive (not "fix" or "update")
- [ ] On the correct branch (if specified)
- [ ] If `pr: true` -- PR exists and is viewable

### 5. PR (if requested)
```bash
gh pr view --json title,body,url
```
- [ ] PR title describes the change
- [ ] PR body explains what and why
- [ ] CI checks are passing (or at least running)

## If Any Check Fails
Report which check failed, include the output, and what you tried. Do NOT claim the task is complete.
