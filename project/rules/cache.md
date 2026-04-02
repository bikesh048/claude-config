---
paths:
  - "apps/builder/backend/src/modules/pages/**/*.ts"
  - "apps/builder/backend/src/modules/patterns/**/*.ts"
---

# Cache Invalidation Rules

- PageCache and block-level cache must be invalidated on publish/update
- Individual blocks are stored in `page_blocks` with cached rendered HTML
- Cache invalidation must cascade: page update -> page_blocks cache -> PageCache
- Never serve stale cached HTML after a content change
