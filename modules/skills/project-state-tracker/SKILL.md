---
name: project-state-tracker
description: Event-driven project state management replacing Kanban -- conversational updates, decision history, auto standups
read_when: "user wants project tracking, status updates, decision logging, standup summaries, or alternative to Kanban"
---

# Project State Tracker

Replace Kanban with conversational project state management. Talk about progress, agent tracks everything.

## How It Works

Instead of dragging cards, chat naturally:
- "Finished the auth flow, starting on the dashboard" -> logs progress, updates state
- "Blocked on the API rate limit" -> creates blocker, changes status
- "Decided to use Postgres instead of Mongo" -> logs decision with context

## Database Setup

```sql
CREATE TABLE projects (
  id INTEGER PRIMARY KEY,
  name TEXT UNIQUE,
  status TEXT,          -- active, blocked, completed
  current_phase TEXT,
  last_update TIMESTAMPTZ DEFAULT NOW()
);

CREATE TABLE events (
  id INTEGER PRIMARY KEY,
  project_id INTEGER REFERENCES projects(id),
  event_type TEXT,      -- progress, blocker, decision, pivot
  description TEXT,
  context TEXT,
  timestamp TIMESTAMPTZ DEFAULT NOW()
);

CREATE TABLE blockers (
  id INTEGER PRIMARY KEY,
  project_id INTEGER REFERENCES projects(id),
  blocker_text TEXT,
  status TEXT DEFAULT 'open',
  created_at TIMESTAMPTZ DEFAULT NOW(),
  resolved_at TIMESTAMPTZ
);
```

## Agent Instructions

```
You are my project state manager.

On conversational updates:
- "Finished [X]" -> log progress event, update state
- "Blocked on [X]" -> create blocker, set status to blocked
- "Starting [X]" -> log progress, update current phase
- "Decided to [X]" -> log decision event with full context
- "Pivoting to [X]" -> log pivot event with reasoning

On queries:
- "Status of [project]?" -> latest events, blockers, current phase
- "Why did we decide [X]?" -> search decision events
- "What's blocked?" -> list all open blockers

Daily standup (9 AM cron):
1. Scan git commits from past 24h (gh CLI)
2. Link commits to projects by branch/message
3. Post to Discord/Slack:
   - Yesterday: events + commits
   - Today: current phase + plans
   - Blocked: open blockers
```

## Key Insight

Context gets preserved. Three months from now, you can ask "why did we switch to Postgres?" and get the full reasoning -- something Kanban boards never capture.
