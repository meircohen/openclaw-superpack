---
name: second-brain
description: Zero-friction memory capture via text message with searchable dashboard
read_when: "user wants to save ideas, capture notes via chat, build a knowledge base, or search past memories"
---

# Second Brain

Text anything to remember it. Search everything later. Zero friction.

## Core Principle

Capture should be as easy as texting. Retrieval should be as easy as searching. No folders, no tags, no organization overhead.

## How It Works

1. Text your agent via Telegram/iMessage/Discord with anything:
   - "Remind me to read Designing Data-Intensive Applications"
   - "Save this link: https://example.com/article"
   - "Remember: John recommended the restaurant on 5th street"

2. Agent stores it in memory immediately (built-in memory system)

3. Search anytime: "What was that restaurant John mentioned?"

## Searchable Dashboard (Optional)

Ask the agent to build a Next.js dashboard:

```
Build a second brain dashboard with Next.js. Include:
- Searchable list of all memories and conversations
- Global search (Cmd+K) across everything
- Filter by date and type
- Clean, minimal UI
```

The agent builds and deploys the entire app.

## Power Features

- **Cumulative memory**: Everything you have ever told the agent is remembered
- **Cross-device capture**: Text from your phone, search from your laptop
- **No organization tax**: Just text and search -- the agent handles structure
- **Semantic retrieval**: Ask by meaning, not exact keywords

## Pair With

- `semantic-memory-search` (memsearch) for vector-powered semantic search over memory files
- Install memsearch for hybrid retrieval (dense vectors + BM25):
  ```bash
  pip install memsearch
  memsearch index ~/path/to/memory/
  memsearch search "what caching solution did we pick?"
  ```

## Tips

- Use it for everything: ideas, links, book recommendations, meeting notes, random thoughts
- The more you capture, the more valuable search becomes
- Voice-to-text on your phone makes capture even faster
