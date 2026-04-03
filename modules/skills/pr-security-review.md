---
name: pr-security-review
description: Structured PR security review with false-positive filtering and confidence scoring
read_when: "reviewing PR security, conducting security code review, analyzing code changes for vulnerabilities, or running a security audit on a branch"
---

# PR Security Review

Perform a security-focused code review identifying HIGH-CONFIDENCE vulnerabilities with real exploitation potential. Not a general code review -- focus ONLY on security implications newly added by the PR.

## Methodology

### Phase 1: Repository Context Research
- Identify existing security frameworks and libraries in use
- Look for established secure coding patterns in the codebase
- Examine existing sanitization and validation patterns

### Phase 2: Comparative Analysis
- Compare new code against existing security patterns
- Identify deviations from established secure practices
- Flag code that introduces new attack surfaces

### Phase 3: Vulnerability Assessment
- Examine each modified file for security implications
- Trace data flow from user inputs to sensitive operations
- Look for privilege boundaries being crossed unsafely

## Categories to Examine

- **Input validation**: SQL injection, command injection, XXE, template injection, path traversal
- **Auth issues**: authentication bypass, privilege escalation, session flaws, JWT vulns
- **Crypto/secrets**: hardcoded keys, weak algorithms, improper key storage
- **Code execution**: RCE via deserialization, pickle injection, eval injection, XSS
- **Data exposure**: sensitive data logging, PII handling violations, API leakage

## Confidence Scoring

Only report findings with confidence >= 0.8:
- **0.9-1.0**: Certain exploit path identified
- **0.8-0.9**: Clear vulnerability pattern with known exploitation methods
- **Below 0.8**: Do not report (too speculative)

## Hard Exclusions (automatic false positives)

1. DoS/resource exhaustion vulnerabilities
2. Secrets stored on disk if otherwise secured
3. Rate limiting concerns
4. Lack of hardening measures (flag concrete vulns only)
5. Race conditions unless concretely problematic
6. Outdated third-party library vulns (managed separately)
7. Memory safety in memory-safe languages (Rust, etc.)
8. Unit test files
9. Log spoofing, regex injection, regex DoS
10. Environment variables and CLI flags (trusted values)
11. Client-side JS/TS missing auth checks (server handles these)
12. React/Angular XSS unless using dangerouslySetInnerHTML or similar

## Execution Pattern (sub-agent pipeline)

1. **Sub-agent 1**: Explore repo context + analyze PR changes for vulnerabilities
2. **Parallel sub-agents**: One per vulnerability found, each applying false-positive filtering
3. **Filter**: Remove anything with confidence < 8/10

## Output Format

For each finding:
```
# Vuln N: [Category]: `file.py:line`
* Severity: High|Medium
* Description: [What the vulnerability is]
* Exploit Scenario: [How an attacker exploits it]
* Recommendation: [Specific fix]
```

Only report HIGH and MEDIUM. Better to miss theoretical issues than flood with false positives.
