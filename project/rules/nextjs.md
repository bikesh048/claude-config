---
paths:
  - "apps/tour/web/**/*.ts"
  - "apps/tour/web/**/*.tsx"
---

# Tour Web (Next.js) Rules

- Server-side vars use `API_BASE_URL`, client-side use `NEXT_PUBLIC_` prefix
- Test with Jest + `@testing-library/react`
- Never expose server-side secrets via `NEXT_PUBLIC_` variables
- Use `ASSET_PREFIX` for CDN-served static assets
- `CORS_ALLOW_ORIGIN` must match the public site URL
