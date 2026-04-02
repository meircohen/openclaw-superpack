---
name: security-static-analysis
description: Run static analysis with Semgrep, CodeQL, and SARIF for security vulnerabilities
read_when: "user wants static analysis, security scanning, Semgrep rules, CodeQL queries, or SARIF reports"
---

# Security Static Analysis

Use Semgrep, CodeQL, and SARIF to find security vulnerabilities in code.

## Semgrep (Fast, Pattern-based)

### Install and Run
```bash
pip install semgrep
# Or: brew install semgrep

# Run with curated security rules
semgrep --config auto .
semgrep --config p/security-audit .
semgrep --config p/owasp-top-ten .

# Language-specific
semgrep --config p/python .
semgrep --config p/javascript .
semgrep --config p/typescript .
```

### Custom Semgrep Rule
```yaml
rules:
  - id: hardcoded-secret
    pattern: |
      $X = "AKIA..."
    message: "Possible hardcoded AWS access key"
    languages: [python, javascript, typescript]
    severity: ERROR
    metadata:
      cwe: "CWE-798"
```

```bash
semgrep --config my-rules.yml .
```

### Key Rulesets
- `p/security-audit` - General security
- `p/owasp-top-ten` - OWASP Top 10
- `p/secrets` - Hardcoded credentials
- `p/sql-injection` - SQLi patterns
- `p/xss` - Cross-site scripting

## CodeQL (Deep, Semantic)

### Setup
```bash
# Install CodeQL CLI
gh extension install github/gh-codeql

# Create database
codeql database create ./codeql-db --language=javascript --source-root=.

# Run queries
codeql database analyze ./codeql-db codeql/javascript-queries:codeql-suites/javascript-security-extended.qls --format=sarif-latest --output=results.sarif
```

## SARIF Output
Both tools can output SARIF for unified reporting:
```bash
semgrep --config auto --sarif --output results.sarif .
```

Upload to GitHub:
```bash
gh api repos/{owner}/{repo}/code-scanning/sarifs \
  -f "sarif=$(gzip -c results.sarif | base64)"
```

## Triage Workflow
1. Run scan, export SARIF
2. Filter by severity: ERROR > WARNING > INFO
3. For each finding:
   - Is it a true positive? (Check context)
   - Is it exploitable? (Check access path)
   - What's the fix? (Apply, or mark as false positive with `nosemgrep` comment)
4. Track findings in issues with CWE references

## CI Integration
```yaml
# .github/workflows/security.yml
- name: Semgrep
  uses: returntocorp/semgrep-action@v1
  with:
    config: p/security-audit p/secrets
```
