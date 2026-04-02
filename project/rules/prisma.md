---
paths:
  - "**/*.prisma"
  - "**/dao/**/*.ts"
  - "**/prisma/**/*.ts"
---

# Prisma & Database Rules

- Prisma models use `@@map` to match existing Laravel table names
- Avoid N+1 queries — use `include` for relations, never loop with `findUnique`
- Use MySQL-specific types where needed (`@db.LongText`, etc.)
- DAOs extend `BaseDao<T>` — never call `prisma` directly from services
- `@tripcart/database` is shared across all backends via same MySQL connection
- Never create circular dependencies between packages
