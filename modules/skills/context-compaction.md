---
name: context-compaction
description: Structured context compaction and session summarization for efficient continuation across context windows
read_when: "context window is filling up, need to summarize a session for handoff, preparing a continuation summary, or compacting conversation history"
---

# Context Compaction

Create summaries that allow efficient continuation in a new context window where conversation history is replaced with the summary.

## Continuation Summary Format

Use when the full conversation is being replaced:

1. **Task Overview**: Core request, success criteria, constraints
2. **Current State**: What's completed, files created/modified/analyzed (with paths), key artifacts
3. **Important Discoveries**: Technical constraints, decisions + rationale, errors resolved, failed approaches + why
4. **Next Steps**: Specific actions needed, blockers, priority order
5. **Context to Preserve**: User preferences, domain-specific details, promises made

## Detailed Session Summary Format

Use when thorough technical detail must be preserved:

1. **Primary Request and Intent**: All explicit requests in detail
2. **Key Technical Concepts**: Technologies, frameworks, patterns
3. **Files and Code Sections**: Enumerate files with code snippets and why each matters
4. **Errors and Fixes**: Each error, how fixed, user feedback on it
5. **Problem Solving**: Problems solved, ongoing troubleshooting
6. **All User Messages**: Every non-tool-result user message (critical for understanding changing intent)
7. **Pending Tasks**: Explicitly requested work still outstanding
8. **Current Work**: Precisely what was being worked on immediately before compaction, with file names and code
9. **Optional Next Step**: Only if directly in line with user's most recent explicit request -- include direct quotes

## Rules

- Wrap analysis in `<analysis>` tags before producing `<summary>` tags
- Chronologically analyze each section of conversation
- Pay special attention to user feedback and course corrections
- Convert relative dates to absolute dates
- Include full code snippets where they carry meaning
- Err on including information that prevents duplicate work or repeated mistakes
- For partial compaction (older messages only), include "Context for Continuing Work" section so newer messages make sense
- Never drift from what the user actually asked -- verify next steps against most recent explicit requests
