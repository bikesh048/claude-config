# Domain Support — Visual-First Tour Extraction Workflow

Add or fix extraction support for a tour page domain. Uses visual comparison between the live page and extraction output to identify and fix issues.

## Input

User provides a tour page URL, optionally with specific issues noted.

## Workflow

### Phase 1: Capture & Visual Ground Truth

1. **Check for existing capture**:
   ```bash
   ls apps/importer/backend/captures/<domain>/ 2>/dev/null
   ```

2. **Screenshot the live page** using playwright-cli (via Bash):
   ```bash
   cd apps/importer/backend && npx playwright-cli screenshot "<URL>" --full-page
   ```
   Read the screenshot to understand the page structure: sections, headings, highlights, itinerary layout, images, trip notes, inclusions/exclusions.

3. **If no capture exists**, run capture:
   ```bash
   curl -s -X POST http://localhost:3030/api/importer/v1/playground/blocks \
     -H 'Content-Type: application/json' -d '{"url": "<URL>"}'
   ```
   If the dev server isn't running, tell the user: `cd apps/importer/backend && pnpm run dev`

### Phase 2: Extract & Compare

4. **Run the extraction pipeline** (deterministic, no LLM):
   ```bash
   cd apps/importer/backend && node -e "
   var SN=require('./dist/modules/parser/services/structure-normalizer.service').StructureNormalizerService;
   var BE=require('./dist/modules/parser/services/block-extractor.service').BlockExtractorService;
   var RC=require('./dist/modules/parser/services/rule-based-classifier.service').RuleBasedClassifierService;
   var TSE=require('./dist/modules/parser/services/tour-section-extractor.service').TourSectionExtractorService;
   var fs=require('fs');
   var sn=new SN(); var be=new BE(); var rc=new RC(); var tse=new TSE();
   var html=fs.readFileSync('captures/<domain>/<hash>/dom.html','utf8');
   var normalized=sn.normalize(html);
   var blocks=be.extractBlocks(normalized);
   var result=rc.classify(blocks);
   var sections=tse.extract(blocks,result.classified);
   // Print summary
   console.log(JSON.stringify({
     highlights: sections.highlights ? sections.highlights.length+' items' : null,
     overview: sections.overview ? sections.overview.text.length+' chars' : null,
     itinerary: sections.itinerary ? {days: sections.itinerary.days.length, sampleMeals: sections.itinerary.days[0]?.meals, sampleAccom: sections.itinerary.days[0]?.accommodation, sampleDescLen: sections.itinerary.days[0]?.description?.length} : null,
     inclusions: sections.inclusions ? sections.inclusions.items.length+' items' : null,
     exclusions: sections.exclusions ? sections.exclusions.items.length+' items' : null,
     faqs: sections.faqs ? sections.faqs.items.length+' items' : null,
     tripNote: sections.tripNote ? sections.tripNote.text.length+' chars' : null,
     other: sections.other.length+' sections',
   }, null, 2));
   "
   ```

5. **Compare screenshot vs extraction output**. Flag:
   - Sections visible on page but missing in extraction
   - Content in wrong sections
   - Empty fields (descriptions, meals, images)
   - Noise content mixed with real content
   - Images visible on page but not extracted

6. **Report findings** to user as a checklist:
   ```
   Comparing <URL> screenshot vs extraction:
   [x] Highlights — 9 items extracted
   [ ] Itinerary descriptions — empty (0 chars per day)
   [x] Inclusions — 15 items
   [ ] Trip Note — missing
   [ ] Images — missing from Mountain Flight section
   ```

### Phase 3: Fix (if issues found)

7. **Follow /extraction-fix workflow** for each issue:
   - Diagnose root cause (classifier, normalizer, section extractor)
   - Read target file before editing
   - Make targeted fixes
   - Build: `cd apps/importer/backend && pnpm run build`
   - Run ALL tests: `npx jest --config jest.unit.config.js --no-coverage`
   - Re-run extraction to verify fix
   - Zero regressions required

### Phase 4: Lock Snapshot

8. **Generate E2E regression snapshot**:
   ```bash
   cd apps/importer/backend && npx ts-node scripts/lock-e2e-snapshot.ts <domain> <hash>
   ```

9. **Review snapshot** — adjust expectations if auto-generated values are wrong (e.g., wrong tour name detection). Add `knownBugs` for pre-existing issues.

10. **Final test run** — all tests must pass including new snapshot.

## Pipeline Files Reference

| Layer | File | Purpose |
|-------|------|---------|
| DOM Cleaning | `capture/services/dom-cleaner.service.ts` | Noise removal, material icon stripping, gallery extraction |
| Page Interaction | `capture/services/page-interaction.service.ts` | Puppeteer accordion/tab expansion (incl. React SPA buttons) |
| Structure Normalization | `parser/services/structure-normalizer.service.ts` | Non-standard HTML → canonical headings |
| Block Extraction | `parser/services/block-extractor.service.ts` | HTML → ContentBlock[] |
| Classification | `parser/services/rule-based-classifier.service.ts` | Heading patterns → categories (35+ rules incl. semantic detection) |
| Section Parsing | `parser/services/tour-section-extractor.service.ts` | Blocks → TourPageSections (itinerary days, FAQ Q&A, lists) |
| Schema Assembly | `assembler/services/schema-assembler.service.ts` | Sections → final schema |
| Heuristic Metadata | `parser/services/heuristic-metadata.service.ts` | Regex metadata (name, duration, difficulty) |

### Common Fix Patterns

| Issue | Fix Location |
|-------|-------------|
| Material icon text leaking | `dom-cleaner.service.ts` Phase 0-pre2 |
| Pricing/CTA widget noise | `dom-cleaner.service.ts` noiseSelectors array |
| React accordion content not captured | `page-interaction.service.ts` step 2b |
| FAQ answers missing | Check if `force` scrape needed (React expands), then `tour-section-extractor.service.ts` Pattern 9 |
| Itinerary descriptions empty | `tour-section-extractor.service.ts` text-node fallback in Strategy 1 |
| Gallery images not extracted | `dom-cleaner.service.ts` gallerySelectors (add section[id="..."]) |
| Content misclassified | `rule-based-classifier.service.ts` heading rules or semantic detection |
| CTA text in overview | `tour-section-extractor.service.ts` removeToggleElements CTA patterns |

## Rules

- Always use `playwright-cli` via Bash for screenshots (NOT Playwright MCP tools)
- Always run ALL tests before and after fixes — zero regressions
- Check how similar sites handle the same pattern before inventing new approaches
- Never update existing E2E snapshots unless explicitly asked
- Prefer targeted fixes (narrow regex) over broad changes
- Playground must mirror assembler pipeline
- For React/SPA sites, `force: true` re-scrape may be needed to capture expanded content
