# Superpowers Audit — obra/superpowers (v5.0.6)

**Source:** https://github.com/obra/superpowers
**Audit date:** 2026-03-31
**Repo:** 60+ files, 15 skills, 1 hook, 3 commands, 1 agent, Claude Code plugin
**Stars:** ~94K
**Prior audit:** v4.3.0 (same date, initial pass) — this is the comprehensive update

---

## 1. The 7-Phase Workflow and Quality Enforcement

Superpowers implements a **mandatory 7-phase pipeline** where each skill's terminal state names the next required skill. The agent cannot skip phases — the chain is enforced through skill sequencing, not hooks.

```
Phase 1: BRAINSTORM → Phase 2: PLAN → Phase 3: ISOLATE → Phase 4: EXECUTE
    │                    │                │                    │
    │ Design approval    │ Plan saved     │ Worktree ready     │ Two-stage review
    │ gate               │ gate           │ baseline green     │ per task
    ▼                    ▼                ▼                    ▼
Phase 5: REVIEW → Phase 6: VERIFY → Phase 7: COMPLETE
    │                 │                  │
    │ Spec + quality   │ Evidence-first   │ 4-option merge
    │ gates            │ assertion gate   │ decision gate
    ▼                  ▼                  ▼
                                         DONE
```

### Phase Details

| # | Phase | Skill | Gate Condition | Terminal State |
|---|-------|-------|----------------|----------------|
| 1 | **Brainstorm** | `brainstorming` | User approves design doc; spec written to `docs/superpowers/specs/` | → invoke `writing-plans` |
| 2 | **Plan** | `writing-plans` | Plan saved to `docs/superpowers/plans/`; self-reviewed for placeholders | → choose execution mode |
| 3 | **Isolate** | `using-git-worktrees` | Worktree created on feature branch; `npm install`/equiv; baseline tests green | → begin execution |
| 4 | **Execute** | `subagent-driven-development` OR `executing-plans` | All tasks implemented; each passes two-stage review | → request final review |
| 5 | **Review** | `requesting-code-review` + `receiving-code-review` | Final code-reviewer subagent approves entire implementation | → verify |
| 6 | **Verify** | `verification-before-completion` | Fresh test command output cited; evidence before assertions | → invoke finish skill |
| 7 | **Complete** | `finishing-a-development-branch` | Tests verified; user chooses merge/PR/keep/discard; worktree cleaned | → DONE |

### Cross-Cutting Disciplines (active during any phase)

| Discipline | Skill | Iron Law |
|------------|-------|----------|
| TDD | `test-driven-development` | NO PRODUCTION CODE WITHOUT A FAILING TEST FIRST |
| Debugging | `systematic-debugging` | NO FIXES WITHOUT ROOT CAUSE INVESTIGATION FIRST |
| Verification | `verification-before-completion` | NO COMPLETION CLAIMS WITHOUT FRESH VERIFICATION EVIDENCE |

### How Quality Is Enforced

1. **Hard gates block progression.** Each phase has a precondition — the brainstorming skill uses `<HARD-GATE>` XML tags to prevent code before design approval.

2. **Rationalization defense.** Each discipline skill includes a table of 8-12 excuses Claude might use, with explicit refutations. Example from TDD:
   - "I'll write tests after" → Tests written after pass immediately, proves nothing
   - "Deleting X hours of work is wasteful" → Sunk cost fallacy
   - "TDD is dogmatic" → TDD IS pragmatic; shortcuts = debugging in production

3. **Red flags lists.** Each skill lists internal thoughts that mean STOP:
   - "This is just a simple question" → Questions are tasks. Check for skills.
   - "Quick fix for now, investigate later" → STOP. Return to Phase 1.

4. **Two-stage review per task.** Spec compliance (does code match requirements?) runs BEFORE code quality (is code well-built?). This catches "well-written but wrong" AND "spec-compliant but messy".

5. **Fresh subagent per task.** Context pollution treated as first-class failure mode. Each implementer subagent starts clean with curated context.

6. **Evidence-first assertions.** Can't say "tests pass" without showing `34/34 pass` output from a command run in the same message.

---

## 2. Hook System and Integration

### Architecture (Single Hook)

```json
{
  "hooks": {
    "SessionStart": [{
      "matcher": "startup|clear|compact",
      "hooks": [{
        "type": "command",
        "command": "\"${CLAUDE_PLUGIN_ROOT}/hooks/run-hook.cmd\" session-start",
        "async": false
      }]
    }]
  }
}
```

