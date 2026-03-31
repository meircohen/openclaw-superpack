# Repo Raid: Claude Code v2.1.88 Source Audit

**Origin**: npm source map leak (`cli.js.map`, ~59.8 MB) in `@anthropic-ai/claude-code@2.1.88` (March 30-31, 2026)
**Discoverer**: Chaofan Shou (@shoucccc)
**Mirror used**: https://github.com/instructkr/claude-code (12k+ stars, 18k+ forks within hours)
**Original URL**: `ChaofanShou/claude-code-source` — 404 (taken down or never existed at that path)
**Status**: Anthropic unpublished v2.1.88, rolled back to v2.1.87. Code already archived across multiple repos.
**Audited**: 2026-03-31

**Note**: This is the second leak. First was Feb 24, 2025 (inline source map in `cli.mjs`). Third vector was March 7, 2026 (`@anthropic-ai/claude-agent-sdk` accidentally contained the full CLI bundle). This time Bun generated source maps by default and nobody disabled it for the production build.

---

## Architecture Overview

### Scale
| Metric | Count |
|--------|-------|
| Subsystems | 31 major packages |
| Archived modules | ~2,000+ |
| Built-in commands | 207 |
| Built-in tools | 184 |
| Service modules | 130 |
| UI components | 389 |
| Utility modules | 564 |
| React hooks | 104 |
| Bundled skills | 20 |

### Core Directory Structure (src/)

| Directory | Modules | Purpose |
|-----------|---------|---------|
| `assistant/` | - | Session history management |
| `bootstrap/` | - | Startup state coordination |
| `bridge/` | 31 | Remote bridging (SSH, teleport, direct connect, deep link) |
| `buddy/` | 6 | **UNRELEASED** digital pet/companion system |
| `cli/` | 19 | Command-line interface handlers |
| `commands/` | - | ~207 built-in command registry |
| `components/` | 389 | React UI components |
| `constants/` | 21 | Configuration, API limits, system prompt |
| `coordinator/` | 1 | Multi-instance coordination mode |
| `entrypoints/` | 8 | SDK and MCP entry points |
| `hooks/` | 104 | React hooks |
| `keybindings/` | 14 | Custom keybinding + full Vim support |
| `memdir/` | 8 | Long-term persistent memory system |
| `migrations/` | 11 | Settings/state migrations |
| `plugins/` | 2 | Plugin discovery and registration |
| `remote/` | 4 | Remote session management |
| `schemas/` | 1 | Hook schemas |
| `screens/` | 3 | Doctor, REPL, ResumeConversation |
| `server/` | 3 | Direct connect server |
| `services/` | 130 | Business logic + analytics |
| `skills/` | 20 | Bundled skills system |
| `state/` | 6 | Flux-like app state management |
| `types/` | 11 | TypeScript type definitions |
| `upstreamproxy/` | 2 | API relay to Anthropic |
| `utils/` | **564** | Largest subsystem — everything from shell to rendering |
| `vim/` | 5 | Full Vim motions, operators, text objects |
| `voice/` | 1 | Voice mode (speech-to-text, text-to-speech) |

### Core Event Loop

Turn-based query engine (`QueryEnginePort`):

1. **Input**: `submit_message()` receives user prompt
2. **Routing**: Token-based matching against command registry (207) + tool registry (184)
3. **Execution**: Matched commands/tools executed via `ExecutionRegistry`
4. **Output**: Results formatted and persisted via `TranscriptStore`
5. **Persistence**: Sessions saved to `.port_sessions/*.json` with token usage tracking

Key config:
```python
QueryEngineConfig(
    max_turns=8,
    max_budget_tokens=2000,
    compact_after_turns=12
)
```

---

## The 5 Unreleased Features

### 1. BUDDY — Digital Companion System
**Status**: Fully implemented, 6 modules in `src/buddy/`
**Files**: `CompanionSprite.tsx`, `companion.ts`, `prompt.ts`, `useBuddyNotification.tsx`, `sprites.ts`, `types.ts`
**What it is**: Interactive digital pet/companion with sprite rendering, notifications, and prompting. Gamification layer for persistent user engagement.
**Verdict**: Complete feature, likely held back for product/marketing timing (April Fools per earlier reports).

