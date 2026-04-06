# Pull Request

Full PR workflow: review changes, update docs if needed, push, and create/update PR using the project template.

## Usage

```
/pr
```

## Workflow

### 1. Analyze changes

```bash
git status
git log --oneline ${BASE_BRANCH}..HEAD
git diff ${BASE_BRANCH}...HEAD --stat
```

Understand the full scope of changes (all commits, not just the latest).

### 2. Code review and fix (MANDATORY — DO NOT SKIP)

**This step is a BLOCKING prerequisite.** You MUST run the code review before proceeding to pre-flight checks or PR creation.

Run **code-reviewer** agent on the full diff (`git diff ${BASE_BRANCH}...HEAD`):

```bash
# Pass the diff scope to the reviewer
git diff ${BASE_BRANCH}...HEAD
```

- Fix all CRITICAL and HIGH issues immediately
- Fix MEDIUM issues when possible
- For large feature branches (10+ files or 500+ lines changed), also run **architecture-audit** agent
- If fixes are made, commit them before proceeding

**Do not continue to step 3 until all review issues are resolved.** If the user says "skip review", confirm explicitly — never silently skip.

### 3. Pre-flight checks

- **TypeScript**: `npx tsc --noEmit` must pass
- **Tests**: Run relevant test suite, confirm no regressions introduced by this branch
- **Linting**: `pnpm run lint` if available

If any check fails, fix the issue and commit before proceeding.

### 4. Update docs (if needed)

Check whether changes affect documented architecture:

- **`CLAUDE.md`** — Module structure, file descriptions, rule counts, pipeline descriptions
- **`docs/extraction-pipeline-design.md`** — Pipeline stages, shared utilities, module descriptions
- **`docs/TOUR_IMPORT_ARCHITECTURE.md`** — High-level architecture changes

Only update what's essential — module structure, new files, changed capabilities. Don't over-document.

### 5. Rebase on latest base branch

```bash
git fetch origin ${BASE_BRANCH}
git rebase origin/${BASE_BRANCH}
```

Resolve any conflicts during the rebase. If conflicts are found, fix them, run `git rebase --continue`, and re-run pre-flight checks (step 3) to ensure nothing broke.

### 6. Get OP ticket number

Extract from branch name (e.g., `bug/1727-fix-for-...` → `#1727`) or ask the user.

### 7. Push and create PR

```bash
git push -u origin <branch-name>
```

Use `gh pr create` with this template (matches `.github/pull_request_template.md`):

```
gh pr create --base ${BASE_BRANCH} --title "<type>: <short description>" --body "$(cat <<'PREOF'
## Ticket
[OP#XXXX](${OP_BASE_URL}/projects/${OP_PROJECT_SLUG}/work_packages/XXXX/activity)

## Summary
<Brief description of what changed and why>

## QA / Testing Done
- [ ] Manual test on Chrome/Safari
- [x] Automated tests pass
- [ ] Screenshots/Video attached

## Deployment Notes
- Env variables needed: No
- Migrations needed: No
PREOF
)"
```

If a PR already exists for the branch, use `gh pr edit <number>` instead.

### 8. Return PR URL

Always show the PR URL to the user when done.

## Rules

- **Never skip the OP ticket link** — ask the user if not derivable from branch name
- **Never invent a custom PR format** — always use the project template
- **Base branch is `${BASE_BRANCH}`** unless the user specifies otherwise
- **PR title format**: `<type>: <description>` where type is feat/fix/refactor/docs/test/chore
- **Don't force-push** unless explicitly asked
