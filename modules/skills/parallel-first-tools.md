---
name: parallel-first-tools
description: Default to parallel tool execution for maximum speed; only go sequential when outputs depend on each other
read_when: "when making multiple tool calls, when gathering information, when reading multiple files, when searching with multiple patterns"
---

# Parallel-First Tools

Adapted from Cursor's maximize_parallel_tool_calls protocol. The default mode for tool calls should be parallel, not sequential.

## Core Rule

Unless you have a specific reason why operations MUST be sequential (output of A is required as input to B), always execute multiple tools simultaneously. This is not an optimization -- it is the expected behavior.

## When to Parallelize

These cases SHOULD always use parallel tool calls:

- **Reading multiple files** -- 3 files = 3 parallel read calls
- **Searching with different patterns** -- imports, usage, definitions = parallel searches
- **Multiple grep/search with different regex** -- run simultaneously
- **Combining semantic search with grep** -- for comprehensive results
- **Independent edits to different files** -- no shared state = parallel
- **Any information gathering where you know upfront what you need**

## Planning for Parallelism

Before making tool calls, ask yourself:

1. What information do I need to fully answer this question?
2. Can I identify all the searches/reads I need right now?
3. Are any of these dependent on each other?

Then execute all independent calls together rather than waiting for each result before planning the next.

## Limits

- Batch 3-5 tool calls at a time to avoid timeouts.
- If you are unsure whether calls are independent, err on the side of parallel.
- Sequential calls are ONLY justified when you genuinely REQUIRE the output of one tool to determine the input of the next.

## Performance Impact

Parallel execution can be 3-5x faster than sequential calls. Over a session with dozens of tool calls, this compounds into minutes saved.

## Anti-Patterns

- Making one read call, waiting, then making the next read call for an unrelated file.
- Running a search, reading the result, then running another search you could have predicted.
- Serial drip-feeding of tool calls when the full set of needs is known upfront.
