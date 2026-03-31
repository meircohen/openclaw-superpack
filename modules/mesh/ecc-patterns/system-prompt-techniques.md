# System Prompt Optimization Techniques

## Source
Extracted from ECC (everything-claude-code) patterns

## 1. Authority Hierarchy
System prompt content has HIGHEST authority, then user messages, then tool results.
Use `--system-prompt` flag to inject high-authority context dynamically.

## 2. Context-Specific Aliases
Create mode-specific aliases that load different contexts:
- dev mode: loads project state, active tasks, coding rules
- review mode: loads review checklists, security rules
- research mode: loads search patterns, citation requirements

## 3. Rule Layering
- Global rules: ~/.claude/settings.json (user scope, every session)
- Project rules: .claude/rules/*.md (project scope, team-shared)
- Dynamic rules: --system-prompt flag (session scope, task-specific)

## 4. MCP Tool Minimization
Each MCP server adds tool definitions to context window. Replace with CLI wrappers:
- GitHub MCP → `gh` CLI wrapped in skills/commands
- Supabase MCP → `supabase` CLI wrapped in skills
- Result: Same functionality, less context consumption

## 5. Strategic Compaction
- Don't rely on auto-compaction (triggers too late at 95%)
- Set CLAUDE_AUTOCOMPACT_PCT_OVERRIDE=50
- Compact AFTER exploration, BEFORE implementation
- Compact AFTER debugging, BEFORE new work
- NEVER compact mid-implementation or mid-debug

## 6. Subagent Context Protection
Main session context is precious. Use subagents (Task tool) for:
- File exploration (reads 20 files, returns summary)
- Test running (runs suite, returns results)
- Search/research (searches broadly, returns findings)
Main context stays clean with only the synthesized results.

## 7. Extended Thinking Control
- Default MAX_THINKING_TOKENS: 31,999 (expensive!)
- Recommended: 10,000 for most tasks (~70% cost reduction)
- Set to 0 for trivial tasks
- Toggle with Alt+T / Option+T

## 8. Model Routing Mid-Session
Switch models without losing context:
- /model sonnet — default for most work
- /model opus — complex reasoning only
- /model haiku — quick lookups
Use CLAUDE_CODE_SUBAGENT_MODEL=haiku for subagents

## 9. Session Persistence Architecture
Three-hook pattern for memory across sessions:
1. session-start: Load previous session context
2. pre-compact: Save state before compaction
3. session-end: Persist learnings and progress

Session files should contain:
- What worked (with evidence)
- What was tried but failed
- What's left to do

## 10. Continuous Learning Loop
Pattern: Session → Extract patterns → Save as skill → Auto-load next session
Trigger on Stop hook when session has ≥10 user messages.
Extract: debugging techniques, workarounds, project patterns.

## 11. Hook-Based Automation
Use hooks for repetitive quality enforcement:
- PostToolUse[Edit]: Auto-format (black/ruff for Python)
- PreToolUse[Bash]: Block dangerous commands, remind about tmux
- PostToolUse[Bash]: Check for build completion, notify desktop
- Stop: Evaluate session, persist learnings

## 12. Instinct System (Learning Memory)
Instincts = learned behaviors with confidence scores.
- instinct-export: Share learnings as portable YAML
- instinct-import: Load learnings from files/URLs
- evolve: Analyze instincts, generate skills/commands/agents
Pattern: repeated corrections → instinct → skill → automated behavior

## 13. Skeleton Projects Pattern
For new projects: search for skeleton/template repos first.
Clone skeleton → customize → much faster than from scratch.

## 14. Repository Pattern for Data
Abstract data access through Repository pattern:
- Clean separation of data logic from business logic
- Easy to mock for testing
- Consistent API across data sources

## 15. Envelope API Response Pattern
Wrap all API responses:
```json
{"success": true, "data": {...}, "error": null, "meta": {"page": 1}}
```
Consistent handling across all endpoints.
