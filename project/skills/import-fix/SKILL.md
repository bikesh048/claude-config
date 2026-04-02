---
name: import-fix
description: End-to-end tour import diagnosis and fix. Takes 1-2 URLs from same domain — with 2 URLs, diffs pages to separate domain noise from tour content with high confidence. Launches parallel agents, compares main vs noise, applies semantic fixes. Use when user provides tour URL(s) to fix.
allowed-tools: Bash(playwright-cli:*), Bash(npx playwright-cli:*), Bash(curl:*), Bash(cd:*), Bash(ls:*), Bash(cat:*), Bash(rm:*), Bash(kill:*), Bash(lsof:*), Bash(sleep:*), Bash(pnpm:*), Bash(npx:*), Bash(node:*), Read, Edit, Write, Grep, Glob, Agent
---

# Import Fix — Parallel Visual Import Diagnosis & Fix

## Purpose

Single skill to diagnose and fix tour content extraction. Given 1-2 URLs:
1. Parallel agents analyze source page(s) and pipeline extraction
2. **With 2 URLs**: diff extracted blocks — shared = domain noise, unique = tour content (high confidence)
3. Compare what exists vs what was extracted
4. Classify content as main/noise/ambiguous
5. Apply semantic code fixes
6. Verify with tests and re-extraction

## Trigger

User provides 1-2 tour URLs from the same domain and wants to fix/improve extraction.
**2 URLs preferred** — enables dual-page diff for confident noise vs content separation.

## Input

```
/import-fix <URL>
/import-fix <URL1> <URL2>    ← preferred: dual-page diff
```

---

## Content Classification

### Main Content (MUST extract)

| Section | Examples |
|---------|----------|
| **Overview** | Tour description, summary paragraphs, intro text |
| **Itinerary** | Day-by-day breakdown: title, description, meals, accommodation, images |
| **FAQs** | Question/answer pairs, "Good to know" Q&A |
| **Inclusions** | What's included list |
| **Exclusions** | What's not included list |
| **Highlights** | Key selling points, bullet features |
| **Trip Notes** | Traveler info, gear lists, fitness requirements, packing |
| **Categories** | Tour categories, tags, activity types, difficulty level, group size, duration |
| **Others** | Main content with no specific section — "About the Guide", "Route Details", "What to Expect", "Safety Info". If it has substantial text and is informational for a traveler, it's "other" main content. |

**Key insight:** Sections like FAQs, inclusions, exclusions, and categories appear on EVERY tour
page of a domain — but with DIFFERENT content per tour. These are per-tour main content, NOT noise.
The dual-page diff must compare actual text content, not just section presence.

### Noise (MUST filter out)

Site-level content that is IDENTICAL across all pages on the domain:

- Header, navigation bar, footer
- Reviews, ratings, testimonials, guest feedback
- Sidebar: pricing widget, booking form, date picker, "From $X" cards
- Related/similar/suggested tours cards
- Suggested articles, blog links, "You might also like"
- Social share buttons, follow us, newsletter signup
- Ads, CTAs ("Book Now" banners), cookie/consent banners
- Breadcrumbs, pagination
- Like/wishlist/favorite buttons
- Chat widgets, support popups
- "Why Choose Us" / "Why Travel With Us" — same marketing copy on every page
- Domain-wide FAQ sections (same Q&As on every page, not tour-specific)

### Ambiguous — STOP AND ASK

If you cannot confidently classify content as main or noise, **ask the user**. Examples:
- "Meet Your Guide" with photo — is it main content?
- A map/route visualization — relevant or chrome?
- A short testimonial embedded inside itinerary
- "Why Choose Us" marketing block
- Photo gallery that could be decorative or informational

Format the question clearly:
```
I found these sections I'm not sure about:
1. "Meet Your Guide" — short bio with photo. Main content or noise?
2. "Route Map" — interactive map widget. Extract or skip?
```

Wait for user response before proceeding with fixes.

---

## Workflow

### Step 1: Launch Parallel Agents

Launch as **foreground** agents simultaneously. With 2 URLs, run pipeline for both.

#### Agent A — Source Page Analysis (per URL)

```
Analyze the source tour page(s) to build a content map.

Using playwright-cli (via Bash), for EACH URL:

1. Open and screenshot the full page:
   playwright-cli open "<URL>"
   playwright-cli screenshot --filename=captures/import-fix-source-<N>.png
   playwright-cli snapshot --filename=captures/import-fix-source-<N>.yaml

2. Read the screenshot. Create a section-by-section content map:
   For EVERY visible section on the page, record:
   - Section heading (or describe if no heading)
   - Classification: main_content | noise | ambiguous
   - If main_content: type (overview/itinerary/faq/inclusion/exclusion/highlight/trip_note/other)
   - If ambiguous: describe what it is so user can decide
   - Approximate content size (short/medium/long)

3. Close browser:
   playwright-cli close

Return the full content map as a structured list.
```

