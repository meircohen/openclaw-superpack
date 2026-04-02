---
name: pre-build-validator
description: Scan GitHub, HN, npm, PyPI, and Product Hunt before building to check if the idea already exists
read_when: "user wants to build something new, validate a project idea, check for competitors, or assess market saturation"
---

# Pre-Build Idea Validator

Before writing any code for a new project, check if it already exists.

## How It Works

Uses the `idea-reality-mcp` server to scan 5 real data sources:
- GitHub (repo count, star distribution)
- Hacker News (discussion volume)
- npm (package count)
- PyPI (package count)
- Product Hunt (existing products)

Returns a `reality_signal` score (0-100) indicating market saturation.

## Setup

```bash
uvx idea-reality-mcp
```

Add to MCP config:
```json
{
  "mcpServers": {
    "idea-reality": {
      "command": "uvx",
      "args": ["idea-reality-mcp"]
    }
  }
}
```

## Decision Rules

Add to agent instructions:

```
Before starting any new project, tool, or feature, run idea_check first.

- reality_signal > 70: STOP. Show top 3 competitors with stars.
  Ask: proceed, pivot, or abandon?
- reality_signal 30-70: Show results + pivot_hints.
  Suggest a niche angle existing projects miss.
- reality_signal < 30: Proceed. Note the space is open.

Always show the score and top competitors before writing code.
```

## Variations

- **Deep mode**: `depth="deep"` scans all 5 sources in parallel for major decisions
- **Batch validation**: Give a list of 10 ideas, rank by reality_signal (lowest = most original)
- **Web demo**: Try at mnemox.ai/check before installing

## Key Insight

A high score does not mean "don't build." It means "differentiate or don't bother." A low score means genuine white space -- that is where solo builders win.
