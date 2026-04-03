---
name: image-gen
description: Generate images using OpenAI DALL-E 3 or gpt-image-1. Use when a user asks to create, generate, draw, design, or make an image, picture, illustration, logo, icon, or visual. Also use for editing/variations when prompted.
---

# Image Generation

Generate images via the OpenAI Images API (DALL-E 3 or gpt-image-1).

## Prerequisites

`OPENAI_API_KEY` must be set in `~/.openclaw/.env`.

## Usage

```bash
python3 scripts/generate.py "a sunset over Miami Beach" --model gpt-image-1 --size 1024x1024 --quality high
```

### Models

| Model | Best for | Sizes | Notes |
|-------|----------|-------|-------|
| `gpt-image-1` | High quality, text rendering, complex scenes | 1024x1024, 1536x1024, 1024x1536, auto | Default. Supports transparent backgrounds. |
| `dall-e-3` | Fast, cheaper | 1024x1024, 1024x1792, 1792x1024 | Auto-rewrites prompts for better results. |

### Options

- `--model`: `gpt-image-1` (default) or `dall-e-3`
- `--size`: Image dimensions (default: `1024x1024`)
- `--quality`: `auto`/`low`/`medium`/`high` for gpt-image-1; `standard`/`hd` for dall-e-3
- `--style`: `vivid` or `natural` (dall-e-3 only)
- `--background`: `auto`/`transparent`/`opaque` (gpt-image-1 only)
- `--n`: Number of images, 1-4 for gpt-image-1
- `--output`/`-o`: Custom output path

### Output

Images save to `artifacts/images/` by default. Script outputs JSON with file paths.

## Workflow

1. Craft a detailed prompt — be specific about style, composition, colors, mood
2. Run generate.py with appropriate model and settings
3. Use the `image` tool to verify the output visually
4. Iterate on the prompt if needed

## Prompt Tips

- Be specific: "watercolor painting of a golden retriever in a field of lavender at sunset" > "dog picture"
- Specify style: photorealistic, illustration, watercolor, oil painting, pixel art, 3D render
- Include composition: close-up, wide shot, bird's eye view, centered
- For text in images: use gpt-image-1 (much better at text rendering)
