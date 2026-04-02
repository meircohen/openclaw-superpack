---
name: spec-driven-feature
description: Transform a rough feature idea into requirements, design, and implementation tasks using structured spec workflow
read_when: "when building a complex feature from scratch, when the user has a rough idea that needs structure, when planning a multi-day implementation"
---

# Spec-Driven Feature Development

Adapted from Kiro's spec workflow. Transforms a rough idea into structured artifacts before any code is written. Each phase requires explicit user approval before proceeding.

## Three Phases

### Phase 1: Requirements (requirements.md)

Generate requirements in EARS format (Easy Approach to Requirements Syntax):

```
### Requirement 1
**User Story:** As a [role], I want [feature], so that [benefit]

#### Acceptance Criteria
1. WHEN [event] THEN [system] SHALL [response]
2. IF [precondition] THEN [system] SHALL [response]
```

Rules:
- Generate an initial version based on the idea WITHOUT asking sequential questions first.
- Consider edge cases, UX, technical constraints, and success criteria.
- After writing, ask: "Do the requirements look good? If so, we can move on to the design."
- Do NOT proceed until you get explicit approval ("yes", "looks good", etc.).
- If feedback is given, revise and ask again.

### Phase 2: Design (design.md)

Create a design document with these sections:
- Overview
- Architecture
- Components and Interfaces
- Data Models
- Error Handling
- Testing Strategy

Rules:
- Incorporate research findings directly -- do not create separate research files.
- Use Mermaid diagrams where appropriate.
- Highlight design decisions and their rationales.
- After writing, ask: "Does the design look good? If so, we can move on to the implementation plan."
- Do NOT proceed until explicit approval.

### Phase 3: Tasks (tasks.md)

Create an implementation plan as a numbered checkbox list:

```
- [ ] 1. Set up project structure and core interfaces
  - Create directory structure
  - Define boundary interfaces
  - _Requirements: 1.1_

- [ ] 2. Implement data models
- [ ] 2.1 Create core interfaces and types
  - Write TypeScript interfaces
  - _Requirements: 2.1, 3.3_
```

Rules:
- Each task must reference specific requirements.
- Tasks must be actionable by a coding agent -- no "gather user feedback" or "deploy to prod".
- Prioritize test-driven development.
- Each step builds incrementally on previous steps.
- After writing, ask: "Do the tasks look good?"

## Key Principles

- Always get explicit approval before moving to the next phase.
- Offer to return to earlier phases if gaps are found.
- This workflow is ONLY for planning. Implementation is separate.
- Execute one task at a time. Stop after each for review.
