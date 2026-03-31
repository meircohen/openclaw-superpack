# Skill: Research Brief

You are researching a topic and producing a structured deliverable. Quality = specific, sourced, actionable. Not a Wikipedia summary.

## Inputs
Brief includes: `question`, `depth`, `sources`, `output`, `output_file`, `constraints`.

## Steps

### 1. Plan your search
Based on `depth`:
- **quick** (5 min, 3 sources): 2-3 targeted web searches. Get the answer, cite it, done.
- **standard** (15 min, 8 sources): Web + specified sources. Cross-reference claims. Note disagreements.
- **deep** (30 min+, 15+ sources): Exhaustive. Multiple search angles. Primary sources preferred. Synthesize conflicting information.

### 2. Search each source type

**Web:**
```bash
bash scripts/search.sh "precise query" 10
```
Or use web_search / web_fetch tools. Read the actual pages -- don't rely on snippets.

**Email (if in sources):**
```bash
gog gmail messages search "relevant keywords" --max 10 --json
```

**Memory (if in sources):**
Check `memory/` daily notes and blocks for relevant prior context.

**Docs (if in sources):**
```bash
rg -l "keywords" /path/to/docs/
```

**GitHub (if in sources):**
```bash
gh search repos "query" --limit 5
gh search issues "query" --limit 10
```

**Fireflies (if in sources):**
```bash
bash scripts/fireflies-helper.sh search_person "name"
bash scripts/fireflies-helper.sh list_meetings
```

### 3. Evaluate sources
For each source, note:
- Is this primary or secondary?
- How recent? (apply constraints if specified)
- Does it corroborate or contradict other sources?
- Any obvious bias?

### 4. Synthesize

**bullet-points format:**
```
## [Question]

- **Finding 1:** Detail. [Source: URL]
- **Finding 2:** Detail. [Source: URL]
- **Key uncertainty:** What we don't know yet.
- **Recommendation:** What to do with this info.
```

**summary format:**
2-4 paragraphs. Lead with the answer. Support with evidence. End with implications and next steps.

**report format:**
Full structured report with sections: Executive Summary, Findings, Analysis, Recommendations, Sources.

### 5. Fact-check
Before finalizing:
- Are all numbers verified from primary sources?
- Are dates correct?
- Are names/titles spelled right?
- Any claims that could be embarrassing if wrong?

**Rule: Vague > Wrong.** "Approximately $50M" beats "$47.3M" if you're not sure.

### 6. Write output
If `output_file` specified, write there. Otherwise, return the research in your response.

## Common Pitfalls
- Don't confuse Google snippets with actual content. Click through.
- Don't cite one source for a major claim. Cross-reference.
- If SearXNG is down, fall back to web_search tool.
- Time-box yourself. Don't spend 30 min on a "quick" depth research.
- If a constraint says "only 2025+" don't include 2024 sources.

## Success = All of these are true:
- [ ] Question is directly answered (not danced around)
- [ ] Source count meets depth tier minimum
- [ ] All numbers/dates are verified or explicitly marked uncertain
- [ ] Output matches requested format
- [ ] Written to output_file if specified
- [ ] Completed within time budget for depth tier
