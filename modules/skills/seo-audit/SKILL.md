---
name: seo-audit
description: Audit and diagnose technical and on-page SEO issues on websites
read_when: "user wants an SEO audit, to improve search rankings, fix SEO issues, or optimize a site for search"
---

# SEO Audit

Systematic audit of technical SEO, on-page optimization, and content quality.

## Technical SEO Checklist

### Crawlability
- [ ] `robots.txt` exists and is correct (`/robots.txt`)
- [ ] XML sitemap exists and is submitted (`/sitemap.xml`)
- [ ] No accidental `noindex` on important pages
- [ ] Canonical tags set correctly
- [ ] 301 redirects for moved content (no 302 chains)

### Performance (Core Web Vitals)
- [ ] LCP < 2.5s
- [ ] INP < 200ms
- [ ] CLS < 0.1
- Measure: `npx lighthouse <URL> --output json`

### Mobile
- [ ] Responsive design (test at 375px)
- [ ] No horizontal scroll
- [ ] Touch targets >= 48px

## On-Page SEO Per-page Checklist
- [ ] Title tag: 50-60 chars, primary keyword
- [ ] Meta description: 150-160 chars, compelling
- [ ] H1: One per page, includes keyword
- [ ] H2-H3: Logical hierarchy
- [ ] Images: alt text, compressed, dimensions set
- [ ] Internal links: 3-5 per page
- [ ] URL: Short, descriptive, hyphens

## Schema Markup
```html
<script type="application/ld+json">
{"@context":"https://schema.org","@type":"Article","headline":"...","author":{"@type":"Person","name":"..."}}
</script>
```

## Quick Audit Command
```bash
npx lighthouse https://example.com --only-categories=seo,performance,accessibility --output html --output-path report.html
```

## Output: Prioritized Table
| Priority | Issue | Pages Affected | Fix | Impact |
|----------|-------|---------------|-----|--------|
| Critical | Missing title tags | /about | Add unique titles | High |
