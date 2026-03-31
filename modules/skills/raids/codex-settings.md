# Repo Raid: Codex Settings

- Repo: `feiskyer/codex-settings`
- Stars: `166` on GitHub as observed on 2026-03-31
- Companion verification source: `openai/codex` official config docs/schema

## What this repo is

This is a practitioner config repo for Codex rather than the Codex source tree itself. It is useful because it shows how a serious user organizes real `config.toml` files, skills, prompts, and provider variants. I cross-checked the reusable knobs against `openai/codex` so the patterns below are not just one person's local hacks.

## Key patterns

### 1. Profiles over one giant config

The repo leans on `[profiles.*]` plus multiple config variants (`config.toml`, `ollama.toml`, `gemini.toml`, `azure.toml`) instead of one overloaded default. That keeps model, sandbox, and provider changes isolated.

### 2. MCP servers as the real plugin system

The strongest pattern is explicit `[mcp_servers.*]` blocks with a stable server name, launch command, args, and environment wiring. This is a better operating model than burying tool setup inside shell aliases or prompt text.

### 3. Skills are directories, not prompt snippets

Each skill lives under `skills/<name>/SKILL.md` and can include scripts or assets. The useful pattern is packaging workflow instructions with the code or CLI entrypoints they depend on.

### 4. Delegation wrappers stay thin

The `claude-skill` examples wrap agent-to-agent delegation, but they keep the wrapper narrow: define the task, pass the prompt, avoid re-implementing the downstream CLI. That prevents config drift.

### 5. Project-local scratch space

The repo uses dedicated output areas like `.research/` and `.autonomous/`. This is a good pattern for keeping agent-generated intermediates out of durable docs until they are reviewed.

### 6. Prompt packs are separate from runtime config

There are reusable prompts for research and autonomous work, but they are not mixed into the base transport settings. This separation makes it easier to tune workflows without destabilizing the environment.

### 7. Cross-provider portability matters

The repo is set up to swap between OpenAI, Azure OpenAI, Ollama, and Gemini-style configs. The durable pattern is to design around provider slots and profiles, not provider-specific prompts.

### 8. Official Codex schema confirms the important knobs

The official `openai/codex` repo confirms the configuration surface worth standardizing around: `profiles`, `mcp_servers`, `plugins`, `projects.<path>.trust_level`, `permissions`, `memories`, `approvals_reviewer`, `apps`, and `connectors`.

## Actionable takeaways

- Split our Codex setup into a small base config plus named profiles such as `research`, `builder`, `review`, and `ops`.
- Treat MCP entries as first-class infrastructure. Give every server a stable name and explicit env contract.
- Package reusable workflows as skill folders with `SKILL.md` plus scripts, not giant AGENTS files or loose prompt fragments.
- Add project-scoped trust and permission defaults per workspace path instead of one global sandbox posture.
- Create dedicated scratch/output directories for agent runs, then promote only reviewed artifacts into durable docs.
- Keep delegation adapters thin. Pass scope, inputs, and success criteria; do not duplicate another agent's CLI/config logic.
- Version prompts separately from runtime settings so model/provider changes do not rewrite workflow instructions.
- Use the official Codex schema as the source of truth before adopting knobs from community repos.

## Sources

- https://github.com/feiskyer/codex-settings
- https://raw.githubusercontent.com/feiskyer/codex-settings/main/config.toml
- https://raw.githubusercontent.com/feiskyer/codex-settings/main/skills/deep-research/SKILL.md
- https://raw.githubusercontent.com/feiskyer/codex-settings/main/skills/claude-skill/SKILL.md
- https://github.com/openai/codex
- https://raw.githubusercontent.com/openai/codex/main/docs/config.md
- https://raw.githubusercontent.com/openai/codex/main/codex-rs/core/config.schema.json
