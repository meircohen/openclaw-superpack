---
name: web-perf-audit
description: Audit Core Web Vitals, render-blocking resources, and page load performance
read_when: "user wants to audit web performance, improve page speed, fix Core Web Vitals, or optimize loading"
---

# Web Performance Audit

Audit and optimize Core Web Vitals and overall page load performance.

## Core Web Vitals Targets

| Metric | Good | Needs Work | Poor |
|--------|------|-----------|------|
| LCP (Largest Contentful Paint) | < 2.5s | 2.5-4s | > 4s |
| INP (Interaction to Next Paint) | < 200ms | 200-500ms | > 500ms |
| CLS (Cumulative Layout Shift) | < 0.1 | 0.1-0.25 | > 0.25 |

## Measurement

```bash
# Lighthouse CLI
npx lighthouse https://example.com --output json --output-path report.json

# Performance only
npx lighthouse https://example.com --only-categories=performance --output html --output-path perf.html

# Mobile simulation
npx lighthouse https://example.com --preset=perf --emulated-form-factor=mobile
```

## Common Issues and Fixes

### LCP Too Slow
1. **Render-blocking CSS/JS**: Add `defer` or `async` to scripts, inline critical CSS
2. **Large images**: Use WebP/AVIF, add `width`/`height`, use `loading="lazy"` below fold
3. **Slow server**: Check TTFB, add CDN, enable compression (gzip/brotli)
4. **Web fonts**: Use `font-display: swap`, preload critical fonts
```html
<link rel="preload" href="/fonts/main.woff2" as="font" type="font/woff2" crossorigin>
```

### INP Too High
1. **Long tasks**: Break up JS execution, use `requestIdleCallback`
2. **Heavy event handlers**: Debounce input handlers, use `requestAnimationFrame`
3. **Third-party scripts**: Defer non-critical scripts, use facade pattern
4. **Hydration cost**: Use progressive hydration or islands architecture

### CLS Too High
1. **Images without dimensions**: Always set `width` and `height` attributes
2. **Dynamic content injection**: Reserve space with CSS `aspect-ratio` or `min-height`
3. **Web fonts causing FOUT**: Use `font-display: optional` or size-adjust
4. **Ads/embeds**: Reserve container dimensions

## Resource Checklist
```bash
# Check what's loaded
curl -s https://example.com | grep -oP '(src|href)="[^"]*"' | sort

# Check compression
curl -sI -H "Accept-Encoding: gzip,br" https://example.com | grep -i content-encoding

# Check caching headers
curl -sI https://example.com/style.css | grep -i cache-control
```

## Performance Budget
| Resource Type | Budget |
|--------------|--------|
| HTML | < 50 KB |
| CSS (total) | < 100 KB |
| JS (total) | < 300 KB |
| Images (per page) | < 500 KB |
| Web fonts | < 100 KB |
| Total page weight | < 1.5 MB |

## Monitoring
- Set up RUM (Real User Monitoring) with web-vitals library
- Track CrUX data in Google Search Console
- Alert on regressions > 20% from baseline
