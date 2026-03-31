# Verification: Research Brief

Run these checks BEFORE reporting completion.

## Checks

### 1. Question answered
- [ ] The research question is directly answered (not danced around)
- [ ] Answer is in the first paragraph/bullet (lead with it)
- [ ] Reader can get the gist in 30 seconds

### 2. Source requirements met
Based on `depth`:
- [ ] **quick**: >= 3 sources cited
- [ ] **standard**: >= 8 sources cited
- [ ] **deep**: >= 15 sources cited
- [ ] Sources are actual URLs or specific references (not "various sources")

### 3. Factual accuracy
- [ ] All numbers verified against primary sources
- [ ] All dates are correct
- [ ] All names/titles spelled correctly
- [ ] Uncertain claims marked with "approximately", "reportedly", "as of [date]"
- [ ] No claims that contradict the cited sources

### 4. Format compliance
- [ ] Output matches requested format (summary/report/bullet-points)
- [ ] If `output_file` specified: file exists and contains the research
  ```bash
  ls -la {output_file}
  wc -l {output_file}
  ```

### 5. Constraints honored
- [ ] If date constraints set: no sources outside the range
- [ ] If source constraints set: only used allowed source types
- [ ] If focus constraints set: research stays on topic

### 6. Actionability
- [ ] Research includes "so what" -- implications or recommendations
- [ ] Key uncertainties are flagged (what we still don't know)
- [ ] Next steps are suggested if applicable

## If Any Check Fails
Report which check failed and what's missing. Partial research with honest gaps beats fabricated completeness.
