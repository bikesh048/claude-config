---
paths:
  - "apps/builder/frontend/src/**/*.ts"
  - "apps/builder/frontend/src/**/*.tsx"
---

# Builder Frontend Rules

- State management via Zustand — keep stores small and focused
- Styling with CSS Modules — no global CSS leaks
- Test files as `*.test.tsx` with `@testing-library/react`
- Use `jest-environment-jsdom` for component tests
- Block content is Gutenberg JSON — never mutate block data in-place, create new objects