**Key design decisions:**
- **Synchronous** (`async: false`) — blocks until complete, ensures context is available on first turn
- **Fires on startup, clear, and compact** — skills awareness survives context resets
- **Content injection via JSON** — Reads `using-superpowers/SKILL.md`, JSON-escapes it, outputs as `hookSpecificOutput.additionalContext`
- **Dual platform support** — Outputs `additional_context` for Cursor, `hookSpecificOutput` for Claude Code, with deduplication avoidance

### What the Hook Injects

The full content of `using-superpowers/SKILL.md` wrapped in `<EXTREMELY_IMPORTANT>` tags. This establishes:
1. Skills exist and must be checked before any action
2. How to access skills (Skill tool, not Read tool)
3. Priority order: user instructions > skills > system prompt
4. Rationalization defense for skill-skipping

### JSON Escape Pattern (Performance)
```bash
# O(n) bash parameter substitution instead of O(n²) character loop
escape_for_json() {
    local s="$1"
    s="${s//\\/\\\\}"
    s="${s//\"/\\\"}"
    s="${s//$'\n'/\\n}"
    s="${s//$'\r'/\\r}"
    s="${s//$'\t'/\\t}"
    printf '%s' "$s"
}
```

### Comparison with Our Mesh

| Aspect | Our Mesh Hooks | Superpowers Hook |
|--------|---------------|-----------------|
| Count | Multiple event-driven hooks | Single SessionStart hook |
| Implementation | Python subprocess handlers, profile-based (minimal/standard/strict) | Single bash script, JSON output |
| Skill awareness | Via CLAUDE.md instructions | Via context injection at every session start |
| Flexibility | More flexible (multiple events, profiles) | Simpler (one hook does one thing) |
| Resilience | Survives session if CLAUDE.md loaded | Re-injects on clear/compact via matcher |

---

## 3. Subagent Prompt Templates (Unique Pattern)

Superpowers provides **three prompt templates** for its subagent-driven-development workflow:

### Implementer Prompt (`implementer-prompt.md`)
- Receives FULL task text (never reads plan file)
- Has explicit "Before You Begin" section encouraging questions
- Has "When You're in Over Your Head" section — "It is always OK to stop and say 'this is too hard for me.' Bad work is worse than no work."
- Reports structured status: `DONE | DONE_WITH_CONCERNS | BLOCKED | NEEDS_CONTEXT`
- Self-review checklist: completeness, quality, discipline, testing

### Spec Reviewer Prompt (`spec-reviewer-prompt.md`)
- **Core principle:** "CRITICAL: Do Not Trust the Report"
- "The implementer finished suspiciously quickly. Their report may be incomplete, inaccurate, or optimistic."
- Must read actual code, not trust claims
- Checks: missing requirements, extra work, misunderstandings
- Returns: ✅ compliant or ❌ issues with file:line references

### Code Quality Reviewer Prompt (`code-quality-reviewer-prompt.md`)
- Only dispatched AFTER spec compliance passes
- Uses `superpowers:code-reviewer` agent template
- Additional checks: file responsibility, decomposition, file growth
- Returns: Strengths, Issues (Critical/Important/Minor), Assessment

**Key pattern we don't have:** The "Do Not Trust the Report" adversarial stance for reviewers. Our reviewers don't have explicit instructions to be skeptical of implementer claims.

---

## 4. Persuasion Principles for Skill Design

Unique to Superpowers — `writing-skills/persuasion-principles.md` documents research-backed principles for making skills more effective:

**Research:** Meincke et al. (2025) tested 7 persuasion principles with N=28,000 AI conversations. Compliance increased from 33% → 72% with persuasion techniques.

### Principles Applied

| Principle | Technique | Example |
|-----------|-----------|---------|
| **Authority** | Imperative language, non-negotiable framing | "YOU MUST", "No exceptions" |
| **Commitment** | Require announcements, force explicit choices | "Announce skill usage" |
| **Scarcity** | Time-bound requirements, sequential dependencies | "IMMEDIATELY request review" |
| **Social Proof** | Universal patterns, failure modes | "Every time", "X without Y = failure" |
| **Unity** | Collaborative language, shared goals | "we're colleagues", "our codebase" |

**Avoid:** Reciprocity (feels manipulative), Liking (creates sycophancy)

### Combination by Skill Type

| Type | Use | Avoid |
|------|-----|-------|
| Discipline-enforcing | Authority + Commitment + Social Proof | Liking, Reciprocity |
| Guidance/technique | Moderate Authority + Unity | Heavy authority |
| Collaborative | Unity + Commitment | Authority, Liking |
| Reference | Clarity only | All persuasion |

**What we don't have:** We don't apply persuasion research to our skill design. Our skills use prose instructions without deliberate persuasion architecture.

---

## 5. Testing Anti-Patterns Reference

`test-driven-development/testing-anti-patterns.md` provides 5 anti-patterns with gate functions:

