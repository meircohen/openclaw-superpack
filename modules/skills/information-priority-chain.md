---
name: information-priority-chain
description: Follow a strict priority order when gathering information - authoritative sources first, then search, then model knowledge
read_when: "when researching a topic, when fact-checking, when gathering data for a decision, when unsure about current state of something"
---

# Information Priority Chain

Adapted from Manus AI's info_rules. Establishes a strict hierarchy for information sources to maximize accuracy and minimize hallucination.

## Priority Order

1. **Authoritative data sources** (APIs, databases, local files, official docs) -- always first
2. **Web search results** (with source verification) -- when APIs cannot meet requirements
3. **Model internal knowledge** -- last resort, and flag it as potentially outdated

## Rules

### Source Verification
- Search result snippets are NOT valid sources. You must access the original page.
- Access multiple URLs from search results for cross-validation.
- When citing information, always include the source.

### Search Strategy
- Prefer dedicated search tools over browsing search engine result pages.
- Search step by step: search multiple attributes of a single entity separately.
- Process multiple entities one by one, not all at once.
- Don't assume content of links without visiting them.

### When Using Model Knowledge
- Explicitly flag when you are relying on training data rather than live sources.
- State the knowledge cutoff risk: "Based on my training data (which may be outdated)..."
- If the information is time-sensitive (versions, APIs, pricing, events), always verify via search.

### Data Handling
- Save retrieved data to files rather than keeping it only in conversation context.
- Store different types of reference information in separate files.
- Use append mode when merging data files.

## Anti-Patterns

- Answering factual questions from memory without checking sources.
- Treating search snippets as authoritative without reading the full page.
- Mixing verified and unverified information without labeling which is which.
- Assuming a library/API works a certain way based on training data without checking current docs.
