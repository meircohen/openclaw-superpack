---
name: content-factory
description: Multi-agent content pipeline -- research, writing, and thumbnail agents in dedicated Discord channels
read_when: "user wants automated content creation pipeline, multi-agent content production, or scheduled content generation"
---

# Multi-Agent Content Factory

Chain specialized agents in a pipeline: research feeds writing, writing feeds thumbnails. Hands-free.

## Architecture

Three agents, three Discord channels:
- **#research** -- Research Agent scans trends, competitor content, social media
- **#scripts** -- Writing Agent drafts scripts/threads/newsletters from top ideas
- **#thumbnails** -- Thumbnail Agent generates cover images for the content

## Setup

1. Create Discord server with three channels
2. Prompt:

```
Build a content factory in Discord:

1. Research Agent (#research): Every morning at 8 AM, research trending
   stories, competitor content, and top-performing social media in my niche.
   Post top 5 content opportunities with sources.

2. Writing Agent (#scripts): Take the best idea from research and write
   a full script/thread/newsletter draft. Post in #scripts.

3. Thumbnail Agent (#thumbnails): Generate cover images for the content.
   Post in #thumbnails.

Run this pipeline automatically every morning.
```

## Skills Needed

- Discord integration with multiple channels
- `sessions_spawn` / `sessions_send` for multi-agent orchestration
- Web search for trend research
- Image generation (Nano Banana or API)

## Customization

Adapt for any content format:
```
I focus on X/Twitter threads, not YouTube. Change the writing agent
to produce tweet threads instead of video scripts.
```

Or newsletters, LinkedIn posts, podcast outlines, blog articles.

## Tips

- Discord channels make review easy -- give feedback per agent
- Running local image gen (Mac Studio + Nano Banana) reduces costs
- One agent's output feeds the next automatically
- Wake up to finished content every morning
