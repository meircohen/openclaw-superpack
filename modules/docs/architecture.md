# Architecture Overview

This document describes the high-level architecture of the OpenClaw system -- a multi-LLM orchestration platform that combines intelligent routing, specialized agents, and automated intelligence gathering into a cohesive development environment.

## System Layers

```
+--------------------------------------------------+
|                  Claude Code CLI                  |
|           (primary interaction layer)             |
+--------------------------------------------------+
|          MCP Servers  |  Skills / Superpowers     |
+--------------------------------------------------+
|    Mesh System    |   Agent System   | Delegation |
|  (LLM routing)   | (55 specialists) |  (voice +  |
|                   |                  |  templates) |
+--------------------------------------------------+
|          Intelligence Pipeline                    |
|   (collect -> filter -> digest -> act -> trends)  |
+--------------------------------------------------+
|          Heartbeat System                         |
|   (runtime ops, health checks, scheduling)        |
+--------------------------------------------------+
```

## Mesh System

The mesh is a multi-LLM routing layer that dispatches requests to the optimal provider based on task characteristics.

**Core responsibilities:**
- Route requests across LLM providers (Claude, GPT, Gemini, local models)
- Optimize for cost, latency, and quality based on task type
- Monitor provider health and availability
- Learn from routing outcomes to improve future decisions

**Key components:**
- `router.py` -- Decision engine that selects the best provider for each request
- `health_monitor.py` -- Tracks provider uptime, latency, and error rates
- `cost_tracker.py` -- Monitors spend across providers, enforces budgets
- `learning.py` -- Feedback loop that improves routing based on outcomes
- `mcp_server.py` -- MCP interface exposing mesh capabilities to Claude Code

**Routing factors:**
- Task complexity and type (coding, analysis, creative, factual)
- Provider cost per token
- Current provider health and latency
- Historical success rate for similar tasks
- Budget constraints and daily spend limits

## Intelligence Pipeline

An automated pipeline that collects, processes, and surfaces relevant information.

**Pipeline stages:**

1. **Collect** -- Gather raw data from configured sources (RSS feeds, API endpoints, repositories, services)
2. **Filter** -- Apply relevance scoring and deduplication to reduce noise
3. **Digest** -- Summarize and structure filtered information into actionable briefings
4. **Act** -- Route digested intelligence to the appropriate agent or queue for action
5. **Trends** -- Track patterns over time, surface emerging themes and anomalies

**Output artifacts:**
- Daily digest documents with prioritized items
- Trend reports highlighting changes over time
- Actionable items routed to the work queue
- Alerts for time-sensitive information

## Agent System

A collection of 55 specialized agents, each defined by two core files:

- **SOUL.md** -- The agent's purpose, personality, expertise domain, and behavioral guidelines. Defines *what* the agent is and *how* it thinks.
- **IDENTITY.md** -- The agent's name, role title, and operational parameters. Defines *who* the agent is within the system.

**Agent categories:**
- **Development** -- Code generation, review, testing, debugging, refactoring
- **Operations** -- Deployment, monitoring, infrastructure, CI/CD
- **Research** -- Information gathering, analysis, competitive intelligence
- **Communication** -- Writing, editing, translation, summarization
- **Coordination** -- Task routing, project management, scheduling

**Collaboration patterns:**
- Agents can delegate subtasks to other agents
- Chain-of-agents workflows for multi-step processes
- Parallel dispatch for independent subtasks
- Escalation paths when an agent hits its expertise boundary

## Delegation Layer

Controls how work is assigned and how agents communicate.

**Components:**
- **Templates** -- Structured formats for common delegation patterns (code review, research request, draft review)
- **Voice guides** -- Tone and style parameters that ensure consistent communication across agents
- **Verification** -- Post-completion checks that validate delegated work meets requirements before acceptance

**Delegation flow:**
1. Task arrives (from user, queue, or another agent)
2. Template selected based on task type
3. Appropriate agent(s) identified
4. Work dispatched with context and constraints
5. Results verified against acceptance criteria
6. Output delivered or escalated

## Heartbeat System

The runtime operations layer that keeps everything running.

**Responsibilities:**
- Scheduled health checks across all system components
- Nightly backup execution (3 AM cron, 7-day rotation)
- Log rotation and cleanup
- System status aggregation (MESH-STATUS.md)
- Cron job management for recurring tasks
- Disaster recovery preparation

**Health checks:**
- LLM provider connectivity and response times
- MCP server availability
- Disk space and resource utilization
- Configuration integrity
- Backup freshness

## MCP Server Integration

MCP (Model Context Protocol) servers extend Claude Code's capabilities by providing additional tools and data sources.

**Integrated servers:**
- **context-mode** -- Semantic code search and navigation
- **context7** -- Library and framework documentation lookup
- **claude-peers** -- Multi-instance coordination
- **ai-mesh** -- Mesh system interface
- **perplexity** -- Web search and research

Each server runs as an independent process, communicating with Claude Code through the MCP protocol. Configuration templates are maintained in the `mcp-servers` module.

## Data Flow

```
User Request
    |
    v
Claude Code (with MCP servers)
    |
    v
Mesh Router --> selects optimal LLM provider
    |
    v
Agent System --> specialist handles the task
    |
    v
Delegation Layer --> subtasks dispatched if needed
    |
    v
Verification --> results validated
    |
    v
Response delivered to user
```

The intelligence pipeline runs independently on a schedule, feeding processed information into the work queue where agents can pick it up during normal operations.
