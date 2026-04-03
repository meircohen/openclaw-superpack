---
name: memory-consolidation
description: "Dream consolidation pass over memory directory. Merges, prunes, deduplicates, and strengthens memory entries."
read_when: "heartbeat runs memory maintenance, user asks to clean/consolidate/organize memories, or memory blocks exceed size limits"
---

# Memory Consolidation

Run a "dream" consolidation pass over the memory directory to produce a clean, non-redundant working set.

## Phase 1 -- Orient
- List contents of memory directory
- Read the index/blocks
- Skim existing topic files to understand current state

## Phase 2 -- Gather Recent Signal
- Look for new information worth persisting from daily logs
- Identify drifted memories that contradict current state
- Search narrowly (grep with targeted queries) for overlooked details

## Phase 3 -- Consolidate
- Merge new signal into existing entries -- avoid near-duplicates
- Convert relative dates ("yesterday", "last week") to absolute dates
- Delete facts contradicted by fresher evidence

## Phase 4 -- Prune and Index
- Refresh index to stay within size limit
- Remove stale or dangling pointers
- Shorten verbose entries without losing essential meaning
- Add pointers to newly created memories
- Resolve contradictions between entries

## Rules
- Fewer, stronger memories over many weak ones
- Merge overlapping entries by evidence strength and recency
- Promote durable patterns and constraints; demote one-off observations

## Memory Entry Format
- **Statement** -- The fact or preference
- **Evidence** -- Brief supporting context
- **Confidence** -- high / medium / low

## Output
Brief report: what was consolidated, what was updated, what was pruned.
