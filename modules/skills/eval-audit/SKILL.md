---
name: eval-audit
description: Audit LLM evaluation pipelines to find gaps, bias, and quality issues
read_when: "user wants to audit evals, evaluate LLM outputs, build eval pipelines, or assess AI quality"
---

# LLM Eval Audit

Systematically audit evaluation pipelines for LLM-powered features.

## Audit Checklist

### 1. Coverage
- [ ] All user-facing LLM features have evals
- [ ] Edge cases are represented (empty input, long input, adversarial)
- [ ] Multiple languages/locales if applicable
- [ ] Failure modes are tested (hallucination, refusal, off-topic)

### 2. Test Data Quality
- [ ] Sufficient volume (minimum 100 examples per eval)
- [ ] Representative of production distribution
- [ ] Labeled by domain experts (not just the developer)
- [ ] Balanced across categories (no class imbalance)
- [ ] Includes hard negatives and boundary cases

### 3. Eval Method Assessment

| Method | Pros | Cons | When to Use |
|--------|------|------|-------------|
| Exact match | Fast, deterministic | Brittle | Structured output |
| Contains/regex | Simple | High false positive | Keyword checks |
| LLM-as-Judge | Flexible, nuanced | Expensive, variable | Subjective quality |
| Human review | Gold standard | Slow, expensive | Calibration, audit |
| Embedding similarity | Semantic matching | Threshold tuning | Paraphrase tolerance |

### 4. LLM-as-Judge Validation
If using LLM-as-Judge:
- [ ] Judge prompt is specific (not "rate quality 1-5")
- [ ] Rubric defines each score level with examples
- [ ] Judge is calibrated against human labels (>80% agreement)
- [ ] Position bias tested (swap order of options)
- [ ] Judge model is different from the model being evaluated

### 5. Metrics
- [ ] Primary metric defined and tracked over time
- [ ] Regression detection automated (alert on >X% drop)
- [ ] Results segmented by category/difficulty
- [ ] Confidence intervals reported (not just averages)

## Eval Pipeline Structure
```
Test Dataset -> LLM Under Test -> Output Capture -> Evaluator(s) -> Score Aggregation -> Dashboard
                                                         |
                                                   Human Review (sample)
```

## Common Failure Modes to Check
1. **Hallucination**: Claims facts not in context
2. **Instruction following**: Ignores format requirements
3. **Safety**: Generates harmful content when prompted
4. **Consistency**: Different answers to equivalent questions
5. **Regression**: New model version breaks existing capabilities

## Quick Error Analysis
```python
# Categorize failures
failures = [ex for ex in results if ex['score'] < threshold]
# Group by: error type, input length, category, difficulty
# Look for patterns: are failures clustered?
```

## Output
Deliver as a findings report:
| Finding | Severity | Impact | Recommendation |
|---------|----------|--------|----------------|
| No adversarial test cases | High | May miss jailbreaks | Add 50 adversarial examples |
