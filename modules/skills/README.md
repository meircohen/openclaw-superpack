# Skills Module

A collection of reusable AI agent skills and raid reports for enhancing Claude Code and OpenClaw workflows.

## Structure

```
skills/
  <skill-name>/SKILL.md   # 23 mesh skills (agent capabilities)
  raids/                   # Repo raid reports (tool/library analysis)
```

## Mesh Skills

Each skill is a self-contained SKILL.md that defines when to activate, core rules, workflow steps, and quality gates. Skills are loaded into agent context when the matching task type is detected.

| Skill | Description |
|-------|-------------|
| `article-writing` | Long-form content with voice matching |
| `autonomous-loops` | Self-correcting agent loops with exit conditions |
| `benchmark` | Performance benchmarking and comparison |
| `codebase-onboarding` | Rapid codebase understanding |
| `content-engine` | Content pipeline management |
| `context-budget` | Token/context window management |
| `continuous-learning-v2` | Agent learning from past sessions |
| `cost-aware-llm-pipeline` | Cost-optimized LLM routing |
| `data-scraper-agent` | Structured web data extraction |
| `deep-research` | Multi-source deep research |
| `eval-harness` | Evaluation framework for agent outputs |
| `iterative-retrieval` | Multi-pass retrieval refinement |
| `market-research` | Market and competitive analysis |
| `openclaw-persona-forge` | Persona creation and management |
| `prompt-optimizer` | Prompt engineering and optimization |
| `repo-scan` | Repository analysis and auditing |
| `search-first` | Search-before-build methodology |
| `security-review` | Security auditing and vulnerability assessment |
| `strategic-compact` | Strategic planning and decision frameworks |
| `tdd-workflow` | Test-driven development workflow |
| `token-budget-advisor` | Token usage analysis and optimization |
| `verification-loop` | Multi-stage output verification |
| `x-api` | X/Twitter API integration |

## Raid Reports

Raid reports are deep-dive analyses of notable repos and tools. They document architecture, integration patterns, and lessons learned.

| Raid | Subject |
|------|---------|
| `claude-octopus` | Multi-LLM orchestration plugin for Claude Code |
| `coasts` | Coast-related tooling analysis |
| `fastmcp` | FastMCP server framework |
| `gemini-extensions` | Gemini model extensions |
| `awesome-claude-code-toolkit` | Claude Code toolkit ecosystem |
| `awesome-ai-agents` | AI agents landscape survey |

## Usage

### Loading a Skill
Skills are designed to be loaded into an agent's system prompt or context when the matching task type is detected. The SKILL.md frontmatter includes `name` and `description` fields for automatic matching.

### Using Raid Reports
Raid reports provide reference material for integration decisions. Read them before adopting a tool or library to understand architecture, tradeoffs, and integration patterns.

## Adding New Skills

1. Create a directory: `skills/<skill-name>/`
2. Add a `SKILL.md` with frontmatter (name, description, origin)
3. Include: activation triggers, core rules, workflow steps, quality gates, common pitfalls
4. Test the skill by running it against real tasks
