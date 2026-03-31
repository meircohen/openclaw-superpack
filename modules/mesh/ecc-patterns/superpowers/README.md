# Superpowers Code Patterns

Extracted from [obra/superpowers](https://github.com/obra/superpowers) v4.3.0 (2026-03-31).

## Files

| File | Pattern | Mesh Integration |
|------|---------|-----------------|
| `two_stage_review.py` | Spec compliance + code quality review pipeline | Enhances `orchestrate.py` reviewer role |
| `rationalization_defense.py` | Anti-rationalization tables for skill enforcement | Usable in any skill/workflow |
| `evidence_gate.py` | Evidence-first verification gate | Enhances `verify.py` pipeline |
| `hard_gate.py` | Hard-gate enforcement with XML attention anchors | Usable in any skill/workflow |
| `workflow_phases.py` | 6-phase workflow state machine | Reference for mesh orchestration |

## Key Insights

1. **Two-stage review** catches "well-written but wrong" code that single-pass review misses
2. **Rationalization tables** prevent Claude from talking itself out of following process
3. **Evidence-first** gates eliminate "should work" claims — evidence THEN assertion
4. **Fresh subagent per task** prevents context pollution between independent work items
5. **Process flowcharts** (DOT format) are followed more reliably than prose descriptions
