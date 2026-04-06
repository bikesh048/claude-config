---
name: tech-debt
description: Identify, catalog, and prioritize technical debt in the codebase. Suggests actionable fixes.
---

# Tech Debt — Identify and Prioritize

Scan the codebase for technical debt and produce an actionable report.

## Usage

```
/tech-debt                         # Scan current project
/tech-debt <path>                  # Scan specific directory
```

## What to Look For

### Code Smells
- Functions > 50 lines
- Files > 800 lines
- Deep nesting (> 4 levels)
- Duplicated logic across files
- God classes/modules (too many responsibilities)
- Magic numbers and hardcoded strings

### Dependency Issues
- Outdated packages (major versions behind)
- Unused dependencies
- Packages with known vulnerabilities
- Circular dependencies

### Architecture Debt
- Missing abstractions (repeated patterns not extracted)
- Tight coupling between modules
- Missing or incomplete interfaces
- Inconsistent patterns across similar modules

### Test Debt
- Missing tests for critical paths
- Flaky tests
- Low coverage areas
- Tests that test implementation, not behavior

### Documentation Debt
- Missing API docs for public functions
- Outdated README or architecture docs
- Missing CLAUDE.md for modules
- Undocumented env variables or config

## Report Format

```
## Tech Debt Report — <project/path>

### Critical (fix now)
| File | Issue | Impact |
|------|-------|--------|
| ... | ... | ... |

### High (fix this sprint)
| File | Issue | Impact |
|------|-------|--------|
| ... | ... | ... |

### Medium (backlog)
| File | Issue | Impact |
|------|-------|--------|
| ... | ... | ... |

### Metrics
- Total debt items: N
- Estimated effort: X hours
- Coverage gaps: Y files
- Outdated deps: Z packages
```

## Rules

- Prioritize by impact, not by count
- Focus on debt that slows down current work
- Suggest concrete fixes, not vague improvements
- Don't flag intentional trade-offs as debt
