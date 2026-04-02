---
name: reddit-digest
description: Daily curated digest of top Reddit posts from favorite subreddits with preference learning
read_when: "user wants Reddit summaries, subreddit monitoring, or a daily Reddit digest"
---

# Reddit Digest

Summarize top-performing posts from chosen subreddits daily, learning preferences over time.

## How It Works

1. User provides a list of subreddits to monitor
2. Agent fetches hot/top posts using the reddit-readonly skill (no auth needed)
3. Filters posts based on learned preferences (stored in memory)
4. Delivers a curated digest at the scheduled time
5. Asks user for feedback and updates preference rules

## Setup

Install the `reddit-readonly` skill from ClawHub:
```bash
clawhub install buksan1950/reddit-readonly
```

## Prompt Template

```
I want a daily digest of top posts from these subreddits:
- r/LocalLLaMA
- r/MachineLearning
- r/programming
[add yours]

Create a memory file for my Reddit preferences. Every day at [TIME], run this digest.
After delivering, ask if I liked the selection. Save my feedback as rules:
- e.g., "skip memes", "prioritize tutorials", "exclude posts under 50 upvotes"

Format each entry as:
- Title + link
- Score and comment count
- 1-2 sentence summary
- Why it matches my preferences
```

## Preference Learning

Store rules in `~/.openclaw/memory/reddit-preferences.md`:
```
## Rules
- Skip memes and image-only posts
- Prioritize tutorials and deep technical content
- Minimum 50 upvotes
- Exclude "rate my setup" posts
```

Update rules after each feedback cycle. The digest improves daily.

## Tips

- Read-only: no posting, voting, or commenting
- Pull comment threads for context on interesting discussions
- Build a "shortlist" of posts to manually review later
- Combine with scheduling (cron) for hands-free delivery
