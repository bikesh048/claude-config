---
name: extraction-fix
description: Fix tour content extraction for a specific URL. Screenshots real website, runs importer pipeline, compares output, identifies noise/missing content, and applies semantic DOM/classifier fixes. Use when user provides a tour URL to fix.
allowed-tools: Bash(playwright-cli:*), Bash(curl:*), Bash(cd:*), Bash(ls:*), Bash(cat:*), Bash(rm:*), Bash(kill:*), Bash(lsof:*), Bash(sleep:*), Bash(pnpm:*), Bash(npx:*), Bash(node:*), Read, Edit, Write, Grep, Glob, Agent
---

# Extraction Fix — Tour Content Extraction Issue Resolver

## Purpose

When the user provides a tour URL, this skill:
1. Screenshots the real website to understand what content exists
2. Runs the importer pipeline to see what was extracted
3. Compares the two to identify noise (what shouldn't be there) and gaps (what's missing)
4. Applies semantic/structural fixes to the DOM cleaner, classifier, or section extractor
5. Verifies fixes don't break existing snapshot regression tests

## Trigger

User provides a tour URL and wants to fix/improve its extraction. May also paste extraction output showing specific issues.

## Workflow

### Phase 1: Capture & Compare

```
1. Screenshot the REAL website using playwright-cli:
   playwright-cli open <URL>
   playwright-cli screenshot --filename=captures/<domain>-real.png
   playwright-cli snapshot --filename=captures/<domain>-snapshot.yaml
   playwright-cli close

2. Run the importer pipeline (force fresh scrape):
   curl -s -X POST http://localhost:3030/api/importer/v1/playground/pipeline \
     -H "Content-Type: application/json" \
     -d '{"url": "<URL>", "force": true}'

3. Also check the dashboard import result if dashboard is available:
   - Login: http://dashboard.test/tour-listing
   - Credentials: see ~/.claude-secrets → DASHBOARD_USER / DASHBOARD_PASS

4. Compare: what's on the real page vs what was extracted.
   Identify:
   - NOISE: content that shouldn't be there (reviews, pricing, related tours, ads, CTAs)
   - MISSING: content that should be there but isn't (overview, itinerary, FAQs, inclusions)
   - DUPLICATES: same content appearing multiple times (responsive duplicates, thumbnail variants)
```

### Phase 2: Analyze Captures

```
5. Examine the scraped HTML structure:
   node -e "
     const cheerio = require('cheerio');
     const fs = require('fs');
     const html = fs.readFileSync('captures/<domain>/<date>/<hash>/scraped.html', 'utf8');
     const $ = cheerio.load(html);
     // Check for semantic landmarks, heading structure, noise patterns
   "

6. Examine the cleaned DOM:
   - Compare scraped.html vs dom.html to see what the cleaner removed/kept
   - Check heading hierarchy in dom.html
   - Identify structural patterns for noise (repeated cards, review blocks, pricing widgets)
```

### Phase 3: Fix (Semantic/Structural Preferred)

```
Priority order for fixes:
1. SEMANTIC: Use HTML5 landmarks, heading hierarchy, ARIA roles
2. STRUCTURAL: Detect noise by DOM shape (repeated siblings, img+heading cards)
3. CLASSIFIER: Add heading patterns to rule-based-classifier.service.ts
4. DOM CLEANER: Add noise selectors or heading patterns to dom-cleaner.service.ts
5. SECTION EXTRACTOR: Fix content routing in tour-section-extractor.service.ts

Key files:
- apps/importer/backend/src/modules/capture/services/dom-cleaner.service.ts
- apps/importer/backend/src/modules/parser/services/rule-based-classifier.service.ts
- apps/importer/backend/src/modules/parser/services/tour-section-extractor.service.ts
- apps/importer/backend/src/modules/shared/heading-patterns.ts
- apps/importer/backend/src/modules/capture/services/page-interaction.service.ts
- apps/importer/backend/src/modules/capture/services/content-density-scorer.service.ts
```

### Phase 4: Verify

```
7. Type-check:
   cd apps/importer/backend && npx tsc --noEmit

8. Run regression tests:
   npx jest --config jest.unit.config.js --testPathPatterns="pipeline-e2e" --no-coverage

   Baseline: 4 pre-existing failures in worldexpeditions.com
   Any NEW failures beyond these must be investigated.

9. Restart dev server and re-test the URL:
   kill $(lsof -t -i:3030); sleep 1; pnpm run dev &
   # Delete cached scraped.html to force fresh scrape
   rm captures/<domain>/<date>/<hash>/scraped.html
   # Re-run pipeline
   curl -s -X POST http://localhost:3030/api/importer/v1/playground/pipeline ...
```

## Rules

- **NEVER modify snapshot files** under test/e2e/snapshots/
- **Prefer semantic/structural fixes** over filename/keyword heuristics
- **Test 1-3 iterations per URL** — screenshot, extract, compare, fix, repeat
- **Use playwright-cli** (not Playwright MCP tools) for browser automation
- **Run foreground agents** for extraction fixes — user wants to see progress
- **Check how existing patterns solve the problem** before adding new approaches

## Noise Patterns Reference

### Already Handled (DOM Cleaner)
- `<nav>`, `<footer>`, `<header>`, `<aside>` (semantic chrome)
- Class-based: cookie, popup, modal, ads, social-share, breadcrumb, booking, newsletter, rating, testimonial, similar, cta, pricing, chat-widget, consent
- Heading-based: related tours, similar tours, popular tours, your next discovery, price-only headings, dates & availability

### Already Handled (Classifier)
- ignore:reviews — reviews, ratings, testimonials, feedback, guest feedback
- ignore:booking — book now, reserve, check availability, package options, view available dates
- ignore:related — similar tours, related tours, popular tours, your next discovery
- ignore:awards — proudly awarded, our awards
- ignore:social — share this, follow us
- ignore:newsletter — subscribe, newsletter

### Image Filtering
- Domain filter: tripadvisor, fbcdn, gravatar, trustpilot, mylivechat, tawk.to, crisp.chat
- Filename filter: favicon, logo, badge, icon, avatar, livechat, chatbutton
- Size-variant dedup: keeps largest of -NNNpx variants (e.g., -800px over -200px)
- SVG and placeholder filtering

### Accordion/Tab Expansion
- Bootstrap collapse triggers
- ARIA expanded="false" / data-state="closed" (Radix, Headless UI, MUI)
- CSS Modules accordion buttons (class*="accordion")
- Hash-link tab navigation

## Common Fix Patterns

### New noise heading → DOM Cleaner Phase 2e
```typescript
// In noiseHeadingPatterns array:
/^your\s+new\s+pattern/i,
```

### New ignore classification → Classifier
```typescript
// In headingRules array:
{ category: 'ignore', pattern: /\bnew\s*pattern\b/i, confidence: 'high', name: 'ignore:new', skipGuard: true },
```

### New noise selector → DOM Cleaner noiseSelectors
```typescript
'[class*="new-noise"]', '[id*="new-noise"]',
```

### Embedded FAQ extraction → Section Extractor
Already handles h3/h4 headings ending with "?" inside info blocks.

### Image noise → DOM Cleaner filterImages
```typescript
// Domain: add to the regex
/\b(newdomain\.com)\b/i
// Filename: add to the regex
/\bnewpattern\b/i.test(filename)
```
