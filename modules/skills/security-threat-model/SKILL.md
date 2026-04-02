---
name: security-threat-model
description: Generate repo-specific threat models with STRIDE analysis and trust boundaries
read_when: "user wants a threat model, security assessment, STRIDE analysis, or trust boundary mapping"
---

# Security Threat Model

Generate a structured threat model for any codebase using STRIDE methodology.

## Process

### 1. Map the System
Identify and document:
- **Entry points**: API endpoints, web forms, file uploads, webhooks, CLI inputs
- **Data stores**: Databases, caches, file systems, secrets stores
- **External services**: Third-party APIs, auth providers, payment processors
- **Trust boundaries**: Where privilege levels change (public/auth/admin, client/server, service/service)

### 2. Apply STRIDE per Component

For each component crossing a trust boundary, evaluate:

| Threat | Question | Example |
|--------|----------|---------|
| **S**poofing | Can an attacker impersonate a user or service? | Missing auth on internal API |
| **T**ampering | Can data be modified in transit or at rest? | Unsigned webhooks, no HMAC |
| **R**epudiation | Can actions be denied without evidence? | Missing audit logs |
| **I**nformation Disclosure | Can sensitive data leak? | Stack traces in responses, verbose errors |
| **D**enial of Service | Can the system be overwhelmed? | No rate limiting, unbounded queries |
| **E**levation of Privilege | Can a user gain unauthorized access? | IDOR, missing RBAC checks |

### 3. Rate and Prioritize

Use DREAD scoring (1-10 each):
- **D**amage potential
- **R**eproducibility
- **E**xploitability
- **A**ffected users
- **D**iscoverability

Priority = average score. Focus on items scoring 7+.

### 4. Output Format

```markdown
## Threat Model: [System Name]

### Architecture Overview
[Diagram or description of components and data flows]

### Trust Boundaries
1. Client <-> API Gateway (public internet)
2. API Gateway <-> Backend services (VPC)
3. Backend <-> Database (private subnet)

### Threats Identified
| ID | Component | STRIDE | Description | DREAD | Mitigation |
|----|-----------|--------|-------------|-------|------------|
| T1 | /api/users/:id | Spoofing, EoP | No ownership check on user data | 8.2 | Add RBAC middleware |

### Recommendations (Priority Order)
1. [Critical] ...
2. [High] ...
```

### 5. Codebase Analysis Checklist
- [ ] Auth middleware on all routes
- [ ] Input validation/sanitization
- [ ] SQL parameterization (no string interpolation)
- [ ] Secrets in env vars, not code
- [ ] CORS properly configured
- [ ] Rate limiting on public endpoints
- [ ] Audit logging for state changes
- [ ] Error messages don't leak internals
