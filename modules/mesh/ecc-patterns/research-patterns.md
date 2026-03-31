# Research Patterns

Extracted from ECC's codebase analysis methodology and research playbook.

## 1. Codebase Analysis Structure

From ECC's ecc2-codebase-analysis.md -- a model for thorough codebase review.

### Standard Report Sections

1. **Architecture Overview** -- Module breakdown with line counts, key patterns, dependency graph
2. **Code Quality Metrics** -- Total lines, test count, unwrap/unsafe counts, TODO/FIXME counts, max file size
3. **Identified Gaps** -- Numbered list of missing features, stubs, half-built systems
4. **Test Coverage Analysis** -- Per-module test counts, coverage focus areas, direct coverage gaps
5. **Security Observations** -- Secrets check, process spawning audit, input sanitization review
6. **Dependency Health** -- Version table with current vs latest, removal candidates
7. **Recommendations (Prioritized)** -- P0 quick wins, P1 feature completions, P2 robustness, P3 extensibility
8. **Framework Best Practices Comparison** -- How code compares to idiomatic usage
9. **Risk Assessment** -- Likelihood/Impact/Mitigation table

### Key Patterns in Analysis

- **Quantify everything**: Line counts per module, exact test counts, specific metric values
- **Use tables**: Module breakdowns, dependency versions, risk assessments all use tables
- **Be specific about gaps**: Don't say "comms is incomplete" -- say "comms/mod.rs has send() but no receive(), poll(), inbox(), or subscribe()"
- **Prioritize findings**: Use P0/P1/P2/P3 with clear criteria (P0 = quick wins, P3 = extensibility)
- **Include code locations**: Reference specific files and line numbers (e.g., "dashboard.rs:495")
- **Compare to standards**: Check against framework best practices, not just internal consistency

### Analysis Checklist

```
[ ] Module breakdown with line counts
[ ] Architecture patterns identified
[ ] Code quality metrics (unwrap, unsafe, TODO counts)
[ ] Test coverage per module
[ ] Coverage gaps identified
[ ] Security review (secrets, injection, process spawning)
[ ] Dependency audit (versions, unused deps)
[ ] Prioritized recommendations
[ ] Risk assessment table
```

## 2. Research Playbook Approach

From ECC's everything-claude-code-research-playbook.md.

### Core Defaults

- **Prefer primary documentation and direct source links** -- Always go to the source first
- **Include concrete dates** when facts may change over time -- Prevents stale information from being treated as current
- **Keep a short evidence trail** for each recommendation or conclusion -- Every claim should trace back to a source

### Suggested Research Flow

1. **Inspect local code and docs first** -- Exhaust what's already available before going external
2. **Browse only for unstable or external facts** -- Don't waste research time on things that are stable and local
3. **Summarize findings with file paths, commands, or links** -- Actionable output, not abstract summaries

### Research Priority Order

1. Local codebase and documentation (git log, source files, README)
2. Primary documentation (official docs for libraries/frameworks)
3. GitHub issues and discussions (for bugs, edge cases, workarounds)
4. Web search (for broader context, alternatives, community patterns)

## 3. Primary Documentation Emphasis

### Why Primary Sources Matter

- **Accuracy**: Primary docs reflect actual behavior, not someone's interpretation
- **Currency**: Official docs are updated with releases; blog posts and tutorials may be stale
- **Completeness**: Primary docs cover edge cases and caveats that secondary sources skip
- **Attribution**: Linking to primary sources makes recommendations verifiable

### How to Apply

When researching a library, framework, or API:

1. **Start with the repo**: README, CHANGELOG, migration guides
2. **Check official docs**: API reference, guides, tutorials from the maintainers
3. **Look at tests**: The project's own test suite shows intended usage patterns
4. **Then go external**: Stack Overflow, blog posts, community forums

When documenting findings:

```
Claim: "ratatui 0.29 supports TableState for stateful selection"
Source: ratatui docs, ratatui/examples/table.rs
Date: 2026-03-26
```

## 4. Source Attribution Practices

### Attribution Format

Every recommendation or conclusion should include:

- **What**: The specific claim or recommendation
- **Source**: File path, URL, or command that produced the evidence
- **Date**: When the information was verified (important for rapidly-changing facts)
- **Confidence**: How certain the claim is (based on source quality and recency)

### Example Attribution Trail

```
## Finding: SQLite lock contention risk is LOW

Evidence:
- DbWriter pattern uses dedicated OS thread (session/runtime.rs:45-89)
- mpsc::unbounded_channel with oneshot acknowledgements prevents concurrent writes
- No shared Connection objects across async tasks
- Pattern matches recommended approach from rusqlite docs (2026-03-15)

Confidence: HIGH -- architectural pattern prevents the issue by design
```

### When to Flag Uncertainty

- Version-specific behavior: "As of ratatui 0.29 (may change in 0.30)"
- Undocumented behavior: "Observed in testing, not confirmed in docs"
- Community consensus: "Common recommendation on GitHub issues, no official guidance"
- Stale information: "Last verified 2025-06-15, check for updates"

## 5. Applying These Patterns in the Mesh

### For Codebase Analysis Tasks
Route to Claude Code (strong at code reading and structured analysis). Use the 9-section report template above. Record the analysis in shared/handoffs/ for other systems to reference.

### For Research Tasks
Route to Perplexity first (web-grounded search), then Gemini (synthesis of large document sets), then Claude Code (actionable recommendations). Each step produces a handoff document with source attribution.

### For Documentation Tasks
Start with local code inspection, then primary docs, then web search. Always include dates and source links. Use the evidence trail format for every claim.
