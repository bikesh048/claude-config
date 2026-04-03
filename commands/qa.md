# QA — Verify Implementation

> Inspired by gstack's /qa command.

Verify the current branch's changes work correctly through automated and manual checks.

## Usage

```
/qa                    # Full QA on current branch
/qa <feature>          # Focus QA on specific feature
```

## Workflow

### 1. Gather scope

```bash
git diff ${BASE_BRANCH}...HEAD --stat
git log --oneline ${BASE_BRANCH}..HEAD
```

Identify what changed — files, modules, features affected.

### 2. Automated checks

Run in order, stop on failure:

```bash
# Type check
pnpm run type-check

# Unit tests
pnpm run test:unit

# Lint
pnpm run lint
```

### 3. Acceptance criteria check

If on a ticket branch (OP#XXXX):
- Fetch ticket via `/op` to get acceptance criteria
- Walk through each AC item
- Verify each passes based on the code changes

### 4. Edge case review

Review the changes for:
- **Null/undefined handling** — what happens with missing data?
- **Error paths** — are errors handled gracefully?
- **Boundary conditions** — empty arrays, max values, concurrent access?
- **Regression risk** — could this break existing functionality?

### 5. Browser verification (if UI changes)

If changes affect UI:
```
playwright-cli open "http://localhost:3000"
playwright-cli snapshot
# Verify visual output matches expectations
playwright-cli screenshot --filename=qa-verification.png
```

### 6. Report

```
## QA Report

**Branch:** <branch-name>
**Changes:** <N files, M lines>

### Automated Checks
- [ ] Type check: PASS/FAIL
- [ ] Unit tests: PASS/FAIL (X/Y passed)
- [ ] Lint: PASS/FAIL

### Acceptance Criteria
- [ ] AC 1: description — PASS/FAIL
- [ ] AC 2: description — PASS/FAIL

### Edge Cases
- <any issues found>

### Verdict: READY / NEEDS FIXES
```

## Rules

- Never skip automated checks
- If tests fail, fix before proceeding
- Report findings honestly — don't rubber-stamp
