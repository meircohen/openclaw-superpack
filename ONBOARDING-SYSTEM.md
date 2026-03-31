# Progressive Onboarding System

## The Problem
The superpack has 55 agents, a mesh network, an intelligence pipeline, delegation layer, MCP servers, heartbeat system, and more. If we dump all of this on a new user at install time, they'll be overwhelmed and won't use 90% of it.

## The Solution: AI-Native Progressive Onboarding

OpenClaw itself teaches the user about features over time, in context, when it's relevant.

## Three Learning Modes

### 1. Welcome Tour (Day 1)
After install, OpenClaw introduces itself with ONLY the top 3 capabilities:
- "I'm now running with an upgraded setup. Here are the 3 biggest things I can do for you:"
  1. **I have 55 specialist agents** -- ask me anything and I'll route to the right expert
  2. **I monitor the AI ecosystem** -- I'll alert you when something important happens
  3. **I run autonomously** -- I do maintenance, health checks, and monitoring while you sleep
- "There's a LOT more. I'll show you features as they become relevant. Or say 'teach me' anytime."

### 2. Daily Feature Discovery (Days 2-30)
Each day, during natural conversation, OpenClaw introduces ONE new feature.

Trigger: First conversation of the day, after handling the user's request.
Format: Brief, casual, not pushy.

Example sequence:
- Day 2: "By the way -- I can delegate heavy coding work to Claude Code or Codex on your subscription so I stay lean. Want me to explain how that works?"
- Day 3: "Quick tip: I have a built-in intelligence pipeline that scans HN, GitHub, Reddit, Bluesky, and more. Want me to run a sweep now?"
- Day 4: "Did you know I can set up reminders, track tasks, and manage deadlines? Just tell me naturally."
- Day 5: "I can post to X/Twitter for you, manage engagement, and queue content. Want to connect your account?"
- Day 7: "I run a heartbeat system every 30 minutes -- checking system health, processing handoffs, and maintaining memory. It's already running."
- Day 10: "I have specialist agents for investing, fitness, cooking, travel, legal advice, and more. Ask me anything and I'll route to the right one."
- Day 14: "The mesh network routes tasks to the cheapest system automatically. Subscription tools first, API tokens last. Want to see your cost breakdown?"
- Day 21: "I can learn your preferences over time and adapt. The more we talk, the better I get at anticipating what you need."
- Day 30: "You've been using the superpack for a month. Want a summary of everything I've done for you?"

Storage: Track which features have been introduced in memory/onboarding-progress.json
```json
{
  "installed_at": "2026-03-31T00:00:00Z",
  "features_introduced": [
    {"feature": "specialist_agents", "date": "2026-03-31", "user_engaged": true},
    {"feature": "intelligence_pipeline", "date": "2026-04-02", "user_engaged": false}
  ],
  "features_remaining": ["delegation", "mesh_cost", "x_posting", ...],
  "user_pace": "normal"  // slow, normal, fast -- adapts based on engagement
}
```

### 3. Contextual Discovery (Ongoing, forever)
When the user does something that a superpack feature handles better, OpenClaw mentions it.

Examples:
- User manually searches for news → "I have an intelligence pipeline that does this automatically every 6 hours. Want me to set it up?"
- User asks about system status → "I run health checks every 30 minutes via the heartbeat system. Here's the latest."
- User writes a long document → "I could route this to Gemini's 1M context window for review -- it's on the free tier."
- User asks about coding → "Want me to dispatch this to Claude Code? It's on your subscription, $0 cost."
- User creates a reminder → "I track all your reminders, tasks, and deadlines in the Today view. Want to see what's active?"

### 4. "Teach Me" Command
At any time, the user can say "teach me" or "what else can you do?" and OpenClaw will:
1. Show a brief overview of un-introduced features
2. Let them pick which ones to learn about
3. Give a 2-3 sentence explanation + live demo

### 5. Weekly Digest (Optional)
If enabled, once a week OpenClaw sends a "This Week in Your AI Setup" summary:
- Features you used this week
- Features you haven't tried yet (with one-line descriptions)
- Suggestions based on your usage patterns
- New features added via superpack update

## Implementation

### File: onboarding/onboarding.md
OpenClaw reads this file on every session start. It contains:
- Current onboarding state
- Which features to introduce next
- Contextual trigger conditions
- "Teach me" response templates

### File: onboarding/features.json
Master list of all superpack features with:
```json
[
  {
    "id": "mesh_network",
    "name": "AI Mesh Network",
    "category": "infrastructure",
    "one_liner": "Routes tasks to the cheapest AI system automatically",
    "full_description": "...",
    "day_to_introduce": 14,
    "contextual_triggers": ["cost", "expensive", "tokens", "billing", "which model"],
    "requires": ["claude_code OR codex OR gemini"],
    "demo_command": "python3 mesh/health.py"
  }
]
```

### File: onboarding/progress.json
Per-user progress tracking (generated on install, updated by OpenClaw):
```json
{
  "user_name": "{{USER_NAME}}",
  "installed_at": "...",
  "onboarding_day": 5,
  "pace": "normal",
  "features_introduced": [...],
  "features_engaged": [...],
  "features_skipped": [...],
  "next_feature": "delegation_layer",
  "weekly_digest_enabled": false
}
```

## Key Principles

1. **Never overwhelm** -- one feature at a time, in context
2. **Respect attention** -- if user is busy or focused, don't interrupt with teaching
3. **Adapt pace** -- if user engages with every feature, speed up. If they skip, slow down.
4. **Always useful first** -- handle the user's actual request BEFORE mentioning new features
5. **Never repeat** -- once introduced, don't bring it up again unless contextually relevant
6. **Living system** -- as we add features via git pull, new items appear in the onboarding queue
