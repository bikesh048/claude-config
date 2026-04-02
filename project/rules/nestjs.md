---
paths:
  - "apps/*/backend/src/**/*.ts"
---

# NestJS Backend Rules

- Use `class-validator` decorators for all DTO validation at API boundaries
- DAOs must extend `BaseDao<T>` from `@common/dao/base.dao.ts`
- Use NestJS built-in exceptions (`NotFoundException`, `BadRequestException`, etc.) — never throw raw errors
- API responses must include `success`, `data`, `timestamp`, `requestId` fields
- Use path aliases: `@common/*`, `@modules/*`, `@/*`
- camelCase for TypeScript properties, snake_case for DB columns
- Never use `any` — use proper types (`@typescript-eslint/no-explicit-any: warn`)
- Unit tests co-located as `*.spec.ts` with mocked dependencies
- Never commit `.env.local` or `.env.production`
