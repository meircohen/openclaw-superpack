# Repo Raid: google-gemini/gemini-cli
- **URL**: https://github.com/google-gemini/gemini-cli
- **Stars**: ~99,665
- **Language**: TypeScript
- **Last updated**: 2026-03-31

## Architecture Overview

Gemini CLI is a monorepo (`packages/`) with these main packages:
- `core` - The engine: tools, agents, config, hooks, scheduler, skills, MCP, policy
- `cli` - Terminal UI layer
- `sdk` - Embeddable SDK
- `a2a-server` - Agent-to-Agent protocol server
- `vscode-ide-companion` - VS Code integration
- `devtools` - Inspector/debugging

The core package follows a **registry-driven architecture** where tools, agents, skills, hooks, and prompts are all managed through dedicated registries that support discovery, precedence layering, and runtime modification. The system is designed for extensibility at every level.

## Key Patterns Found

### Pattern 1: Declarative Tool System (Build/Invoke Separation)

Tools separate **definition** from **execution** via a two-phase pattern: `DeclarativeTool.build(params)` returns a `ToolInvocation` that can then be executed. This cleanly separates validation from side effects.

```typescript
// tools/tools.ts
export abstract class DeclarativeTool<TParams, TResult> implements ToolBuilder<TParams, TResult> {
  constructor(
    readonly name: string,
    readonly displayName: string,
    readonly description: string,
    readonly kind: Kind,          // Read, Edit, Execute, Search, Agent, etc.
    readonly parameterSchema: unknown,
    readonly messageBus: MessageBus,
    readonly isOutputMarkdown: boolean = true,
    readonly canUpdateOutput: boolean = false,
  ) {}

  abstract build(params: TParams): ToolInvocation<TParams, TResult>;
}

// Concrete tools extend BaseDeclarativeTool which auto-validates via JSON schema:
export abstract class BaseDeclarativeTool<TParams, TResult> extends DeclarativeTool<TParams, TResult> {
  build(params: TParams): ToolInvocation<TParams, TResult> {
    const validationError = this.validateToolParams(params);
    if (validationError) throw new Error(validationError);
    return this.createInvocation(params, this.messageBus, this.name, this.displayName);
  }

  protected abstract createInvocation(
    params: TParams,
    messageBus: MessageBus,
    _toolName?: string,
    _toolDisplayName?: string,
  ): ToolInvocation<TParams, TResult>;
}
```

The `Kind` enum classifies tools for permission/policy purposes:
```typescript
export enum Kind {
  Read = 'read', Edit = 'edit', Delete = 'delete', Move = 'move',
  Search = 'search', Execute = 'execute', Think = 'think',
  Agent = 'agent', Fetch = 'fetch', Communicate = 'communicate',
  Plan = 'plan', SwitchMode = 'switch_mode', Other = 'other',
}
```

Every tool automatically gets a `wait_for_previous` parameter injected into its schema, allowing the model to control parallel vs sequential execution:
```typescript
wait_for_previous: {
  type: 'boolean',
  description: 'Set to true to wait for all previously requested tools in this turn to complete before starting.'
}
```

### Pattern 2: Three-Tier Tool Discovery

The `ToolRegistry` manages three distinct tiers of tools, sorted by priority:

1. **Built-in tools** (priority 0) - Hardcoded: shell, read_file, edit, grep, glob, write_file, web_search, web_fetch, memory, ask_user, etc.
2. **Discovered tools** (priority 1) - Found via configurable `toolDiscoveryCommand` that returns JSON `FunctionDeclaration[]`. Called via `toolCallCommand <name>` with params on stdin.
3. **MCP tools** (priority 2) - From MCP servers, grouped by server name.

```typescript
// Discovery flow:
async discoverAllTools(): Promise<void> {
  this.removeDiscoveredTools();
  await this.discoverAndRegisterToolsFromCommand();  // CLI-based discovery
  // MCP tools are registered separately via MCPClientManager
}

// Tool resolution supports legacy aliases:
getTool(name: string): AnyDeclarativeTool | undefined {
  let tool = this.allKnownTools.get(name);
  if (!tool && TOOL_LEGACY_ALIASES[name]) {
    tool = this.allKnownTools.get(TOOL_LEGACY_ALIASES[name]);
  }
  // ...
}
```

