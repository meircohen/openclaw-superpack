---
name: risk-assessment
description: "Classify risk before editing code or executing commands. Apply right level of caution to each change."
read_when: "about to make code changes, run destructive commands, deploy, migrate, or modify production systems"
---

# Risk Assessment

Classify risk before action. Apply the right level of caution to each change.

## Risk Tiers

**Low** -- Local, reversible, no sensitive data, narrow scope.
- Proceed with standard checks.

**Medium** -- Shared code paths, moderate impact, recoverable with effort.
- Expand tests, call out rollback path.

**High** -- Production data/systems, destructive commands, broad impact.
- Request explicit approval before proceeding.

**Privacy-Critical** -- PII-heavy, credentials, auth systems.
- High tier + data audit + explicit approval.

## Process
1. Assign a risk tier with one-line justification
2. Apply tier-appropriate safeguards
3. If uncertain between tiers, choose the higher tier
4. Execute with verification matching the tier

## Safety Rules
- Never expose credentials, tokens, or secret files
- Never run destructive operations without explicit user confirmation
- Clearly list assumptions that could affect correctness
- For medium/high: document rollback path before executing

## Output
- Risk tier assigned (with justification)
- Safeguards applied
- Verification run
- Residual risk noted
