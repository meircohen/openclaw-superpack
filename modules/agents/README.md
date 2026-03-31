# OpenClaw Agents Module

## Overview

This module contains the personality and identity definitions for 55 agents in the OpenClaw system. Each agent is a specialized persona designed to handle a specific domain of work, from software engineering to personal finance to creative writing.

## Structure

Each agent lives in its own directory named by slug (e.g., `backend-architect/`) and contains two files:

### SOUL.md
The agent's core personality and values. This defines *who* the agent is:
- **Core Identity** - Who this agent is in 2-3 sentences
- **Values** - The principles that guide every decision
- **Communication Style** - How the agent speaks and interacts
- **Decision Framework** - How the agent approaches choices and tradeoffs

### IDENTITY.md
The agent's role and operational boundaries. This defines *what* the agent does:
- **Role** - One-sentence role definition
- **Capabilities** - What the agent can do
- **Tools & Integrations** - What tools the agent uses
- **Boundaries** - What the agent should NOT do
- **Reporting** - Who the agent reports to and collaborates with

## Template Variables

Files use `{{USER_NAME}}` as a placeholder for the user's name, to be substituted at deployment time.

## Agent Categories

| Category | Agents |
|----------|--------|
| **Engineering** | backend-architect, code-architect, code-reviewer, codex, claude-code, design-engineer, devops-engineer, frontend-developer, infra-engineer, mobile-app-builder, rapid-prototyper |
| **Quality & Testing** | api-tester, performance-tester, qa-engineer, security-auditor |
| **Leadership & Management** | ceo, cfo, engineering-manager, ops-manager, product-manager, release-captain, team-lead |
| **Research & Analysis** | ai-expert, analytics-reporter, data-analyst, perplexity, prediction-markets-expert, researcher, strategist |
| **Creative & Content** | content-creator, image-creator, marketing-creative, social-media-manager, technical-writer, writer |
| **Finance & Trading** | crypto-trader, money-coach, stock-trader |
| **Personal & Lifestyle** | accountability-coach, chef, executive-assistant, fitness-coach, personal-shopper, study-buddy, travel-planner, wellness-guide |
| **Specialized** | growth-hacker, legal-advisor, prompt-engineer, retro-facilitator, the-contrarian, the-innovation-bull, translator, ux-designer, ux-researcher |

## Design Principles

1. **Distinct personalities** - Each agent has a unique voice and perspective appropriate to their domain
2. **Clear boundaries** - Every agent knows what it should NOT do and who to defer to
3. **Collaboration-aware** - Agents know which other agents they work with
4. **No personal data** - Templates contain no user-specific information
5. **Professional with character** - Agents are professional but not generic; each has a perspective and point of view

## Usage

These files are intended to be loaded as system context when activating an agent. The SOUL.md shapes the agent's personality and the IDENTITY.md constrains its operational scope.

See `ROSTER.md` for a quick reference of all 55 agents with one-line descriptions.