Model-specific tool schemas are supported via `getSchema(modelId?)` -- different models can see different parameter schemas for the same tool.

### Pattern 3: Skills as Markdown with YAML Frontmatter

Skills are discovered from `SKILL.md` files with YAML frontmatter for metadata and markdown body for the skill logic/instructions:

```markdown
---
name: my-skill
description: Does something useful
---
# Skill body here
Instructions for the agent when this skill is activated...
```

Discovery follows a **layered precedence** system (highest wins):
1. Workspace skills: `.gemini/skills/` or `.agents/skills/` (project-level)
2. User skills: `~/.gemini/skills/` or `~/.agents/skills/`
3. Extension skills (from installed extensions)
4. Built-in skills (lowest, in `core/src/skills/builtin/`)

```typescript
// skillManager.ts
async discoverSkills(storage: Storage, extensions: GeminiCLIExtension[], isTrusted: boolean): Promise<void> {
  this.clearSkills();
  await this.discoverBuiltinSkills();           // 1. Built-in (lowest)
  for (const ext of extensions) {               // 2. Extensions
    if (ext.isActive && ext.skills) this.addSkillsWithPrecedence(ext.skills);
  }
  this.addSkillsWithPrecedence(await loadSkillsFromDir(Storage.getUserSkillsDir()));        // 3. User
  this.addSkillsWithPrecedence(await loadSkillsFromDir(storage.getProjectSkillsDir()));     // 4. Workspace (highest)
}
```

Skills are **activated** via an `activate_skill` tool call -- the model decides when to invoke a skill. Active skills inject their body as system context.

### Pattern 4: Agent Definitions (Local + Remote via A2A)

Agents are defined as markdown files with frontmatter (same pattern as skills), loaded from `~/.gemini/agents/` and `.gemini/agents/`:

```yaml
# Local agent frontmatter:
---
kind: local
name: my-agent
description: Does something
tools: [shell, read_file, grep]
model: gemini-2.5-pro
max_turns: 30
timeout_mins: 10
mcp_servers:
  my-server:
    command: node
    args: [server.js]
---
System prompt goes here as the markdown body.
Supports ${query} templating.
```

```yaml
# Remote agent (A2A protocol):
---
kind: remote
name: external-agent
description: External capability
agent_card_url: https://example.com/.well-known/agent.json
auth:
  type: http
  scheme: Bearer
  token: ${MY_TOKEN}
---
```

The `AgentRegistry` handles:
- Built-in agents (CodebaseInvestigator, CliHelp, Generalist, Browser, MemoryManager)
- User-level agents from `~/.gemini/agents/`
- Project-level agents from `.gemini/agents/` (with trust/acknowledgement)
- Extension-contributed agents
- Remote A2A agents with full auth support (apiKey, http, OAuth2, google-credentials)

Agents are exposed to the model as tools via `SubagentTool`, which wraps an `AgentDefinition` and presents it with the agent's `inputSchema` as the tool parameters.

### Pattern 5: Extension System

Extensions are first-class packages that can contribute nearly everything:

```typescript
export interface GeminiCLIExtension {
  name: string;
  version: string;
  isActive: boolean;
  path: string;
  mcpServers?: Record<string, MCPServerConfig>;    // MCP server configs
  contextFiles: string[];                           // Extra context files
  excludeTools?: string[];                          // Tools to disable
  hooks?: { [K in HookEventName]?: HookDefinition[] };  // Lifecycle hooks
  settings?: ExtensionSetting[];                    // Configurable settings
  skills?: SkillDefinition[];                       // Skills
  agents?: AgentDefinition[];                       // Agents
  themes?: CustomTheme[];                           // UI themes
  rules?: PolicyRule[];                             // Policy rules
  checkers?: SafetyCheckerRule[];                   // Safety checkers
  plan?: { directory?: string };                    // Planning config
}
```

