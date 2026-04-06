# Learn — Cross-Session Memory

Capture patterns, preferences, and pitfalls from the current session for future use.

## Usage

```
/learn                             # Review session and extract learnings
/learn "<pattern>"                 # Save a specific pattern
/learn list                        # Show all saved learnings
```

## Input: $ARGUMENTS

## Routing

| Input | Action |
|-------|--------|
| _(no args)_ | Auto-extract from session |
| `"<pattern>"` | Save specific pattern |
| `list` | Show saved learnings |

## Action: Auto-Extract

Review the current session for:
- Solutions that took multiple attempts (the final approach is the learning)
- Non-obvious API behaviors discovered
- Debugging techniques that worked
- Configuration gotchas
- Performance optimizations found

Save each as a memory file:

```markdown
# .claude/memories/<slug>.md
---
name: <descriptive-name>
description: <one-line searchable description>
---

## Context
<When does this apply?>

## Pattern
<What to do>

## Anti-pattern
<What NOT to do — the mistake that led to this learning>
```

## Action: Save Specific

```
/learn "prisma needs explicit select for relations"
```

Creates:
```markdown
# .claude/memories/prisma-explicit-select-relations.md
---
name: prisma-explicit-select-relations
description: Prisma requires explicit select/include for relation fields
---

## Pattern
Always use `include` or `select` when querying relations in Prisma.
Relation fields are not loaded by default.

## Anti-pattern
Assuming relation data is available without include — returns null silently.
```

## Action: List

Show all saved learnings from `.claude/memories/`:

```
Saved learnings:
  1. prisma-explicit-select-relations — Prisma requires explicit select for relations
  2. validate-git-state-before-ops — Always check git status before file operations
  3. alternative-paths-guidance — Consider alternative approaches before committing
```

## Rules

- Keep learnings atomic — one insight per file
- Include the anti-pattern (what went wrong) — it's as valuable as the fix
- Use searchable descriptions — Claude loads these by relevance
- Don't save obvious things — only non-obvious patterns worth remembering
- Review and prune periodically — stale learnings add noise
