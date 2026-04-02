---
name: incident-response
description: Structured incident response with triage, communication, and post-mortem
read_when: "user is dealing with a production incident, outage, service degradation, or needs an incident response plan"
---

# Incident Response

Structured workflow for handling production incidents from detection to post-mortem.

## Severity Levels

| Level | Criteria | Response Time | Example |
|-------|----------|--------------|---------|
| SEV1 | Complete outage, data loss risk | Immediate | Database down, auth broken |
| SEV2 | Major feature broken, workaround exists | 30 min | Payment processing delayed |
| SEV3 | Minor feature degraded | 4 hours | Slow search, UI glitch |
| SEV4 | Cosmetic, no user impact | Next sprint | Logging noise, minor UI |

## Incident Workflow

### 1. Detect and Triage (0-5 min)
```
- What is broken? (symptoms, not guesses)
- Who is affected? (all users, segment, internal)
- When did it start? (check deploy times, cron jobs)
- What changed recently? (deploys, config changes, dependencies)
- Assign severity level
```

### 2. Communicate (5-10 min)
```
INCIDENT: [Title]
SEVERITY: SEV[X]
IMPACT: [Who is affected and how]
STATUS: Investigating
LEAD: [Name]
CHANNEL: #incident-[date]-[name]
```

Update stakeholders every 30 min for SEV1, every hour for SEV2.

### 3. Investigate (parallel tracks)
```bash
# Check recent deploys
git log --oneline --since="2 hours ago"

# Check error rates
# (use your monitoring: Datadog, Grafana, CloudWatch)

# Check logs
kubectl logs -l app=api --tail=100 --since=30m
# or
aws logs tail /aws/ecs/api --follow

# Check resource usage
kubectl top pods
```

### 4. Mitigate
Priority order:
1. **Rollback** if a deploy caused it: `git revert HEAD && git push`
2. **Feature flag** off the broken feature
3. **Scale up** if capacity issue
4. **Redirect traffic** if regional
5. **Hotfix** only if rollback is impossible

### 5. Resolve and Verify
- Confirm metrics return to baseline
- Test affected user flows
- Update status page
- Notify stakeholders of resolution

### 6. Post-Mortem (within 48 hours)

```markdown
## Incident Post-Mortem: [Title]

### Timeline
| Time | Event |
|------|-------|
| HH:MM | First alert fired |
| HH:MM | Incident declared |
| HH:MM | Root cause identified |
| HH:MM | Mitigation applied |
| HH:MM | Resolved |

### Root Cause
[Blameless description of what went wrong]

### Impact
[Users affected, duration, revenue impact]

### Action Items
| Item | Owner | Due | Priority |
|------|-------|-----|----------|
| Add monitoring for X | @eng | MM/DD | High |
| Add circuit breaker | @eng | MM/DD | Medium |
```

## Key Principle: Mitigate first, investigate second. Stop the bleeding before finding root cause.
