---
name: product-discovery
description: Run structured product discovery to validate opportunities before committing engineering resources
read_when: "user asks about product discovery, opportunity solution tree, assumption mapping, problem validation, user research planning, or discovery sprint"
---

# Product Discovery

You run structured discovery to de-risk product bets. Build evidence before building software.

## Core Workflow

### 1. Define the Outcome
- Pick one measurable outcome to improve (e.g., activation rate, NPS, time-to-value)
- Set baseline and target with a time horizon
- If the outcome isn't measurable, redefine it until it is

### 2. Build an Opportunity Solution Tree (Teresa Torres)
```
Outcome (metric to move)
  |-- Opportunity A (unmet need / pain)
  |     |-- Solution idea A1
  |     |     |-- Experiment: prototype test
  |     |-- Solution idea A2
  |           |-- Experiment: survey
  |-- Opportunity B
        |-- Solution idea B1
              |-- Experiment: concierge test
```

Rules:
- At least 3 distinct opportunities before converging
- Opportunities come from user evidence, not internal brainstorms
- Every solution needs at least one experiment before building

### 3. Map Assumptions

For each solution idea, list assumptions across four dimensions:

| Dimension | Question |
|-----------|----------|
| Desirability | Do users want this? Will they use it? |
| Viability | Can we monetize it? Does it fit our model? |
| Feasibility | Can we build it in reasonable time? |
| Usability | Can users figure it out without help? |

Score each: risk (high/medium/low) x certainty (high/medium/low). Test highest-risk, lowest-certainty assumptions first.

### 4. Validate the Problem
- Conduct 5-8 user interviews focused on behavior, not opinions
- Ask: "Tell me about the last time you [did the thing]"
- Look for: frequency, severity, current workarounds, willingness to pay
- Kill opportunities where the pain is mild or rare

### 5. Validate the Solution
- Prototype before building. Options: Figma prototype, concierge, Wizard of Oz, fake door
- Measure behavior, not stated preference
- Run concept tests: "If this existed, would you switch from [current solution]?"
- Success criteria defined before the test, not after

### 6. Discovery Sprint Format
- Duration: 1-2 weeks
- Start with explicit hypotheses
- Daily 15-min evidence reviews
- End with decision: **Proceed** / **Pivot** / **Stop**

## Interview Guide Template

```
1. Context: Tell me about your role and how [topic] fits into your work.
2. Current behavior: Walk me through the last time you [did X].
3. Pain: What was the hardest part? What happened as a result?
4. Workarounds: What do you do today to deal with that?
5. Ideal: If you could wave a magic wand, what would change?
6. Priority: How important is solving this vs other problems you have?
```

Never ask: "Would you use this?" or "Would you pay for this?" People say yes to both and do neither.

## Rules
- Evidence > opinions. Always.
- Kill ideas early and cheaply. That is the point.
- Discovery is not a phase. It runs continuously alongside delivery.
