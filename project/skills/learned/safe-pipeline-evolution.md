---
name: safe-pipeline-evolution
description: "Phased importer pipeline changes with snapshot regression guards — add stages, remove modules, enhance classifiers safely"
user-invocable: false
origin: auto-extracted
---

# Safe Pipeline Evolution Pattern

**Extracted:** 2026-03-28
**Context:** Evolving the importer extraction pipeline (adding/removing stages, enhancing classifiers) without breaking 24+ URL snapshot regression tests

## Problem
The importer pipeline has 3000+ snapshot regression tests across 24 URLs. Architectural changes (removing modules, adding stages, enhancing classifiers) risk breaking these tests. Need a safe approach to make large changes incrementally.

## Key Insight: Dual Pipeline Architecture
The snapshot tests use `scripts/lib/pipeline-runner.ts` which directly instantiates services — it does NOT use `AssemblerService.runDeterministicPipeline()`. This means:
- Changes to `assembler.service.ts` (production path) don't affect snapshot tests
- New services added to the assembler pipeline (e.g., DeduplicationService) won't break tests
- But changes to individual services (classifier, section extractor, metadata) DO affect tests since pipeline-runner uses them directly

## Solution: Phased Evolution with Guards

### Phase pattern
1. **Remove/simplify first** — Delete dead code (enrichment module) before adding new code. Fewer moving parts = easier debugging.
2. **Add new capabilities as post-processing** — New classifier signals (weighted cascade) run AFTER existing classification, only touching previously-unclassified blocks. Existing classifications are untouched.
3. **New pipeline stages go in assembler only** — DeduplicationService was added between classify→section-extract in the assembler but NOT in pipeline-runner.ts. Production benefits without test impact.

### Verification gate per phase
```bash
# 1. Type-check (catches import/interface breaks)
cd apps/importer/backend && pnpm run type-check

# 2. Full unit + snapshot tests (catches behavioral regressions)
pnpm run test:unit  # 3112 tests including 3070 snapshots

# 3. Docker build (catches production compilation issues)
docker compose build importer-backend

# 4. Docker health check
docker compose up importer-backend -d
docker compose ps importer-backend  # verify "healthy"
```

### Safe change categories
| Change Type | Affects Snapshots? | Approach |
|---|---|---|
| Delete unused module | No (if not in pipeline-runner) | Remove imports, delete files, type-check |
| Add new pipeline stage | No (assembler-only) | Add to assembler, skip pipeline-runner |
| Enhance existing service | YES | Add as post-processing, only affect unclassified blocks |
| New heading rules | YES | Must produce same or better results for all 24 URLs |
| Change service interface | YES | Update both assembler AND pipeline-runner |

## When to Use
- Adding a new pipeline stage (dedup, validation, enrichment)
- Removing a module or service from the pipeline
- Enhancing the classifier with new signals
- Any architectural change to the importer extraction pipeline
