---
name: design-system-gen
description: Generate cohesive UI designs with strict color, typography, and layout rules for modern web apps
read_when: "when building UI from scratch, when creating landing pages, when the user asks for a beautiful or modern design"
---

# Design System Generation

Adapted from v0's design guidelines. Enforces a constrained, cohesive design system that prevents common UI mistakes.

## Color System

ALWAYS use exactly 3-5 colors total.

- Choose 1 primary brand color appropriate for the domain.
- Add 2-3 neutrals (white, grays, off-whites, black variants).
- Add 1-2 accent colors.
- NEVER exceed 5 total colors without explicit permission.
- If you override a component's background color, you MUST override its text color for contrast.

**Gradients:**
- Avoid entirely unless explicitly requested.
- If needed: only subtle accents, never primary elements.
- Use analogous colors only (blue->teal, purple->pink). NEVER mix opposing temperatures (pink->green, orange->blue).
- Maximum 2-3 color stops.

## Typography

Maximum 2 font families total.

- One for headings (can vary weights), one for body text.
- Line-height 1.4-1.6 for body text.
- NEVER use decorative fonts for body text.
- Minimum 14px font size for any text, 16px for inputs.

## Layout

- Mobile-first: design for small screens first, enhance for larger.
- 44px minimum touch targets for all interactive elements.
- Use flexbox for most layouts, CSS Grid only for complex 2D layouts.
- NEVER use floats or absolute positioning unless absolutely necessary.
- Use spacing scale values (4, 8, 12, 16, 24, 32, 48, 64) not arbitrary pixel values.
- Use gap classes for spacing between children, not margin.

## Semantic Design Tokens

Define all colors as semantic tokens, not raw values:
- `--background`, `--foreground`, `--primary`, `--secondary`, `--accent`, `--muted`, `--border`, `--destructive`
- Never use direct colors like `text-white` or `bg-black` -- everything goes through tokens.

## Component Rules

- Split UI into multiple components. Never one giant page file.
- Use semantic HTML elements (`main`, `header`, `nav`, `section`).
- Add proper ARIA roles and attributes.
- Add alt text for all non-decorative images.
- Use screen-reader-only classes for accessible labels.
- NEVER use emojis as icons -- use a proper icon library.
- NEVER generate SVG paths for maps or geographic data -- use a mapping library.

## Visual Content

- Prefer real images over placeholders.
- NEVER generate abstract shapes (gradient circles, blurry squares, decorative blobs) as filler.
- NEVER hand-draw SVG illustrations for complex visuals.

## Final Rule

Ship something interesting rather than boring, but never ugly.
