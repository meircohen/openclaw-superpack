# FastMCP Raid

Audit date: 2026-03-31

## Bottom line

**FastMCP is real, mature, and worth adopting for custom Python MCP servers.**

It is **not** a replacement for our mesh. It is a better implementation layer for MCP servers than our current mix of file-based proxying, ad hoc config wiring, and bespoke scripts.

My recommendation: **use it selectively, do not rewrite the mesh around it**.

## What FastMCP actually is

FastMCP is a Python framework that wraps MCP protocol plumbing in a high-level server/client API.

Core shape:

- `FastMCP("Server Name")` creates the server
- `@mcp.tool`, `@mcp.resource`, and `@mcp.prompt` register components
- type hints + docstrings become schemas and descriptions
- `mcp.run()` handles transport startup
- the same framework supports stdio and remote HTTP-style deployment

This is a real abstraction layer, not just docs sugar.

## Architecture

### 1. High-level server object over a real MCP stack

- `src/fastmcp/server/server.py` shows `FastMCP` built on top of:
  - `mcp.types`
  - auth/context abstractions
  - providers
  - middleware
  - transports
  - lifecycle support

This is a real framework, not a toy wrapper.

### 2. Decorator-first component model

The main developer experience is:

- `@mcp.tool`
- `@mcp.resource("uri://...")`
- `@mcp.prompt`

That matters because it removes most MCP boilerplate:
- JSON-RPC handling
- schema generation
- registration
- transport glue

### 3. Provider system

This is one of the strongest parts of the architecture.

Two especially relevant providers:

- `FileSystemProvider`
  - scans Python files
  - auto-registers `@tool`, `@resource`, `@prompt`
  - gives a file-based organization model without manual imports
- Proxy Provider / `create_proxy()`
  - exposes components from other MCP servers
  - bridges transports
  - handles session isolation
  - forwards protocol features like sampling, logging, progress, roots

That means FastMCP is not just for single servers. It has a real composition story.

### 4. Deployment and config story

FastMCP has a credible production path:

- stdio for local clients
- HTTP / Streamable HTTP / SSE for remote use
- ASGI integration
- `fastmcp.json` for declarative config
- CLI-driven run/install/inspect flows

This is much stronger than "write a JSON-RPC loop yourself and hope it stays compliant."

### 5. Maturity signals

The maturity signals are strong:

- docs are detailed and current
- pyproject has a substantial dependency and optional-feature surface
- real CLI entrypoint
- explicit test configuration and dev tooling
- auth, deployment, proxying, transports, and clients are all first-class

This looks like a serious framework.

## How it compares to what we have

## Our current state

Today our MCP setup is mostly:

- mesh/file bus orchestration via `openclaw-mesh-starter/docs/ARCHITECTURE.md`
- lightweight read-only proxying via `shared/MCP-PROXY.md`
- per-client MCP wiring via scripts like `scripts/setup-perplexity.sh`
- capability/routing docs in `shared/TOOLS.md`, `shared/ROUTING.md`, and `mesh/README.md`

That means:

- we are good at cross-agent routing, handoffs, cost rules, and filesystem coordination
- we do **not** have a clean reusable framework for building custom MCP servers in Python

## The actual comparison

FastMCP solves a different problem than the mesh.

Our mesh solves:
- agent routing
- handoffs
- async coordination
- cost policy
- system boundaries

FastMCP solves:
- MCP protocol implementation
- tool/resource/prompt registration
- transport handling
- remote deployment
- server composition/proxying

So the right comparison is not "FastMCP vs our mesh."

The right comparison is:

- FastMCP vs hand-rolled custom MCP servers
- FastMCP vs more ad hoc proxy/config scripts

On that comparison, FastMCP wins.

## Is it worth switching to for custom MCP servers?

## Yes, for new Python MCP servers

If we want to build custom MCP servers for internal tools, memory views, routing introspection, document services, or read-only operational surfaces, FastMCP is a better base than bespoke code.

Why:

- less protocol boilerplate
- faster iteration
- better schema generation
- better transport story
- better remote deployment story
- better server composition story

## No, for mesh orchestration itself

Do not try to replace:

- `shared/` as the inter-system bus
- handoff lifecycle
- heartbeat / dispatch loop
- routing and escalation logic

FastMCP is not an orchestration bus. It is an MCP server framework.

## The practical recommendation

Use a hybrid:

- keep the current mesh architecture for multi-agent coordination
- use FastMCP anywhere we need a real Python MCP surface

That gives us:

- mesh-level autonomy and cost routing
- proper MCP ergonomics for custom services

## What we should build with it first

Best first candidates:

- a read-only `mesh-status` server
  - active handoffs
  - recent replies
  - routing suggestions
  - health snapshots
- a `memory-bridge` server
  - expose curated memory blocks/resources cleanly
- an `ops-tools` server
  - bounded internal tools with proper schemas
- a proxy/bridge server
  - wrap selected existing MCP services behind one controlled endpoint

## Should we switch wholesale?

No.

### Switch for

- new Python MCP servers
- any server that needs HTTP deployment
- any server that benefits from resources/prompts/providers/proxying

### Do not switch for

- the shared filesystem bus
- cross-agent dispatch
- simple one-off config wiring where no real custom server is needed

## Final verdict

**Worth adopting, not worth rewriting around.**

For custom Python MCP servers, FastMCP is materially better than what we have today. For mesh orchestration, it is complementary, not substitutive.

## Sources

- https://github.com/jlowin/fastmcp
- https://raw.githubusercontent.com/jlowin/fastmcp/main/pyproject.toml
- https://raw.githubusercontent.com/jlowin/fastmcp/main/src/fastmcp/server/server.py
- https://gofastmcp.com/v2/getting-started/welcome
- https://gofastmcp.com/getting-started/quickstart
- https://gofastmcp.com/tutorials/create-mcp-server
- https://gofastmcp.com/servers/resources
- https://gofastmcp.com/servers/providers/filesystem
- https://gofastmcp.com/servers/providers/proxy
- https://gofastmcp.com/deployment/server-configuration
- https://gofastmcp.com/deployment/http

## Local comparison files

- `openclaw-mesh-starter/docs/ARCHITECTURE.md`
- `shared/MCP-PROXY.md`
- `shared/TOOLS.md`
- `shared/ROUTING.md`
- `mesh/README.md`
- `scripts/setup-perplexity.sh`
