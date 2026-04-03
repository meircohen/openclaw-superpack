---
name: youtube-digest
description: Daily summaries of new videos from favorite YouTube channels with transcript insights
read_when: "user wants YouTube summaries, channel monitoring, or video digest"
---

# YouTube Digest

Get daily summaries of new videos from your favorite channels using transcript analysis.

## How It Works

1. Check channels for new uploads (free, 0 credits)
2. Fetch transcripts for new videos only (1 credit each)
3. Summarize key insights in 2-3 bullets per video
4. Deliver digest at scheduled time
5. Track seen videos to avoid re-processing

## Setup

Install the `youtube-full` skill:
```bash
npx clawhub@latest install youtube-full
```

Account creation and API key setup happen automatically. 100 free credits on signup.

## Channel-Based Digest

```
Every morning at 8am, fetch latest videos from these channels:
- @Fireship
- @ThePrimeTimeagen
- @lexfridman
[add yours]

For each new video (last 24-48h):
1. Get the transcript
2. Summarize main points in 2-3 bullets
3. Include title, channel, and link

Save my channel list to memory so I can add/remove later.
```

## Keyword-Based Digest

```
Every day, search YouTube for new videos about "AI agents".
Maintain seen-videos.txt with processed video IDs.
Only fetch transcripts for unseen videos.
For each: 3-bullet summary + relevance to my work.
```

## Tips

- `channel/latest` and `channel/resolve` are free (0 credits)
- Only transcripts cost credits -- check for new uploads first
- Ask for different styles: takeaways, notable quotes, timestamps
- Combine channel-based and keyword-based for full coverage