#### Agent B — Pipeline Extraction (per URL)

```
Run the pipeline for each URL and capture what it extracts.

For EACH URL:
1. Run the pipeline API directly:
   curl -s -X POST http://localhost:3030/api/importer/v1/playground/pipeline \
     -H "Content-Type: application/json" \
     -d '{"url": "<URL>", "force": true}'

   Parse the response and summarize:
   - overview: extracted? how many chars?
   - itinerary: extracted? how many days? do days have descriptions?
   - highlights: extracted? how many items?
   - inclusions: extracted? how many items?
   - exclusions: extracted? how many items?
   - faqs: extracted? how many Q&A pairs?
   - tripNote: extracted? how many chars?
   - other: how many sections? what headings?
   - images: how many? any noise images leaked?
   - blocks: full block list with category + heading (for diff)

2. Open dashboard, login, import, and preview (first URL only):
   playwright-cli open "http://dashboard.test/tour-listing"
   playwright-cli snapshot
   # Find and fill login form using refs from snapshot
   # Login: see ~/.claude-secrets → DASHBOARD_USER / DASHBOARD_PASS
   # Navigate to import, paste URL, trigger import
   # Wait for completion, open preview
   playwright-cli screenshot --filename=captures/import-fix-preview.png
   playwright-cli close

Return: pipeline extraction summary per URL + preview screenshot.
```

### Step 2: Dual-Page Diff (when 2 URLs provided)

After both agents return, diff the extracted blocks from both URLs using **content-aware comparison**:

```
For each block, compute TWO signals:
  1. HEADING fingerprint — section heading lowercased, whitespace-normalized
  2. BODY fingerprint — full text content lowercased, whitespace-normalized, first 200 chars

Then classify each block into one of THREE categories:

IDENTICAL blocks (same heading AND same body across both pages) = domain-level noise:
  → Header/footer remnants, review sections, booking widgets, related tours,
    CTAs, newsletter, social sharing, "Why Choose Us", cookie banners.
  → These are literally the same text on every page = site chrome.

SAME-TYPE blocks (same/similar heading BUT different body) = per-tour main content:
  → FAQs: both pages have "FAQs" section but different Q&A pairs
  → Inclusions: both have "What's Included" but different items
  → Exclusions: both have "What's Not Included" but different items
  → Categories/Tags: both have categories but different category lists
  → Overview: both have descriptions but different text
  → These are section TYPES that every tour has with tour-specific content = MAIN CONTENT.

UNIQUE blocks (heading appears in only one page) = tour-specific content:
  → Unique itinerary days, unique trip notes, unique sections.
  → Likely main content unless it matches a known noise pattern.
```

**CRITICAL: Same section type ≠ noise.** Two tours both having FAQs, inclusions, or categories
does NOT make those sections noise. Compare the actual TEXT CONTENT, not just the section presence.

**Content similarity threshold:**
- Body text >90% similar (after normalization) = IDENTICAL → noise candidate
- Body text <90% similar = SAME-TYPE → main content (different per tour)
- Heading not found in other page = UNIQUE → main content

Cross-reference with classifier output:
```
  - IDENTICAL block classified as main content → FALSE POSITIVE (noise leaking in)
  - SAME-TYPE block classified as noise → FALSE NEGATIVE (per-tour content stripped)
  - UNIQUE block classified as noise → FALSE NEGATIVE (content stripped out)
  - These are HIGH CONFIDENCE fix targets
```

Present the diff:
```
Dual-page diff for <domain>:

IDENTICAL (domain noise — same content on both pages):
  - "Similar Tours" heading + 4 card blocks (identical) → classified as: other ← FIX: noise leaking
  - "Reviews" heading + same rating block → correctly classified as: ignore ← OK
  - Booking widget → correctly filtered by DOM cleaner ← OK
  - "Why Travel With Us" → same marketing copy on both → noise ← OK if filtered

SAME-TYPE (per-tour main content — same section type, different content):
  - "FAQs" — Page1: 5 Q&As, Page2: 3 Q&As (different questions) → MAIN CONTENT
  - "What's Included" — Page1: 12 items, Page2: 8 items (different lists) → MAIN CONTENT
  - "What's Not Included" — Page1: 5 items, Page2: 6 items (different lists) → MAIN CONTENT
  - "Categories" — Page1: "Adventure, Hiking", Page2: "Cultural, Food" → MAIN CONTENT
  - "Overview" — different descriptions → MAIN CONTENT
  If any of these are currently classified as noise → FIX NEEDED (false negative)

UNIQUE (tour content — only in one page):
  - "Day 1: Arrival in KL" → classified as: itinerary ← OK
  - "Trip Notes" section → classified as: noise ← FIX NEEDED (false negative)
```

