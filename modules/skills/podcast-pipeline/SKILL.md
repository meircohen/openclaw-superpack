---
name: podcast-pipeline
description: Automate podcast production -- guest research, outlines, show notes, social media promo
read_when: "user is producing a podcast, needs show notes, episode prep, guest research, or podcast social media posts"
---

# Podcast Production Pipeline

From topic to publish-ready assets. Handles the 70% of podcast work that is not recording.

## Pre-Recording: Research + Outline

```
I'm recording Episode [N] about [TOPIC]. Guest: [NAME].

1. Research the guest: background, recent work, hot takes, controversies
2. Research the topic: trends, news, misconceptions, audience knowledge gaps
3. Generate episode outline:
   - Cold open hook (1-2 sentences)
   - Intro script (30 seconds, casual)
   - 5-7 interview questions (easy rapport-builders to deep/provocative)
   - 2-3 "back pocket" questions for stalls
   - Closing segment with CTA

Save to ~/podcast/episodes/[N]/prep/
```

## Post-Recording: Show Notes + Promo

```
Here's the transcript for Episode [N]: [file path]

1. Timestamped show notes: every topic shift gets a timestamp, 1-line summary,
   and links to everything mentioned
2. Episode description (max 200 words, SEO-optimized, 3-5 keywords)
3. Social media:
   - X/Twitter: 3 tweets (pull quote, key insight, discussion question) <280 chars
   - LinkedIn: 1 post, professional, 100-150 words
   - Instagram: 1 caption, casual, with hashtags
4. Highlights list: 3 most surprising moments with timestamps

Save to ~/podcast/episodes/[N]/publish/
```

## Competitor Monitoring (Optional)

```
Monitor these podcast RSS feeds daily:
- [feed URL 1]
- [feed URL 2]

When a new episode covers a relevant topic, notify via Telegram:
- Title + link
- 1-sentence summary
- Should I respond to this or cover it from my angle?
```

## Tips

- Pre-recording research is the highest-value step
- Timestamped show notes are a listener retention tool most skip
- Social media kit saves the most recurring time
- Use Whisper for local transcript generation
