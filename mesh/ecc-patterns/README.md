# ECC-Extracted Patterns for AI Mesh

Patterns extracted from [everything-claude-code](https://github.com/affaan-m/everything-claude-code) (50K+ stars, Anthropic hackathon winner) and adapted for our 10-system mesh architecture.

## Integrated Patterns

| Pattern | File | Source | Status |
|---------|------|--------|--------|
| Quality Gate Pipeline | `mesh/verify.py` | ECC /verify + /quality-gate | Integrated |
| Session Save/Resume | `mesh/session.py` | ECC /save-session + /resume-session | Integrated |
| Multi-Agent Orchestration | `mesh/orchestrate.py` | ECC /orchestrate + handoff docs | Integrated |
| Loop Safety | `mesh/loop_safety.py` | ECC loop-operator agent | Integrated |
| Security Scanning | `mesh/security_scan.py` | ECC security-reviewer + AgentShield | Integrated |
| Checkpoint System | `mesh/checkpoint.py` | ECC /checkpoint command | Integrated |
| Context Budget | `mesh/context_budget.py` | ECC /context-budget + strategic-compact | Integrated |
| Prompt Optimization | `mesh/prompt_optimize.py` | ECC /prompt-optimize command | Integrated |
| Eval Harness | `mesh/eval_harness.py` | ECC eval-harness skill (pass@k) | Integrated |
| Hook System | `mesh/hooks.py` | ECC cursor/kiro hooks framework | Integrated |

## Round 2 Extraction (2026-03-31)

### System Prompt & Configuration
| File | Source | Description |
|------|--------|-------------|
| `ecc-patterns/optimized-claude-md.md` | ECC CLAUDE.md | Adapted system prompt with all optimization techniques |
| `ecc-patterns/system-prompt-techniques.md` | ECC patterns | 15 documented techniques for prompt optimization |
| `ecc-patterns/token-optimization-guide.md` | ECC docs/token-optimization.md | Complete token/cost optimization guide |
| `ecc-patterns/soul-patterns.md` | ECC SOUL.md | Agent identity and orchestration philosophy |

### Skills (23 SKILL.md files in mesh/skills/)
| Skill | Category |
|-------|----------|
| deep-research, market-research | Research |
| data-scraper-agent, iterative-retrieval, search-first | Data retrieval |
| x-api, content-engine, article-writing | Content/Social |
| cost-aware-llm-pipeline, token-budget-advisor | Cost management |
| autonomous-loops, continuous-learning-v2 | Autonomous operation |
| codebase-onboarding, repo-scan | Codebase analysis |
| tdd-workflow, verification-loop | Testing/Verification |
| strategic-compact, context-budget | Context management |
| prompt-optimizer, security-review | Optimization/Security |
| benchmark, eval-harness | Evaluation |
| openclaw-persona-forge | Agent personality |

### Hooks (11 Python files in mesh/hooks/)
| Hook | Source | Description |
|------|--------|-------------|
| `cost_tracker.py` | cost-tracker.js | Track token usage, estimate API costs per session |
| `config_protection.py` | config-protection.js | Block modifications to protected config files |
| `quality_gate.py` | quality-gate.js | Run formatters/linters after edits |
| `session_manager.py` | session-start/end.js + pre-compact.js | Session start/end/compact lifecycle |
| `suggest_compact.py` | suggest-compact.js | Suggest compaction after N tool calls |
| `mcp_health.py` | mcp-health-check.js | MCP server health probing with backoff |
| `evaluate_session.py` | evaluate-session.js | Extract reusable patterns from sessions |
| `governance.py` | governance-capture.js | Detect secrets/policy violations |
| `commit_quality.py` | pre-bash-commit-quality.js | Pre-commit quality checks |
| `desktop_notify.py` | desktop-notify.js | Native desktop notifications |

### Reference Documents
| File | Source | Description |
|------|--------|-------------|
| `ecc-patterns/agent-patterns.md` | ECC agents/*.md (16 agents) | Consolidated agent reference |
| `ecc-patterns/coding-rules.md` | ECC rules/common + rules/python | Python-focused coding rules |
| `ecc-patterns/command-reference.md` | ECC commands/*.md (60 commands) | All slash commands categorized |
| `ecc-patterns/mcp-configs.md` | ECC mcp-configs/ + .mcp.json | MCP server configurations |
| `ecc-patterns/research-patterns.md` | ECC research/ | Research methodology patterns |
| `ecc-patterns/guides/` | ECC root guides | Longform, shortform, security guides |

### Infrastructure
| File | Source | Description |
|------|--------|-------------|
| `mesh/cost_tracker_hook.py` | cost-tracker.js | Standalone cost tracking (also in hooks/) |
| `mesh/sync-systems.sh` | sync-ecc-to-codex.sh | Cross-system config sync (Claude Code/Codex/Gemini) |
| `mesh/learn.py` (updated) | instinct commands + /evolve | Added instinct export/import/status/evolve |
| `mesh/orchestrate.py` (updated) | orchestrate-worktrees.js | Added worktree orchestration patterns |

## Enhanced Existing Files (Round 1)

| File | Enhancement | Source |
|------|-------------|--------|
| `mesh/router.py` | Learning feedback loop, confidence scores | ECC instinct system + model-route |
| `mesh/learn.py` | Instinct evolution, clustering, per-category analysis | ECC /evolve + continuous-learning-v2 |

## Key ECC Concepts Adapted

### Instinct System
Confidence-scored patterns (0.0-1.0) that guide routing decisions. Unlike hardcoded rules, instincts evolve from observed outcomes.

### Handoff Documents
Structured context passing between systems in multi-agent workflows. Each system produces a handoff doc for the next.

### Evidence Before Assertions
Verification runs BEFORE claiming success. No "tests passing" without actual test output.

### Phase-Aware Context Management
Compact/context-switch at logical boundaries (Research → Planning → Implementation → Testing), not mid-phase.

### Non-Blocking Security
Security scans warn but don't block by default. Only critical findings (hardcoded secrets) block execution.

### Session Continuity
"What Did NOT Work" section prevents blind retry of failed approaches across sessions.

### Deterministic Over Probabilistic
Code-based verification (tests, build, grep) preferred over LLM-based judgment for quality gates.

### Authority Hierarchy (New in Round 2)
System prompt > user messages > tool results. Use --system-prompt flag for high-authority dynamic injection.

### Model Routing (New in Round 2)
Haiku for subagents, Sonnet for daily work, Opus for complex reasoning. Switch mid-session with /model.

### Continuous Learning Loop (New in Round 2)
Session → Extract patterns → Save as skill → Auto-load next session. Trigger on session end.
