---
paths:
  - "apps/importer/backend/src/**/*.ts"
---

# Importer Pipeline Rules

- Module dependency graph must be acyclic: AssemblerModule -> CaptureModule & ParserModule -> PrismaModule
- Never load PlaygroundModule in production — dev-only
- Pipeline is LLM-free — use structural/semantic DOM parsing, not AI extraction
- Puppeteer captures must handle SSL errors with HTTP fallback
- Never update existing E2E snapshots unless explicitly asked