| Anti-Pattern | Gate Function |
|--------------|---------------|
| Testing mock behavior | "Am I testing real behavior or mock existence?" |
| Test-only methods in production | "Is this only used by tests?" |
| Mocking without understanding | "What side effects does the real method have?" |
| Incomplete mocks | "What fields does the real API response contain?" |
| Integration tests as afterthought | Follow TDD cycle |

**Key insight:** Each anti-pattern includes a "gate function" — a decision procedure to run BEFORE the anti-pattern can occur. This is a pattern we could adopt for our skill design.

---

## 6. Code Review Reception as Adversarial Protocol

`receiving-code-review/SKILL.md` is notably adversarial in its stance:

### Forbidden Responses
- "You're absolutely right!" — explicit CLAUDE.md violation
- "Great point!" / "Excellent feedback!" — performative
- ANY gratitude expression — "If you catch yourself about to write 'Thanks': DELETE IT"

### Evaluation Before Implementation
```
BEFORE implementing external feedback:
  1. Check: Technically correct for THIS codebase?
  2. Check: Breaks existing functionality?
  3. Check: Reason for current implementation?
  4. Check: Works on all platforms/versions?
  5. Check: Does reviewer understand full context?
```

### YAGNI Check on "Professional" Features
```
IF reviewer suggests "implementing properly":
  grep codebase for actual usage
  IF unused: "This endpoint isn't called. Remove it (YAGNI)?"
```

**What we don't have:** Our code review skills don't explicitly counter sycophantic agreement or mandate skeptical evaluation of external feedback.

---

## 7. CLAUDE.md Comparison

### Their CLAUDE.md Approach
Superpowers doesn't ship a CLAUDE.md — it uses **SessionStart hook context injection** instead. The `using-superpowers` skill IS their CLAUDE.md equivalent, injected every session.

### Our CLAUDE.md Approach
We use a static CLAUDE.md at `~/.claude/CLAUDE.md` that:
- Points to shared context files (CONTEXT.md, DECISIONS.md, CAPABILITIES.md, QUEUE.md)
- Lists available superpowers skills with one-line descriptions
- States Iron Laws for TDD and Debugging
- Describes handoff workflow to OpenClaw

### Key Differences

| Aspect | Our CLAUDE.md | Superpowers `using-superpowers` |
|--------|-------------|-------------------------------|
| Delivery | Static file, loaded once | Injected on every start/clear/compact |
| Skill list | Manual bullet list | Describes discovery system |
| Enforcement | States iron laws | Includes rationalization defense |
| Priority system | Not explicit | Explicit: user > skills > system prompt |
| Rationalization defense | None | 11-row table of thoughts that mean STOP |
| Skill type system | Not present | Rigid (follow exactly) vs Flexible (adapt) |

### What We're Missing
1. **Re-injection on context clear** — Our CLAUDE.md doesn't survive `/compact` or `/clear` without explicit re-read
2. **Rationalization defense in CLAUDE.md** — We state rules but don't counter excuses
3. **Skill priority ordering** — We don't specify what wins when skills conflict with user instructions
4. **Mandatory skill checking** — "Even a 1% chance a skill might apply means you should invoke"

---

## 8. Patterns We Don't Have in Our Mesh

### 8a. Two-Stage Review (spec compliance → code quality)
**Gap:** Our `orchestrate.py` uses a single reviewer role. Superpowers separates "does it match the spec?" from "is it well-built?" — catches two distinct failure modes with different reviewers.

**Recommendation:** Split our reviewer role into spec_reviewer + quality_reviewer in orchestrate.py.

### 8b. Adversarial Reviewer Stance
**Gap:** Our reviewers don't have explicit instructions to distrust implementer reports. Superpowers says: "The implementer finished suspiciously quickly. Their report may be incomplete, inaccurate, or optimistic."

**Recommendation:** Add adversarial framing to our review templates.

### 8c. Persuasion-Engineered Skills
**Gap:** Our skills use plain prose instructions. Superpowers deliberately applies authority, commitment, scarcity, and social proof principles based on Meincke et al. (2025) research showing 33% → 72% compliance improvement.

**Recommendation:** Redesign our discipline-enforcing skills with authority + commitment + social proof.

### 8d. Gate Functions for Anti-Patterns
**Gap:** Our testing guidance doesn't include decision procedures to run BEFORE anti-patterns can occur. Superpowers provides "BEFORE X: Ask Y" patterns that prevent problems at the point of decision.

**Recommendation:** Add gate functions to our TDD and testing skills.

### 8e. Structured Escalation Protocol for Subagents
**Gap:** Our subagents don't have a `DONE_WITH_CONCERNS | BLOCKED | NEEDS_CONTEXT` status system. Superpowers gives implementers explicit permission and protocol to say "this is too hard for me."

