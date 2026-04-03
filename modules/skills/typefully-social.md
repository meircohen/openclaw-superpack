---
name: typefully-social
description: Create, schedule, and publish social media content across X, LinkedIn, Threads, Bluesky
read_when: "user wants to publish social media posts, schedule tweets, cross-post to LinkedIn/Threads/Bluesky, or manage social content"
---

# Typefully Social Publishing

Create, schedule, and publish social media content across X, LinkedIn, Threads, Bluesky, and Mastodon using Typefully.

## Setup
```bash
export TYPEFULLY_API_KEY="tf_..."
```

## API Endpoints

### Create a Draft
```bash
curl -X POST https://api.typefully.com/v1/drafts/ \
  -H "X-API-KEY: $TYPEFULLY_API_KEY" \
  -H "Content-Type: application/json" \
  -d '{
    "content": "Your post content here.\n\n---\n\nSecond tweet in thread.",
    "threadify": false,
    "platforms": ["twitter", "linkedin", "threads"]
  }'
```

### Schedule a Post
```bash
curl -X POST https://api.typefully.com/v1/drafts/ \
  -H "X-API-KEY: $TYPEFULLY_API_KEY" \
  -H "Content-Type: application/json" \
  -d '{
    "content": "Scheduled post content",
    "schedule-date": "2024-03-15T10:00:00Z",
    "platforms": ["twitter"]
  }'
```

### Auto-schedule (next available slot)
Add `"auto_schedule": true` to let Typefully pick the optimal time.

## Content Formatting

### Thread Format
Separate tweets/posts with `\n\n---\n\n`:
```
First tweet of the thread.

---

Second tweet continues here.

---

Final tweet with CTA.
```

### Platform-Specific Limits
| Platform | Character Limit | Media |
|----------|----------------|-------|
| X/Twitter | 280 (or 25K for Premium) | 4 images, 1 video |
| LinkedIn | 3,000 | Images, documents |
| Threads | 500 | 10 images |
| Bluesky | 300 | 4 images |

## Content Templates

### Announcement
```
We just shipped [feature].

Here's what it does:
- [Benefit 1]
- [Benefit 2]
- [Benefit 3]

Try it: [link]
```

### Thread (educational)
```
[Hook - provocative statement or question]

---

[Context - why this matters]

---

[Point 1 with example]

---

[Point 2 with example]

---

[Summary + CTA]
```

## Best Practices
- Post 3-5x/week consistently
- Best times: Tue-Thu, 9-11am target timezone
- Use threads for engagement (they get 2-3x more impressions)
- Add a hook in the first line (question, number, bold claim)
- End with a clear CTA (follow, reply, link)
- Cross-post but adapt tone per platform (professional for LinkedIn, casual for X)
