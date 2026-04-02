---
name: playwright-browser
description: Automate browser interactions for testing, scraping, and UI verification
read_when: "user wants to automate browser actions, take screenshots, test web UIs, or scrape web pages"
---

# Playwright Browser Automation

Use Playwright to automate real browser interactions -- navigate, click, fill forms, screenshot, and scrape.

## Setup

```bash
npm init -y && npm install playwright
npx playwright install chromium
```

## Quick Scripts

### Take a screenshot
```javascript
// screenshot.mjs
import { chromium } from 'playwright';
const browser = await chromium.launch();
const page = await browser.newPage();
await page.goto('https://example.com');
await page.screenshot({ path: 'screenshot.png', fullPage: true });
await browser.close();
```

### Fill and submit a form
```javascript
await page.goto('https://example.com/login');
await page.fill('input[name="email"]', 'user@example.com');
await page.fill('input[name="password"]', 'secret');
await page.click('button[type="submit"]');
await page.waitForURL('**/dashboard');
```

### Scrape content
```javascript
await page.goto('https://example.com/products');
const items = await page.$$eval('.product-card', cards =>
  cards.map(c => ({
    title: c.querySelector('h2')?.textContent,
    price: c.querySelector('.price')?.textContent,
  }))
);
console.log(JSON.stringify(items, null, 2));
```

### Wait for elements
```javascript
await page.waitForSelector('.loaded-content');
await page.waitForResponse(resp => resp.url().includes('/api/data'));
await page.waitForLoadState('networkidle');
```

## CLI One-liner
```bash
npx playwright screenshot https://example.com screenshot.png --full-page
```

## Testing Pattern
```javascript
// test.spec.mjs
import { test, expect } from '@playwright/test';
test('homepage loads', async ({ page }) => {
  await page.goto('http://localhost:3000');
  await expect(page.locator('h1')).toContainText('Welcome');
  await expect(page).toHaveScreenshot();
});
```

## Key Tips
- Use `{ headless: false }` for debugging
- `page.locator()` is preferred over `page.$()` for resilience
- Set `timeout: 30000` for slow-loading pages
- Use `page.route()` to mock API responses in tests