Extensions have integrity verification (see `config/extensions/integrity.ts`), can be migrated between repos via `migratedTo`, and support custom environment variable settings.

### Pattern 6: Hook System (Event-Driven Lifecycle)

A comprehensive hook system with typed events at every lifecycle point:

```typescript
export enum HookEventName {
  BeforeTool, AfterTool,
  BeforeAgent, AfterAgent,
  SessionStart, SessionEnd,
  PreCompress,
  BeforeModel, AfterModel,
  BeforeToolSelection,
  Notification,
}
```

Hooks can be either **command** (spawn a subprocess) or **runtime** (in-process function):

```typescript
// Command hook (from settings.json or extensions):
{ type: 'command', command: 'python3 my-hook.py', timeout: 5000 }

// Runtime hook (registered programmatically):
{ type: 'runtime', name: 'my-hook', action: async (input) => ({ decision: 'allow' }) }
```

Hook outputs support powerful control flow:
- `decision`: 'allow' | 'deny' | 'block' | 'ask' -- control tool/model execution
- `continue: false` -- stop the entire execution
- `systemMessage` -- inject text into the conversation
- `hookSpecificOutput.llm_request` / `llm_response` -- modify or replace model calls
- `hookSpecificOutput.tool_input` -- modify tool parameters before execution
- `hookSpecificOutput.tailToolCallRequest` -- chain another tool call after completion

The hook system is decomposed into focused components:
- `HookRegistry` - Stores and manages hook registrations
- `HookPlanner` - Creates execution plans from registered hooks
- `HookRunner` - Executes individual hooks
- `HookAggregator` - Merges results from multiple hooks
- `HookEventHandler` - Orchestrates the full event lifecycle

### Pattern 7: Policy Engine with TOML Rules

A priority-based policy engine controls tool execution permissions:

```typescript
interface PolicyRule {
  toolName: string;
  decision: PolicyDecision;  // ALLOW | ASK_USER | DENY
  priority: number;
  source: string;            // Where the rule came from
  modes?: ApprovalMode[];    // Only apply in certain modes
  argsPattern?: string;      // Match specific arguments
  subagent?: string;         // Scope to specific agent
}
```

Policies are loaded from TOML files at multiple tiers (admin, user, workspace, auto-saved). The engine supports wildcards (`*`, `mcp_servername_*`) and MCP tool-specific matching.

Agents get dynamic policy rules registered automatically -- local agents get `ALLOW`, remote agents get `ASK_USER`.

### Pattern 8: Event-Driven Tool Scheduler

The `Scheduler` is an event-driven orchestrator that handles tool execution with:
- Parallel execution (respecting `wait_for_previous`)
- Policy checks before execution
- Hook firing (BeforeTool/AfterTool)
- User confirmation flow via MessageBus
- Tool modification (hooks can alter tool params)
- Telemetry/tracing per tool call

```typescript
// scheduler/types.ts - Tool call lifecycle states:
type CoreToolCallStatus =
  | 'SCHEDULED'    // Queued
  | 'VALIDATING'   // Policy + hooks running
  | 'CONFIRMING'   // Waiting for user
  | 'EXECUTING'    // Running
  | 'COMPLETED'    // Done (success or error)
```

### Pattern 9: MessageBus for Decoupled Communication

A pub/sub `MessageBus` decouples the core engine from the UI layer:

```typescript
// Tools publish confirmation requests:
messageBus.publish({ type: 'TOOL_CONFIRMATION_REQUEST', correlationId, toolCall: { name, args } });

// UI subscribes and responds:
messageBus.subscribe('TOOL_CONFIRMATION_RESPONSE', (response) => { ... });

// Policy updates flow through the bus:
messageBus.publish({ type: 'UPDATE_POLICY', toolName, persist: true });
```

### Pattern 10: Hierarchical Configuration

