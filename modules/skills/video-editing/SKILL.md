---
name: video-editing
description: Edit videos via natural language -- trim, merge, subtitle, color grade, batch process
read_when: "user wants to edit video, add subtitles, trim clips, batch process video files, or crop to vertical"
---

# Video Editing via Chat

Edit videos by describing changes in natural language. No timeline, no GUI.

## Capabilities

- Trim, cut, merge clips by timestamp
- Add background music with automatic audio ducking
- Generate and burn subtitles (50+ languages)
- Color grade ("make it warmer", "match the look of clip 1")
- Crop to vertical for TikTok/Reels/Shorts (9:16)
- Batch process multiple files with the same edit

## Setup

```bash
clawhub install video-editor-ai
clawhub install ai-subtitle-generator
```

## Usage

Drop a video file into chat and describe your edit:

```
Trim this video from 0:15 to 1:30, add upbeat background music,
and burn English subtitles.
```

For batch processing:
```
I have 5 clips in /videos/raw/. For each one:
- Crop to 9:16 vertical
- Add auto-generated captions at the bottom
- Export as mp4 at 1080p
```

## Tips

- Be specific about timestamps and output format
- Mention source language if not English for subtitle work
- Use reference descriptions for color grading ("warm sunset tones")
- Avoid uploading sensitive footage -- review provider's data retention policy
- The agent handles API calls, polls for completion, and delivers finished files
