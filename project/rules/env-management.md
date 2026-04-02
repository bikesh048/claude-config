---
paths:
  - "gocd/env/*"
  - ".env*"
  - "scripts/envctl.mjs"
  - "apps/*/.env*"
  - "apps/*/backend/.env*"
  - "apps/*/frontend/.env*"
  - "apps/*/web/.env*"
---

# Environment Variable Management Rules

- Use `envctl` to add/remove/update env vars — never edit .list or .env.example manually
- `.list` files: one var per line, `?` prefix = optional, `#` = comment
- Shared vars (>1 service) go in root `.env`, service-specific in `apps/{svc}/.env`
- Sensitive vars (SECRET/KEY/PASSWORD/TOKEN) never written to `.env.example` values
- GoCD is the source of truth for develop/staging/prod values
- `generate-env-service.sh` reads .list files at deploy time — do not modify its behavior
