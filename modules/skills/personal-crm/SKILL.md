---
name: personal-crm
description: Auto-discover and track contacts from email and calendar with natural language queries
read_when: "user wants to track contacts, manage relationships, get meeting prep briefings, or query contact history"
---

# Personal CRM

Automatically build and maintain a contact database from email and calendar interactions.

## Setup

1. Create the CRM database:
```sql
CREATE TABLE contacts (
  id INTEGER PRIMARY KEY,
  name TEXT,
  email TEXT,
  first_seen TEXT,
  last_contact TEXT,
  interaction_count INTEGER,
  notes TEXT
);
```

2. Configure daily cron (6 AM):
```
Scan Gmail and Calendar for past 24 hours.
Extract new contacts, update existing ones.
Log interactions with timestamps and context.
```

3. Configure morning briefing (7 AM):
```
Check today's calendar meetings.
For each external attendee, search CRM + email history.
Deliver briefing to Telegram:
- Who they are
- When we last spoke
- What we discussed
- Any open follow-up items
```

## Natural Language Queries

Ask anytime via a dedicated Telegram topic:
- "What do I know about Sarah Chen?"
- "Who needs follow-up this week?"
- "When did I last talk to David?"
- "Show all contacts from Acme Corp"
- "Who have I met in the last 30 days?"

## Skills Needed

- `gog` CLI for Gmail/Calendar access
- SQLite database for contact storage
- Telegram for queries and briefings

## Tips

- Start read-only: scan and index before taking any actions
- Meeting prep briefings are the highest-value feature
- Interaction count helps prioritize who matters most
- Notes field captures context that email search alone misses
