# Agent Guide

The OpenClaw system includes 55 specialized agents, each designed for a specific domain of work. This guide explains how agents are structured, how to create new ones, and how they collaborate.

## Agent Structure

Every agent is defined by two files in its directory:

### SOUL.md

The agent's core definition. Contains:

- **Purpose** -- What the agent exists to do
- **Expertise** -- The domain knowledge the agent possesses
- **Personality** -- Communication style and behavioral traits
- **Guidelines** -- Rules and principles the agent follows
- **Boundaries** -- What the agent should not attempt (triggers delegation to others)

Example structure:

```markdown
# Soul

## Purpose
You are a code review specialist focused on security, performance, and maintainability.

## Expertise
- Static analysis patterns
- Common vulnerability classes (OWASP Top 10)
- Performance anti-patterns across languages
- Clean code principles

## Guidelines
- Always explain the "why" behind feedback
- Prioritize findings by severity
- Suggest fixes, not just problems
- Acknowledge good patterns when you see them

## Boundaries
- Do not write implementation code (delegate to development agents)
- Do not make deployment decisions (delegate to operations agents)
```

### IDENTITY.md

The agent's operational metadata. Contains:

- **Name** -- The agent's identifier
- **Role** -- One-line role description
- **Category** -- Which agent category it belongs to
- **Delegation targets** -- Other agents this one commonly delegates to
- **Escalation path** -- Where to route work that exceeds this agent's scope

Example structure:

```markdown
# Identity

## Name
SecurityReviewer

## Role
Security-focused code review specialist

## Category
Development

## Delegates To
- CodeWriter (for implementing fixes)
- InfraOps (for infrastructure-level mitigations)

## Escalates To
- LeadArchitect (for design-level security concerns)
```

## Agent Categories

### Development

Agents focused on writing, reviewing, and maintaining code:
- Code generation and completion
- Code review (style, security, performance)
- Test writing and test strategy
- Debugging and root cause analysis
- Refactoring and technical debt reduction

### Operations

Agents focused on infrastructure and deployment:
- CI/CD pipeline management
- Deployment automation
- Monitoring and alerting
- Infrastructure provisioning
- Incident response

### Research

Agents focused on information gathering and analysis:
- Technology evaluation
- Competitive analysis
- Documentation research
- Trend analysis
- Best practice surveys

### Communication

Agents focused on content and messaging:
- Technical writing
- Documentation generation
- Summarization
- Translation
- Status reporting

### Coordination

Agents focused on workflow management:
- Task routing and prioritization
- Project planning
- Schedule management
- Cross-agent orchestration
- Escalation handling

## Creating Custom Agents

### 1. Create the agent directory

```bash
mkdir -p ~/.openclaw/workspace/agents/my-agent
```

### 2. Write SOUL.md

Define the agent's purpose, expertise, personality, guidelines, and boundaries. Be specific about what the agent should and should not do -- clear boundaries prevent overlap with existing agents.

Key principles for writing a good SOUL.md:
- **Be specific** -- "Reviews Python code for type safety issues" is better than "Reviews code"
- **Define boundaries** -- Explicitly state what is out of scope
- **Set tone** -- How should the agent communicate? Terse and technical? Friendly and explanatory?
- **Include examples** -- Show the kind of output you expect

### 3. Write IDENTITY.md

Define the agent's name, role, category, delegation targets, and escalation path.

Guidelines:
- Choose a descriptive name that makes the agent's role immediately clear
- Map delegation targets to existing agents that complement this one
- Define an escalation path for work that exceeds scope

### 4. Test the agent

Use the agent in a Claude Code session to verify:
- It stays within its defined scope
- It delegates appropriately when hitting boundaries
- Its communication style matches the personality defined in SOUL.md
- It produces useful output for its intended task type

## Agent Collaboration Patterns

### Direct Delegation

One agent hands off a subtask to another:

```
CodeReviewer finds a bug
    --> delegates fix to CodeWriter
    --> CodeWriter returns the fix
    --> CodeReviewer verifies the fix
```

### Chain of Agents

A multi-step workflow where output flows through a sequence:

```
ResearchAgent gathers requirements
    --> ArchitectAgent designs the solution
    --> CodeWriter implements it
    --> TestWriter writes tests
    --> CodeReviewer reviews everything
```

### Parallel Dispatch

Independent subtasks sent to multiple agents simultaneously:

```
Coordinator receives a large task
    --> dispatches frontend work to FrontendDev
    --> dispatches backend work to BackendDev
    --> dispatches test plan to TestWriter
    --> collects and integrates all results
```

### Escalation

An agent encounters work beyond its scope:

```
JuniorReviewer finds an architecture concern
    --> escalates to LeadArchitect
    --> LeadArchitect makes the decision
    --> decision flows back to JuniorReviewer
```

## Best Practices

- **Keep agents focused** -- An agent that does one thing well is more useful than one that does many things poorly
- **Define clear boundaries** -- Overlap between agents creates confusion about which one to use
- **Use delegation** -- Agents should not try to handle work outside their expertise; they should delegate
- **Write testable guidelines** -- If you cannot verify whether an agent is following a guideline, the guideline is too vague
- **Review periodically** -- As your workflow evolves, update agent definitions to match current needs