**Recommendation:** Add structured status reporting to our subagent prompts.

### 8f. Anti-Sycophancy in Code Review
**Gap:** Our code review reception doesn't explicitly counter performative agreement ("You're absolutely right!") or mandate skeptical evaluation. Superpowers forbids ALL gratitude expressions.

**Recommendation:** Add anti-sycophancy rules to our code review skills.

### 8g. Plan Self-Review with No-Placeholder Rule
**Gap:** Our plans don't have a mandatory self-review pass checking for "TBD", "TODO", "similar to Task N", or vague steps like "add appropriate error handling". Superpowers lists these as explicit plan failures.

**Recommendation:** Add no-placeholder enforcement to our planning skills.

### 8h. Model Selection for Subagents
**Gap:** Our orchestrate.py doesn't have guidance on which model to use for which task type. Superpowers specifies: mechanical tasks → cheap model, integration → standard, architecture/review → most capable.

**Recommendation:** Add model selection guidance to our subagent dispatch.

### 8i. Visual Companion for Brainstorming
**Gap:** Superpowers offers a browser-based visual companion for showing mockups and diagrams during brainstorming. We have no equivalent.

**Status:** Low priority — nice to have but not critical for our workflow.

---

## 9. Patterns We Already Have That They Don't

| Pattern | Our Mesh | Superpowers |
|---------|----------|-------------|
| Multi-system orchestration | OpenClaw ↔ Claude Code handoff mesh | Single-agent only |
| Loop safety | `loop_safety.py` with stall/cost detection | Manual controller management |
| Cost awareness | `intercept.py`, `cost.py`, `cost_tracker_hook.py` | Acknowledged as expensive, no controls |
| Workflow types | 5 types (feature, bugfix, refactor, security, research) | 2 types (subagent-driven, executing-plans) |
| Health monitoring | `health.py`, `health-status.json` | None |
| Security scanning | `security_scan.py` | None |
| Context budget management | `context_budget.py` | None (relies on Claude Code's built-in) |
| Prompt optimization | `prompt_optimize.py` | None |

---

## 10. Extracted Patterns — Ready to Integrate

### Pattern 1: Rationalization Defense Table
```markdown
## Common Rationalizations
| Excuse | Reality |
|--------|---------|
| "[specific thought]" | [why it's wrong and what to do instead] |
```
**Use in:** Any discipline-enforcing skill. Build from observed failures.

### Pattern 2: Evidence-First Assertion Gate
```
BEFORE claiming any status:
1. IDENTIFY: What command proves this claim?
2. RUN: Execute fresh
3. READ: Full output, check exit code
4. VERIFY: Does output confirm claim?
5. ONLY THEN: Make the claim
```

### Pattern 3: Two-Stage Review Loop
```
Implementer → Spec Reviewer (does it match requirements?)
  ↓ issues? → fix → re-review
Spec OK → Code Quality Reviewer (is it well-built?)
  ↓ issues? → fix → re-review
Both OK → mark complete
```

### Pattern 4: Subagent Status Protocol
```
DONE              — proceed to review
DONE_WITH_CONCERNS — read concerns, decide if they matter
NEEDS_CONTEXT     — provide context, re-dispatch
BLOCKED           — assess: context problem? reasoning limit? task too large? plan wrong?
```

### Pattern 5: `<HARD-GATE>` Attention Anchor
```xml
<HARD-GATE>
Do NOT [action] until [condition]. This applies to EVERY [scope].
</HARD-GATE>
```

### Pattern 6: Adversarial Reviewer Framing
```
CRITICAL: Do Not Trust the Report
The implementer finished suspiciously quickly. Their report may be
incomplete, inaccurate, or optimistic. You MUST verify independently.
```

### Pattern 7: No-Placeholder Plan Rule
```
Plan failures — NEVER write:
- "TBD", "TODO", "implement later"
- "Add appropriate error handling"
- "Write tests for the above" (without actual test code)
- "Similar to Task N" (repeat the code)
- Steps that describe what to do without showing how
```

---

## Changelog from v4.3.0 Audit

- Updated version: v4.3.0 → v5.0.6
- Added: Persuasion principles analysis (§4)
- Added: Testing anti-patterns with gate functions (§5)
- Added: Code review reception adversarial protocol (§6)
- Added: CLAUDE.md comparison (§7)
- Added: Model selection for subagents (§8h)
- Added: Visual companion (§8i)
- Expanded: Subagent prompt template analysis (§3)
- Expanded: Patterns we already have (§9)
- Restructured: Extracted patterns section (§10) for direct integration