### 2. BRIDGE Mode — Remote Session Bridging
**Status**: Implemented, 31 modules in `src/bridge/`
**Supports 5 remote execution modes**:
- **Remote control**: Full remote control of local Claude Code
- **SSH mode**: SSH tunneling to remote instances
- **Teleport mode**: Session resume/creation on remote machines
- **Direct connect**: WebSocket connection (server in `src/server/`)
- **Deep link**: URI scheme-based handling

**Key files**: `bridgeApi.ts`, `bridgeConfig.ts`, `bridgeEnabled.ts`, `bridgeMain.ts`, `remoteBridgeCore.ts`, `codeSessionApi.ts`
**Verdict**: Infrastructure for multi-machine Claude Code. This is how they'll do "Claude Code in the cloud."

### 3. MEMDIR — Long-Term Memory System
**Status**: Implemented, 8 modules in `src/memdir/`
**Files**: `memdir.ts`, `findRelevantMemories.ts`, `memoryScan.ts`, `memoryAge.ts`, `memoryTypes.ts`
**What it is**: Persistent memory storage with semantic relevance-based retrieval and age-based filtering. This is what powers the memory system we already use — but the internals show it's more sophisticated than the docs suggest.
**Verdict**: Production feature, already shipped (we use it). The internals confirm relevance scoring and memory scanning.

### 4. VOICE Mode — Speech Interface
**Status**: Implemented, gated by feature flag in `src/voice/voiceModeEnabled.ts`
**What it is**: Speech-to-text input, text-to-speech output.
**Verdict**: Feature-flagged, likely in internal testing.

### 5. COORDINATOR Mode — Multi-Agent Orchestration
**Status**: Implemented, 1 module in `src/coordinator/coordinatorMode.ts`
**What it is**: Coordinates between multiple Claude Code instances (swarm mode). Combined with:
- `agentSwarmsEnabled.ts` feature flag in utils
- `agenticSessionSearch.ts` for multi-agent search
- Built-in agents: `exploreAgent`, `planAgent`, `verificationAgent`, `generalPurposeAgent`, `claudeCodeGuideAgent`, `statuslineSetup`
**Verdict**: This is the foundation for agent swarms. Currently exposed as the Agent tool we use, but the coordinator suggests a higher-level orchestration layer is coming.

### Also Notable: "Capybara" Model Codename
Referenced in search results. Unannounced model family. No details in the source beyond feature flag references.

### Feature Flags Identified
- `VOICE_MODE` — voice input/output
- `BRIDGE_MODE` — remote bridging
- `PROACTIVE` — proactive suggestions
- `KAIROS` — persistent background agent (referenced in search results, not fully confirmed in this mirror)
- Agent swarms enabled/disabled
- Auto mode opt-in
- Fast mode availability
- GrowthBook A/B experiments

---

## Telemetry Details

### Infrastructure
| Component | Purpose |
|-----------|---------|
| **Datadog** (`services/analytics/datadog.ts`) | Primary telemetry sink, event batching |
| **First-party logger** (`firstPartyEventLogger.ts`) | Direct logging to Anthropic servers, bypasses Datadog |
| **GrowthBook** (`growthbook.ts`) | A/B testing, feature flags, experiment tracking |
| **Metadata** (`metadata.ts`) | Session context, environment data |
| **Sink killswitch** (`sinkKillswitch.ts`) | User opt-out mechanism |

### What's Tracked
- Session events and completion
- Command usage (all 207 commands)
- Tool invocations (all 184 tools)
- Agent spawning and interaction patterns
- MCP resource access
- Token consumption (input/output)
- User interaction workflows
- Error/exception events
- Feature flag experiment assignments (GrowthBook)

### Opt-Out
- **Sink killswitch**: Disables all telemetry
- **Trust-gated**: Untrusted sessions collect less
- **Settings-based**: Configurable per user

### Transport
4 concurrent mechanisms:
- `HybridTransport`
- `SSETransport` (Server-Sent Events)
- `WebSocketTransport`
- `SerialBatchEventUploader`

---

## Key Patterns We Can Learn From

### 1. Tool System (184 tools)
- Each tool is a module with: implementation, UI component, prompt definition
- Example structure: `tools/BashTool/BashTool.ts`, `tools/BashTool/UI.tsx`, `tools/BashTool/prompt.ts`
- **Bash security is deep**: `bashPermissions.ts`, `bashSecurity.ts`, `destructiveCommandWarning.ts`, `readOnlyValidation.ts`, `sedEditParser.ts`, `sedValidation.ts`, `pathValidation.ts`, `modeValidation.ts`
- **Takeaway**: Our mesh should validate bash commands at this level. We're currently too permissive.