### Step 3: Compare & Report

Merge the visual content map (Agent A) with extraction results (Agent B) and diff insights:

For each section from Agent A's content map:
- **Extracted correctly** → [x]
- **Missing** → [ ] MISSING
- **Noise leaked into extraction** → [ ] NOISE LEAKED
- **Confirmed by diff** → mark with (diff-confirmed) for high confidence
- **Content truncated or wrong section** → [ ] MISPLACED

Present as a checklist:
```
Comparing <URL> — source vs extraction:

Main Content:
[x] Overview — 1200 chars extracted
[ ] Itinerary — MISSING (8 days on page, 0 extracted)
[x] Inclusions — 12 items
[x] Exclusions — 8 items
[ ] FAQs — MISSING (5 Q&A visible on page)
[x] Highlights — 9 items
[ ] Trip Notes — MISSING (diff-confirmed: unique to this page but stripped)

Noise Filtering:
[x] Header/footer — filtered
[x] Reviews — filtered (diff-confirmed: shared across pages)
[ ] "Similar Tours" — LEAKED into 'other' (diff-confirmed: shared = noise)

Ambiguous (need your input):
- "Meet Your Guide" section — main content or noise?
  (diff says: UNIQUE to this page → likely main content)
```

**If there are ambiguous items, STOP and ask the user.** Dual-page diff provides a strong hint but user decides.

**If everything is extracted correctly, report success and stop.**

### Step 4: Diagnose Root Cause

For each issue, examine the pipeline artifacts:

```bash
# Check what the DOM cleaner produced
ls apps/importer/backend/captures/<domain>/

# Compare scraped.html vs dom.html
# Look at what was cleaned vs what remains

# Run classification standalone to see how blocks were classified
cd apps/importer/backend && node -e "
  var fs=require('fs');
  var BE=require('./dist/modules/parser/services/block-extractor.service').BlockExtractorService;
  var RC=require('./dist/modules/parser/services/rule-based-classifier.service').RuleBasedClassifierService;
  var html=fs.readFileSync('captures/<domain>/<latest>/dom.html','utf8');
  var be=new BE(); var rc=new RC();
  var blocks=be.extractBlocks(html);
  var result=rc.classify(blocks);
  result.classified.forEach(c => console.log(c.category, '|', c.name, '|', c.heading?.substring(0,60)));
"
```

Identify which pipeline stage caused the issue:
- **DOM Cleaner** removed it too aggressively → content never reached classifier
- **Classifier** miscategorized it → content routed wrong
- **Section Extractor** couldn't parse the structure → content lost during assembly
- **Page Interaction** didn't expand accordion/tab → content not in DOM at all

### Step 5: Diagnose & Fix Semantically

#### 5a. Analyze DOM Structure First

Before writing any fix, understand WHY the issue exists structurally:

```bash
# Examine the scraped HTML structure
cd apps/importer/backend
node -e "
  const cheerio = require('cheerio');
  const fs = require('fs');
  const html = fs.readFileSync('captures/<domain>/<date>/<hash>/scraped.html', 'utf8');
  const \$ = cheerio.load(html);
  // Check semantic landmarks around the problem content
  // Look for: <aside>, <nav>, <footer>, <header>, ARIA roles, CMS layout containers
"

# Compare scraped.html vs dom.html to see what the cleaner kept/removed
# Check heading hierarchy in dom.html
# Identify structural patterns: repeated sibling cards, widget containers, sidebar wrappers
```

**Ask: WHY is this content noise/missing structurally, not WHAT it contains.**
- Noise image in a sidebar? → Strip the sidebar container (`#sidebar`, `aside`, `.widget-area`), not the image
- Duplicate content? → Find the responsive/mobile duplicate wrapper, strip that
- Missing accordion content? → Fix page interaction to expand it, not the classifier

#### 5b. Apply Fixes — Semantic Priority Order

1. **SEMANTIC** — HTML5 landmarks, heading hierarchy, ARIA roles
   - Strip `<aside>`, `<nav>`, `<footer>` that wrap noise
   - Use `[role="complementary"]`, `[role="navigation"]` selectors
   - Leverage heading hierarchy — noise sections often break the h1→h2→h3 flow

2. **STRUCTURAL** — DOM shape detection
   - Repeated sibling cards (3+ cards with same structure = related tours/reviews)
   - Widget containers (CMS sidebar, booking widgets, pricing blocks)
   - Strip the **container**, not individual items — catches all noise in that area

