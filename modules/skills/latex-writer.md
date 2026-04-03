---
name: latex-writer
description: Write and compile LaTeX papers conversationally with instant PDF preview
read_when: "user wants to write LaTeX, compile a paper, create an academic document, or work with BibTeX"
---

# LaTeX Paper Writing

Write and compile LaTeX papers conversationally. No local TeX installation needed.

## Setup

Clone and deploy Prismer with Docker (includes full TeX Live):
```bash
git clone https://github.com/Prismer-AI/Prismer.git && cd Prismer
docker compose -f docker/docker-compose.dev.yml up
```

The `latex-compiler` skill is built-in with 4 tools:
- `latex_compile` -- compile .tex to PDF
- `latex_preview` -- inline PDF preview
- `latex_templates` -- list available templates
- `latex_get_template` -- fetch a starter template

## Workflow

```
Help me write a research paper in LaTeX:
1. Start from the IEEE template (or article/beamer)
2. When I describe a section, generate the LaTeX source
3. After each major edit, compile and preview the PDF
4. If compilation errors, read the log and fix automatically
5. When I provide BibTeX entries, add to bibliography and recompile

Use xelatex for CJK support, otherwise pdflatex.
Always run 2 passes for cross-references.
```

## Available Templates

- **article** -- standard LaTeX article
- **IEEE** -- IEEE conference/journal format
- **beamer** -- presentation slides
- **Chinese article** -- CJK-ready with xelatex

## Tips

- Describe sections in natural language, agent generates LaTeX
- Paste BibTeX entries directly -- agent integrates them
- Agent auto-fixes compilation errors from log output
- Preview inline without switching to a PDF viewer
- Supports pdflatex, xelatex, and lualatex engines