### 2. Permission Model (3-tier)
1. **Tool-level deny lists**: Exact name or prefix match via `ToolPermissionContext`
2. **Permission denial tracking**: Every blocked operation logged for audit
3. **Trust-gated execution**: Untrusted sessions deny destructive ops

```python
class ToolPermissionContext:
    deny_names: frozenset[str]      # Exact matches
    deny_prefixes: tuple[str, ...]  # Prefix matches
```
**Takeaway**: We should implement trust levels in our mesh — agents from different providers get different permission tiers.

### 3. Coordinator Pattern
- Multi-turn conversation management
- State persistence across turns
- Transcript compaction (keeps last N messages when context fills)
- Token budget tracking with auto-compaction
- **Takeaway**: Their compaction strategy (compact after 12 turns, max 8 turns per query) is a good baseline for our agents.

### 4. Plugin System
- Discovery and registration in `src/plugins/`
- Built-in plugin bundle
- Plugin command integration with namespace isolation
- **Takeaway**: Claude Octopus already builds on this. We should leverage the plugin architecture more.

### 5. Skills System (20 bundled)
- Located in `src/skills/`
- Includes: `batch.ts`, `claudeApi.ts`, `claudeInChrome.ts`, `debug.ts`
- Skills are loaded from directories, first-class citizens alongside plugins
- **Takeaway**: Our superpowers/skills system mirrors this architecture. We're on the right track.

### 6. State Management
- Flux-like store: `AppState.tsx`, `AppStateStore.ts`, `selectors.ts`, `onChangeAppState.ts`
- Session-first: everything is session-bound with explicit persistence
- **Takeaway**: We should persist mesh state per-session, not globally.

### 7. Progressive Trust
- Features gated by trust level
- Untrusted sessions: no plugins, no skills, no MCP, no hooks, reduced telemetry
- Trusted sessions: full initialization
- **Takeaway**: When agents from different providers join our mesh, they should start untrusted and earn capabilities.

### 8. Agent Architecture (built-in agents)
- `exploreAgent` — fast codebase exploration
- `planAgent` — architecture planning
- `verificationAgent` — testing/verification
- `generalPurposeAgent` — general tasks
- `claudeCodeGuideAgent` — help/onboarding
- Each agent is composable, can be spawned from other agents
- **Takeaway**: We already use these. The source confirms they're specialized prompt+tool bundles, not separate models.

---

## What Was NOT Exposed

- Model weights or training data
- API keys or user data
- Backend infrastructure details
- The actual system prompt text (referenced in `src/constants` but this mirror is Python stubs, not full source)

---

## Recommendations for Our Mesh

### Immediate Actions
1. **Adopt the 3-tier permission model** — tool deny lists, denial tracking, trust gating
2. **Implement transcript compaction** — compact after N turns with token budget tracking
3. **Add bash command validation** — destructive command warnings, sed parsing, path validation
4. **Gate features by trust level** — new agents start restricted, earn capabilities

### Architecture Patterns to Port
1. **Session-first state** — all mesh coordination state is session-bound
2. **Token budgeting** — max_turns + max_budget_tokens + compact_after_turns
3. **Multi-transport** — SSE + WebSocket + batch upload for different use cases
4. **Agent composability** — agents that can spawn sub-agents with scoped permissions
5. **Memory scanning with relevance** — `findRelevantMemories.ts` pattern for our MEMDIR

### Watch List
1. **BRIDGE mode** — when this ships, Claude Code gets multi-machine support. We should be ready to integrate.
2. **Coordinator mode** — official agent swarm orchestration. May compete with or complement Claude Octopus.
3. **Voice mode** — speech interface could change how we interact with the mesh.
4. **Capybara model family** — unannounced, watch for it.

### What This Confirms About Our Setup
- Our superpowers/skills architecture mirrors Claude Code's internal skills system. Good.
- Our memory system (MEMDIR) is based on the same pattern they use internally. Good.
- Our multi-agent mesh (Claude Code + Codex + Gemini) is ahead of what Claude Code supports natively — their coordinator mode is still gated. We have a head start.
- Claude Octopus's consensus gate pattern is not something Claude Code does internally — it's additive value we should keep.