3. **CLASSIFIER** — Heading pattern rules in `rule-based-classifier.service.ts`
   - Only when semantic/structural signals don't exist
   - Add to `headingRules` array with appropriate confidence

4. **DOM CLEANER** — Noise selectors or heading patterns in `dom-cleaner.service.ts`
   - Add CMS-specific selectors (e.g., `#boxs`, `.sidebar-widget`, `[data-widget]`)
   - Add noise heading patterns for domain-wide marketing copy

5. **SECTION EXTRACTOR** — Content routing in `tour-section-extractor.service.ts`
   - Fix how content is assigned to sections, not what's included/excluded

**NEVER use filename/keyword heuristics** (e.g., matching image filenames to domain names).
If content is semantically ambiguous (e.g., "travel insurance" can be included or excluded),
trust the DOM classification instead of forcibly moving it.

#### 5c. Key Files

| Layer | File |
|-------|------|
| DOM Cleaning | `apps/importer/backend/src/modules/capture/services/dom-cleaner.service.ts` |
| Page Interaction | `apps/importer/backend/src/modules/capture/services/page-interaction.service.ts` |
| Classification | `apps/importer/backend/src/modules/parser/services/rule-based-classifier.service.ts` |
| Section Parsing | `apps/importer/backend/src/modules/parser/services/tour-section-extractor.service.ts` |
| Heading Patterns | `apps/importer/backend/src/modules/shared/heading-patterns.ts` |
| Content Density | `apps/importer/backend/src/modules/capture/services/content-density-scorer.service.ts` |
| Schema Assembly | `apps/importer/backend/src/modules/assembler/services/schema-assembler.service.ts` |

**Check existing patterns first** — grep for how similar noise/content is already handled before adding new rules.

#### 5d. Common Semantic Fix Patterns

**New noise container → DOM Cleaner noiseSelectors:**
```typescript
'[class*="sidebar"]', '[id*="widget-area"]', '[role="complementary"]',
```

**New noise heading → DOM Cleaner Phase 2e:**
```typescript
// In noiseHeadingPatterns array:
/^your\s+new\s+pattern/i,
```

**New ignore classification → Classifier headingRules:**
```typescript
{ category: 'ignore', pattern: /\bnew\s*pattern\b/i, confidence: 'high', name: 'ignore:new', skipGuard: true },
```

**Missing accordion/tab content → Page Interaction:**
```typescript
// Add expansion trigger for new accordion pattern
```

**Image noise → Strip the container, not the image:**
```typescript
// WRONG: filter by image filename or domain
// RIGHT: remove the widget/sidebar/card container holding the image
'[class*="booking-widget"]', '.related-tours-container',
```

### Step 6: Verify

After each fix:

```bash
# 1. Build
cd apps/importer/backend && pnpm run build

# 2. Type-check
npx tsc --noEmit

# 3. Run tests
npx jest --config jest.unit.config.js --no-coverage

# 4. Re-run pipeline for the URL
curl -s -X POST http://localhost:3030/api/importer/v1/playground/pipeline \
  -H "Content-Type: application/json" \
  -d '{"url": "<URL>", "force": true}'

# 5. Compare again — did the fix work?
```

**Iterate Steps 5-6 up to 3 times.** If still broken after 3 cycles, report remaining issues to user.

### Step 7: Final Summary

```
Fixed extraction for <URL>:
- [what was fixed, one bullet per change]
- All tests passing (N total, 0 regressions)
- Sections now extracting: overview, itinerary (8 days), FAQs (5), inclusions, exclusions
```

---

## Rules

1. **Use `playwright-cli` via Bash** — never Playwright MCP tools
2. **Foreground agents** — user wants to see progress
3. **ASK on ambiguous content** — never guess, always confirm with user
4. **Never modify E2E snapshots** under `test/e2e/snapshots/`
5. **Semantic/structural fixes first** — avoid filename/keyword heuristics
6. **Check existing patterns** before adding new approaches
7. **Zero regressions** — all existing tests must pass
8. **Max 3 fix iterations** — report remaining issues if stuck
9. **Delete cached scraped.html** before re-testing (forces fresh pipeline run)
10. **Build before re-test** — `pnpm run build` after code changes (pipeline runs from `dist/`)
11. **2 URLs > 1 URL** — when available, always use dual-page diff for high-confidence noise detection
12. **Diff drives fixes** — don't guess what's noise, let the diff prove it, then fix semantically
13. **Same section type ≠ noise** — FAQs, inclusions, exclusions, categories appear on every tour page but with different content per tour. Compare actual TEXT CONTENT (>90% similarity = noise, <90% = main content), never classify by section presence alone
