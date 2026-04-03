---
name: gh-fix-ci
description: Debug and fix failing GitHub Actions CI checks by inspecting logs
read_when: "user has failing CI, broken GitHub Actions, red checks on a PR, or needs to debug a workflow"
---

# Fix Failing CI

Systematic approach to debug and fix failing GitHub Actions checks on PRs.

## Step 1: Identify the Failure

```bash
# List recent failed runs
gh run list --status failure --limit 5

# View a specific run
gh run view <RUN_ID>

# View failed jobs in a run
gh run view <RUN_ID> --log-failed
```

## Step 2: Get the Logs

```bash
# Download full logs
gh run view <RUN_ID> --log-failed > ci-failure.log

# For a specific job
gh run view <RUN_ID> --job <JOB_ID> --log
```

## Step 3: Common Failure Patterns

### Test failures
- Read the test output to find the assertion that failed
- Check if it's a flaky test (re-run once to confirm: `gh run rerun <RUN_ID> --failed`)
- Look for environment-specific issues (timezone, locale, OS)

### Dependency issues
- `npm ci` or `pip install` failures: check lockfile consistency
- Version conflicts: compare local vs CI Node/Python versions
- Private registry auth: check `NPM_TOKEN` or `PYPI_TOKEN` secrets

### Linting / type checking
- Run the same command locally: check the workflow file for the exact command
- Auto-fix when possible: `npx eslint --fix`, `ruff format`, `cargo fmt`

### Build failures
- Missing env vars in CI (check `${{ secrets.X }}` references)
- Memory/timeout issues: increase runner resources or add `--max-old-space-size`

### Permission issues
- `GITHUB_TOKEN` permissions: check `permissions:` block in workflow
- Third-party action version pinning: use SHA instead of tag

## Step 4: Fix and Verify

```bash
# Run the failing command locally first
# (copy exact command from workflow YAML)

# Push fix
git add -A && git commit -m "fix: resolve CI failure in [component]"
git push

# Watch the new run
gh run watch
```

## Step 5: Prevent Recurrence
- Add the failing case to local pre-commit hooks
- Pin action versions to SHA: `uses: actions/setup-node@<SHA>`
- Add `--ci` flags to npm commands in workflows
- Set `fail-fast: false` in matrix builds to see all failures at once

## Workflow File Location
```bash
ls .github/workflows/
cat .github/workflows/*.yml
```
