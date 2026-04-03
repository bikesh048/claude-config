# Commit Format

## Message Template

```
<type>(<scope>): <description>

<optional body>

Refs: OP#<ticket_id>
```

## Types

| Type | When |
|------|------|
| `feat` | New feature |
| `fix` | Bug fix |
| `refactor` | Code restructuring (no behavior change) |
| `docs` | Documentation only |
| `test` | Adding or updating tests |
| `chore` | Tooling, config, dependencies |
| `perf` | Performance improvement |
| `ci` | CI/CD changes |

## Rules

- **Scope** is the module or area (e.g. `auth`, `pipeline`, `api`)
- **Description** is imperative mood, lowercase, no period: "add caching" not "Added caching."
- **Refs line** links to the OP ticket if available
- **No Co-Authored-By** — attribution disabled globally
- **Phase commits** during `/deliver`: `feat(envctl): add CLI dispatcher (phase 1/4)`
- **Single-line** for small fixes, body for larger changes explaining why

## Examples

```
fix(pipeline): handle null response from tour API

The extraction pipeline crashed when the API returned null for
removed tours. Now returns empty result instead of throwing.

Refs: OP#1790
```

```
feat(auth): add session timeout configuration
```

```
chore: update prisma to 6.2.0
```
