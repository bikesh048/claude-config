# Ship — Pre-Ship Pipeline

Full pre-ship checklist: sync, test, coverage check, push, and create PR.

## Usage

```
/ship                              # Ship current branch
```

## Workflow

### 1. Pre-flight checks

```bash
# Ensure clean working tree
git status --porcelain

# Sync with base branch
git fetch origin ${BASE_BRANCH}
git rebase origin/${BASE_BRANCH}
```

If working tree is dirty, ask to commit or stash first.
If rebase has conflicts, stop and ask.

### 2. Type check

```bash
pnpm run type-check
```

Fix any errors before proceeding.

### 3. Tests

```bash
pnpm run test:unit
```

If tests fail:
- Show the failures
- Attempt to fix (up to 2 tries)
- If still failing, stop — don't ship broken code

### 4. Lint

```bash
pnpm run lint
```

Auto-fix what's possible, report what's not.

### 5. Coverage check

If coverage tool is available:
```bash
pnpm run test:coverage
```

Report coverage delta:
```
Coverage: 82% (was 80% — +2%)
New files: 3 covered, 0 uncovered
```

Warn if coverage dropped.

### 6. Push

```bash
git push -u origin $(git branch --show-current)
```

### 7. Create PR

Run `/pr` which handles:
- Code review (mandatory)
- PR creation with template
- OP ticket linking

### 8. Summary

```
Ship complete:
  Branch: feature/1822-dashboard
  Tests: 142/142 passed
  Coverage: 82% (+2%)
  PR: https://github.com/org/repo/pull/155
```

## Rules

- Never ship with failing tests
- Never skip type-check
- Always rebase on latest base branch before shipping
- If coverage drops, add tests before shipping
