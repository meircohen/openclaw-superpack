# Repo Raid: coast-guard/coasts

**Repo**: https://github.com/coast-guard/coasts
**Type**: Containerized runtime isolation for parallel dev environments
**Language**: Rust (backend) + React/TypeScript (UI)
**License**: MIT
**Audited**: 2026-03-31

---

## What It Does

Coasts (Containerized Hosts) runs **N isolated development environments on a single machine**, each mapped to a Git worktree. Each instance gets its own ports, volumes, containers, and secrets while sharing the codebase via bind mounts. Built specifically for AI agent workflows — no vendor lock-in, fully offline.

---

## Architecture

```
coast-cli/         → Thin CLI client (clap, JSON-RPC over Unix socket)
coast-daemon/      → Background daemon (async Tokio, Axum HTTP/WS server)
                     SQLite state DB, port manager, API handlers
coast-core/        → Shared types, Coastfile parsing, protocol definitions
                     ts-rs for TypeScript generation
coast-docker/      → Docker runtime abstractions (DinD, Sysbox, Podman)
coast-secrets/     → Secret extraction, encryption, keystore management
coast-guard/       → React 19 + Vite web UI dashboard
coast-i18n/        → Localization
coast-update/      → Auto-update mechanism
```

### Data Flow
```
CLI → Unix socket → Daemon → Handler → StateDb (SQLite)
                                      → Runtime (Docker API via Bollard)
                                        → DinD container → Inner compose stack
                                          → User services (app, db, cache)
```

### Key Design Decisions
- **Unix domain sockets** for CLI-daemon IPC (no network exposure)
- **SQLite WAL** for state (embedded, zero-setup, ACID)
- **socat** for port forwarding (minimal, signal-based restarts)
- **DinD default** with Sysbox/Podman alternatives
- **TOML Coastfile** — works alongside existing docker-compose.yml
- **ts-rs** generates TypeScript types from Rust structs (single source of truth)

---

## Isolation Model

### Container Isolation
- **DinD (default)**: Each instance = one `docker:dind` container with `--privileged`. Inner Docker daemon runs user's compose stack unmodified. Full cgroup/namespace isolation.
- **Sysbox**: Unprivileged alternative, lighter weight, same interface.
- **Podman**: Drop-in alternative for Docker-free setups.

### Network Isolation
- Each instance creates its own Docker network
- Services across instances cannot communicate directly
- Port forwarding via socat:
  - **Canonical ports** (e.g., 8000, 5432): Forwarded to currently-checked-out instance only
  - **Dynamic ports** (49152-65535): Always active for every instance
  - **Checkout = instant**: Kill old socat, spawn new one. No container restart. <100ms.

### Filesystem Isolation
- Project root: bind-mounted R/W to all instances (shared code)
- `private_paths`: per-instance isolated copies (e.g., node_modules per branch)
- Named volumes: per-instance (e.g., `{project}--{instance}--postgres-data`)
- Database state never leaks between instances

### Secret Isolation
- Per-instance encrypted keystores
- Injected via tmpfs (in-memory, never on disk)
- macOS Keychain integration optional
- Custom secret extractors

---

## Observability UI (Coast Guard)

### Tech Stack
React 19 + Vite + Tailwind CSS 4 + Monaco Editor + xterm.js + D3

### Dashboard Pages
| Page | Shows |
|------|-------|
| **Projects** | All projects with instance counts, build status |
| **Instance Detail** | Tabbed: Logs, Ports, Services, Stats, Files, Secrets, Volumes, Exec, MCP |
| **Service Detail** | Per-service logs, stats, config, exec terminal |
| **Build Detail** | Artifacts, versions, coastfile, manifest |
| **Docs** | Markdown viewer with semantic search |

### Real-Time Streaming (WebSocket)
- `/ws/logs` — instance log stream
- `/ws/stats` — CPU/memory metrics
- `/ws/exec` — terminal I/O (xterm)
- `/ws/service-exec` — per-service terminal
- `/ws/service-stats` — per-service metrics
- `/ws/lsp` — LSP protocol forwarding for editor support

### Telemetry
- Opt-in only via `/set_analytics`
- Tracks command frequency, session duration, system info
- No personal data. Disabled via `coast config`.

---

## How This Improves Our Multi-Agent Mesh

### The Problem We Have
When Claude Code + Codex + Gemini run in parallel on the same machine:
- Port conflicts (all want 8000, 5432)
- Shared database mutations interfere
- No unified view of what each agent's environment is doing
- Build processes compete for resources
- Secret duplication across agents

### What Coasts Solves

#### 1. Per-Agent Runtime Isolation
```
Project: our-app
├── Claude Code (main)     → Coast "claude"  → Ports 8000-8010, own DB
├── Codex (feature/auth)   → Coast "codex"   → Ports 8100-8110, own DB
└── Gemini (feature/perf)  → Coast "gemini"  → Ports 8200-8210, own DB
```
Each agent gets dedicated containers, port allocations, volume state, secret overrides.

#### 2. Instant Context Switching (<100ms)
`coast checkout claude` — kills socat for codex's canonical ports, spawns for claude's. No container restart.

#### 3. Unified Observability
Coast Guard shows all 3 agents' environments in one dashboard:
- Real-time logs from each agent's services
- Port status, instance health (CPU/memory)
- Which agent is active on canonical ports

#### 4. Shared Services Save Resources
```toml
[shared_services.db]
image = "postgres:15"
ports = [5432]
```
Single Postgres, all agents connect. Saves ~2GB RAM per agent.

#### 5. MCP Server Hub
Define tools once on host, expose to all agent instances:
```toml
[mcp_servers.file_tools]
proxy = "host"
command = "npx"
args = ["@anthropic-ai/mcp-server-files"]
```
Tools run once, all agents see the same interface. No duplication.

#### 6. Worktree Auto-Discovery
`coast lookup` resolves current worktree → instance name, ports, example commands. Agents don't hardcode anything.

#### 7. Coordinated Build Caching
Build once → all instances reuse cached layers. Hours saved across 3 agents.

### Performance
| Operation | Time |
|-----------|------|
| `coast run` (cold) | 10-30s |
| `coast run` (cached) | 3-5s |
| `coast checkout` | <100ms |
| Daemon memory | ~50MB |
| Instance overhead | 200MB-2GB (depends on services) |

### Agent Support Matrix
| Agent | Status | Notes |
|-------|--------|-------|
| Claude Code | Full | Native MCP client support, CLAUDE.md integration |
| Cursor | Full | AGENTS.md + skills |
| Codex | Full | OpenAI-specific, no MCP yet |
| Gemini | Partial | CLI works, no native harness integration |

---

## Recommended Actions

### Immediate
1. **Install Coasts** for our mesh: `eval "$(curl -fsSL https://coasts.dev/install)"`
2. **Write a Coastfile** for our primary project — define ports, shared services, private paths
3. **Spin up 3 instances** — one per agent (Claude Code, Codex, Gemini)
4. **Use Coast Guard** as the unified dashboard for all agent environments

### Architecture Patterns to Adopt
1. **socat-based port forwarding** — lightweight, instant switching, process-per-port
2. **SQLite WAL for state** — embedded, zero-setup, handles concurrent access
3. **Unix socket IPC** — no network exposure, automatic cleanup
4. **DinD for isolation** — each agent gets a full Docker daemon, zero interference
5. **Shared services** for expensive infrastructure (databases, caches)
6. **ts-rs type generation** — if we build any Rust+TS tooling, single source of truth

### What NOT to Copy
- The `--privileged` DinD default (use Sysbox where possible for tighter security)
- Building a full web UI for observability before the core orchestration is solid
