# Ruflo Raid

Audit date: 2026-03-31

## Bottom line

Ruflo is not pure vapor. There is a real package split, a real CLI wrapper, and a real stdio MCP entrypoint. But the repo is much stronger on narrative than on reproducible proof. My read: **real project, heavily over-marketed, not trustworthy enough to adopt as a core dependency without independent validation**.

If the claim is "85% API cost reduction via WASM acceleration + tiered routing + Q-Learning router," the repo does **not** prove that end to end.

## What is clearly real

- The repo ships a real umbrella package and CLI delegation layer:
  - root `bin/cli.js` forwards into `v3/@claude-flow/cli/bin/cli.js`
  - `v3/@claude-flow/cli/bin/mcp-server.js` implements a stdio MCP loop and calls `listMCPTools`, `callMCPTool`, and `hasTool`
- The package structure is real:
  - `@claude-flow/cli`
  - `@claude-flow/shared`
  - `@claude-flow/guidance`
- There is a real modular design around optional acceleration packages:
  - `@ruvector/router`
  - `@ruvector/learning-wasm`
  - `@ruvector/rvagent-wasm`
  - `@ruvector/ruvllm-wasm`
  - `agentic-flow`

That means the project is not just a README. There is an actual packaging and integration story.

## Where the claims break down

### 1. Cost reduction claim: not proven in-repo

- The README says Ruflo "works with any LLM" and "smart routing picks the cheapest option."
- `CLAUDE.md` describes a 3-tier routing stack:
  - Tier 1: Agent Booster (WASM)
  - Tier 2: Haiku
  - Tier 3: Sonnet/Opus
- But issue `#794` explicitly frames multi-provider execution and major cost savings as a **goal**:
  - "Current State: Claude-flow provides excellent coordination ... but is locked to Anthropic provider only."
  - "Desired State: ... flexible multi-provider execution layer."
- The `@claude-flow/cli` package does not directly show first-class OpenAI/Gemini/OpenRouter SDK wiring. Most of that story appears pushed into optional dependencies, especially `agentic-flow`.

Verdict: **possible in the broader ruv ecosystem, not convincingly implemented and proven inside this repo**.

### 2. WASM acceleration: plausible, but not audited proof

- The repo clearly leans on a WASM story:
  - README: "Agent Booster (WASM)"
  - optional deps include multiple `@ruvector/*wasm` packages
  - `@claude-flow/guidance` exports a `wasm-kernel`
- But the repo audit did not surface a clean, reproducible benchmark harness that proves the headline numbers from this codebase.
- Issue `#794` still describes the execution layer and booster adapter as "NEW", which suggests the big performance story was still mid-integration.

Verdict: **there is probably a real WASM acceleration layer somewhere in the dependency graph, but the repo does not give enough hard evidence to trust the 352x / huge-savings story on faith**.

### 3. Tiered model routing: concept exists, implementation proof is thin

- The routing concept is present in docs:
  - simple transforms -> WASM
  - medium work -> cheaper model
  - complex work -> stronger model
- That pattern is directionally smart.
- But the repo evidence is mostly declarative docs + optional package references, not a clearly auditable routing engine with benchmarked behavior.

Verdict: **pattern is real enough to learn from, but not proven enough to buy into as a black box**.

### 4. Q-Learning router: I could not substantiate it

- I did not find a concrete Q-Learning router implementation in the repo surfaces I audited:
  - README
  - package manifests
  - CLI/MCP entrypoints
  - major issues/releases
- If that claim exists in marketing, it is not a visible core implementation artifact here.

Verdict: **unsubstantiated**.

### 5. README drift / internal inconsistency

- The README says RVF replaces the `sql.js` WASM dependency.
- But `v3/@claude-flow/shared/package.json` still depends on `sql.js`.

That does not kill the project, but it is a strong signal that the docs are ahead of the actual repo state.

### 6. Repo-level auditability is weak

- The CLI entrypoints import compiled files like `v3/@claude-flow/cli/dist/src/mcp-client.js`.
- On GitHub main, some of those compiled paths are not directly inspectable from the repo view I audited.

That makes the repo harder to trust for deep technical claims because the most important runtime behavior is partly hidden behind packaged build output and optional deps.

## Best patterns worth stealing

### 1. Deterministic fast-path before LLM

This is the best idea in the repo.

For trivial edits and boilerplate transforms, try a local deterministic path first:
- code mods
- lint fixes
- type insertion
- boilerplate scaffolding

If it succeeds, skip the model entirely. That is a real path to cost and latency reduction.

### 2. Explicit complexity tiers

The "simple / medium / complex" split is useful even if their numbers are not.

For our mesh:
- simple -> local transform or script
- medium -> subscription model / cheaper model
- complex -> strongest model + structured verification

We already do cost routing. This would sharpen it.

### 3. Auto-mode CLI/MCP entrypoint

The CLI auto-detecting stdio MCP mode is good ergonomics. It reduces config sprawl.

### 4. Hooked context autopilot

The compaction / archive / restore budget idea is strong:
- archive every turn
- importance rank old context
- restore only what is worth paying for

That is more interesting than the swarm marketing.

### 5. Package split with optional accelerators

Core orchestration separated from optional speedups is the right shape. We should steal the shape, not the dependency stack.

## What I would not steal

- Any headline benchmark without a local harness and raw output
- Any "BFT / queen / neural / self-learning" language unless there is a narrow, testable operational definition
- Dependency trees where the magic lives in optional packages we do not control

## What we should do for our mesh

### Steal now

- Add a deterministic "fast path" classifier before model invocation
- Add explicit complexity tiers to routing
- Add memory compaction / restore-budget logic to reduce context waste
- Consider a cleaner MCP entrypoint wrapper for local tools

### Do not do

- Do not replace the mesh with Ruflo
- Do not trust the cost-savings claim without our own benchmark harness
- Do not import their orchestration stack as foundational infrastructure

## Final verdict

**Interesting idea mine, not a trusted substrate.**

There is enough real structure here to steal patterns from. There is not enough hard evidence to accept the performance and cost claims as proven. Treat Ruflo as a source of orchestration ideas, not as a framework we should center the mesh around.

## Sources

- https://github.com/ruvnet/ruflo
- https://raw.githubusercontent.com/ruvnet/ruflo/main/README.md
- https://raw.githubusercontent.com/ruvnet/ruflo/main/package.json
- https://raw.githubusercontent.com/ruvnet/ruflo/main/bin/cli.js
- https://raw.githubusercontent.com/ruvnet/ruflo/main/v3/%40claude-flow/cli/package.json
- https://raw.githubusercontent.com/ruvnet/ruflo/main/v3/%40claude-flow/cli/bin/cli.js
- https://raw.githubusercontent.com/ruvnet/ruflo/main/v3/%40claude-flow/cli/bin/mcp-server.js
- https://raw.githubusercontent.com/ruvnet/ruflo/main/v3/%40claude-flow/shared/package.json
- https://raw.githubusercontent.com/ruvnet/ruflo/main/v3/%40claude-flow/guidance/package.json
- https://raw.githubusercontent.com/ruvnet/ruflo/main/CLAUDE.md
- https://github.com/ruvnet/ruflo/issues/794
- https://github.com/ruvnet/ruflo/issues/890