Configuration follows a merge hierarchy:
1. **Admin controls** (from code_assist server) -- highest authority
2. **CLI flags** (`--yolo`, `--model`, etc.)
3. **Project settings** (`.gemini/settings.json`)
4. **User settings** (`~/.gemini/settings.json`)
5. **Default values** -- lowest

Settings cover: MCP servers, policy paths, approval modes, model selection, sandbox config, tool exclusions, telemetry, extensions, hooks, agents, context management, and more.

The `ModelConfigService` adds another layer of model-specific config with overrides per agent/scope:
```typescript
// Agents can inherit, override, or specify their own model:
modelConfig: {
  model: 'inherit',  // Use the user's selected model
  generateContentConfig: { temperature: 1, topP: 0.95 },
}
```

### Pattern 11: Sandbox and Safety

A `SandboxManager` wraps all external command execution (shell, tool discovery, MCP servers) with configurable sandboxing. Commands are prepared through the sandbox before spawning:

```typescript
const prepared = await sandboxManager.prepareCommand({
  command, args, cwd, env
});
// prepared.program / prepared.args / prepared.env are sandbox-wrapped
```

A separate `CheckerRunner` / `CheckerRegistry` system runs safety checks on tool calls, with checkers contributed by extensions or built-in (e.g., `ConsecaSafetyChecker`).

## Actionable Takeaways for AI Agent Mesh

1. **Adopt the Build/Invoke pattern for tools.** Separating `build(params) -> Invocation` from `execute()` gives clean validation, confirmation, and testing boundaries. Every tool invocation becomes a first-class object with its own lifecycle.

2. **Use YAML-frontmatter markdown for agent/skill definitions.** Gemini CLI's approach of defining agents and skills as `.md` files with YAML frontmatter is extremely developer-friendly. The body is the system prompt or skill instructions. This is directly applicable to our skill system.

3. **Implement layered precedence for all registries.** The pattern of builtin < extension < user < workspace for skills, agents, hooks, and config is well-proven. Higher layers override lower ones by name. This prevents conflicts while allowing customization.

4. **Expose agents as tools (SubagentTool pattern).** Wrapping agent definitions as callable tools with input schemas lets the parent model naturally delegate to sub-agents. The model decides when to invoke which agent based on the tool description and schema.

5. **Hook system with typed events at every lifecycle point.** The comprehensive hook system (BeforeTool, AfterTool, BeforeModel, AfterModel, etc.) with both command and runtime hooks enables powerful extensibility. The ability to modify tool inputs, block execution, or inject synthetic responses is especially valuable.

6. **Policy engine with priority-based rules.** A centralized policy engine that evaluates tool calls against prioritized rules (with wildcards, mode-specific rules, and agent-scoped rules) provides fine-grained control. Auto-saved policies from user "always allow" decisions persist to TOML files.

7. **MessageBus for UI decoupling.** The pub/sub message bus pattern cleanly separates tool execution from user interaction. Confirmation flows, policy updates, and progress reporting all go through the bus, making the core engine UI-agnostic.

8. **Model-specific tool schemas.** The `getSchema(modelId?)` pattern allows different models to see different tool parameter schemas. This is useful when models have different capabilities or schema requirements.

9. **MCP tool naming convention.** The `mcp_{serverName}_{toolName}` convention with helper functions for parsing/formatting provides clean namespacing for MCP tools. Wildcard patterns (`mcp_*`, `mcp_server_*`) enable server-level policy rules.

10. **A2A protocol for remote agents.** Supporting both local (in-process) and remote (A2A protocol) agents through the same `AgentDefinition` interface, with auth configuration and agent card discovery, is a forward-looking pattern for multi-agent systems.

11. **Trust boundaries for project-level content.** Project-level agents require acknowledgement (hash-based verification) before activation. Workspace skills are disabled in untrusted folders. This is critical for any system that loads executable content from repositories.

12. **Parallel tool execution with dependency control.** The `wait_for_previous` parameter, injected into every tool schema, lets the model explicitly control parallelism. The scheduler handles the orchestration, allowing safe parallel reads with sequential mutations.
