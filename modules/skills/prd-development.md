---
name: prd-development
description: Write structured product requirements documents from problem through specs to stories
read_when: "user wants to write a PRD, product spec, feature requirements, or product brief"
---

# PRD Development

Structured process for writing product requirements documents.

## PRD Template

### 1. Problem Statement
- **Who** is affected? (User segment)
- **What** is the problem? (Observable behavior)
- **Evidence**: Metrics, user quotes, support tickets
- **Impact**: What happens if we don't solve this?

### 2. Goals and Non-Goals

| Goals | Non-Goals |
|-------|-----------|
| Solve X for user segment Y | Not building Z this iteration |
| Reduce metric A by B% | Not supporting platform P |

### 3. Success Metrics
| Metric | Current | Target | Measurement |
|--------|---------|--------|-------------|
| Task completion rate | 60% | 85% | Analytics event |
| Support tickets/week | 50 | <20 | Zendesk query |
| Time to complete flow | 5 min | 2 min | Session recording |

### 4. User Personas
For each persona: name, role, key need, current workaround, frustration level.

### 5. Solution Overview
- High-level approach (not implementation details)
- Key user flows (numbered steps)
- Wireframes or mockups (link or inline)
- Edge cases and error states

### 6. Technical Considerations
- Dependencies on other systems
- Data model changes
- API contracts
- Performance requirements
- Security implications
- Migration plan (if applicable)

### 7. User Stories
```
As a [persona],
I want to [action],
So that [outcome].

Acceptance Criteria:
- Given [context], when [action], then [result]
- Given [context], when [action], then [result]
```

### 8. Release Plan
- **Phase 1 (MVP)**: [Minimum to validate hypothesis]
- **Phase 2**: [Based on Phase 1 learnings]
- **Phase 3**: [Full vision]

### 9. Open Questions
| Question | Owner | Due Date | Decision |
|----------|-------|----------|----------|
| Should we support X? | @PM | MM/DD | Pending |

## Process
1. Draft problem statement (30 min)
2. Validate with stakeholders (1-2 days)
3. Write solution section (2-4 hours)
4. Engineering review for feasibility (1 day)
5. Design review for UX (1 day)
6. Final sign-off and story breakdown
