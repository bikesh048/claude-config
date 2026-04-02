# Dispatch — Parallel Agent Task Runner

Fully autonomous: accepts tasks, detects conflicts, dispatches agents, creates PRs, updates tickets. No confirmation needed.

## Usage

```
/dispatch
task1: OP#1234 fix the broken image upload
task2: OP#1235 extraction fix for amazingcanoeing.com
task3: OP#1240 add redis TTL config to media module [opus]
```

Single task shorthand:
```
/dispatch OP#1234 fix the broken image upload
```

## Input: $ARGUMENTS

## Task Parsing

Each task line is parsed for:
- **Ticket ID**: `OP#NNNN` (optional)
- **Description**: free text
- **Model override**: `[sonnet]` or `[opus]` at end of line (optional)
- **Type** (auto-detected):

| Signal | Type | Default Model |
|--------|------|---------------|
| URL + "extraction" or playground output | `extraction` | Sonnet |
| OP ticket + bug/fix keywords | `bugfix` | Opus |
| OP ticket + feat/add/implement keywords | `feature` | Opus |
| No OP ticket, just description | `adhoc` | Sonnet |

Model override `[opus]` or `[sonnet]` takes precedence over auto-selection.

If only one task is given (no `task1:` prefix), treat it as a single task.

## Service Detection

Auto-detect which service a task targets from description keywords, then include the service CLAUDE.md in the agent prompt:

| Keywords | Service | Context File |
|----------|---------|--------------|
| extraction, scrape, pipeline, DOM, Puppeteer, tour operator URL | importer backend | `apps/importer/backend/CLAUDE.md` |
| page, block, editor, Gutenberg, pattern, SSR, header, footer (backend) | builder backend | `apps/builder/backend/CLAUDE.md` |
| page, block, editor, Gutenberg, pattern (frontend/UI) | builder frontend | `apps/builder/frontend/CLAUDE.md` |
| media, upload, image, CDN, S3 | builder backend | `apps/builder/backend/CLAUDE.md` |
| search, filter, translation, currency, global settings (API) | tour backend | `apps/tour/backend/CLAUDE.md` |
| tour listing, tour card, tour page UI | tour web | `apps/tour/web/CLAUDE.md` |
| types, constants, database, prisma schema, shared | packages | `packages/CLAUDE.md` |

If unclear whether backend or frontend, include both. If a task spans services, include all relevant context files.

Each agent prompt MUST include: "Read `<context file>` for service-specific architecture, module map, and troubleshooting guide."

## Workflow

### 1. Validate

- Working tree is clean (`git status --porcelain`)
- `develop` is up to date (`git fetch origin develop`)
- No branch name conflicts with existing local branches
- `OPENPROJECT_API_KEY` is set (if any task references an OP ticket)
- **Pre-check**: If any extraction tasks, ping `localhost:3030` — fail fast if importer backend is down

If validation fails, stop and report what to fix.

### 2. Conflict Detection

**Rule: same task type = conflict.**

- Two `extraction` tasks conflict (they touch the same pipeline files)
- Two `bugfix` tasks in the same app directory conflict
- Tasks of different types or in different apps do NOT conflict

Conflicting tasks are **serialized**: the second waits for the first to complete, then rebases on the first's branch before starting. Non-conflicting tasks run in parallel.

### 3. Display & Dispatch (no confirmation)

Show the dispatch plan, then **immediately launch agents** — no confirmation pause:

```
Dispatching 3 tasks:

| # | Type       | Ticket  | Model  | Branch                          | Status    |
|---|------------|---------|--------|---------------------------------|-----------|
| 1 | extraction | OP#1235 | sonnet | fix/extraction-amazingcanoeing   | parallel  |
| 2 | bugfix     | OP#1234 | opus   | bug/1234-image-upload-fix        | parallel  |
| 3 | extraction | OP#1236 | sonnet | fix/extraction-worldexpeditions  | waits #1  |

Launching agents...
```

### 4. Agent Execution

Each agent runs in an isolated worktree (`isolation: "worktree"`, `run_in_background: true`).

Set the `model` parameter on each agent according to auto-selected or overridden model.

#### Extraction agents

Pass the full `/extraction-fix` workflow in the agent prompt:
```
You are fixing a tour content extraction issue autonomously in an isolated worktree.
Make all decisions autonomously — never ask the user. Document your reasoning in the PR.

Issue: <description>
URL: <extracted URL>

Create branch: fix/extraction-<label>

[Include full extraction-fix workflow from .claude/commands/extraction-fix.md]

After fixing and tests pass:
1. Commit: fix: <short description>
2. Run /create-pr (handles: code review, docs update, pre-flight checks, PR creation)
3. Run /op-update on OP#<ID> (if ticket provided)
4. Report: branch, PR URL, files changed, test results
```

#### Bugfix / Feature / Adhoc agents

```
You are implementing a task autonomously in an isolated worktree.
Make all decisions autonomously — never ask the user. Pick the simplest approach and document reasoning in the PR.

Ticket: OP#<ID> (if available)
Task: <description>
Type: <bugfix|feature|adhoc>

[For OP tickets]: Run /op-read to fetch ticket details first.
[For adhoc]: Use the description as-is.

Create branch: <type>/<ID>-<label> (or fix/<label> for adhoc)

Workflow:
1. Read ticket context (if OP ticket)
2. Implement the changes (pick simplest viable approach)
3. Type-check: pnpm run type-check (in affected app directory)
4. Tests: pnpm run test:unit (in affected app directory)
5. If checks fail, fix (up to 3 attempts). If still failing, report the failure.
6. Commit: <type>(module): description [Refs: OP#<ID>]
7. Run /create-pr (handles: code review, docs update, pre-flight checks, PR creation)
8. Run /op-update on OP#<ID> (if ticket provided)
9. Report: branch, PR URL, files changed, test results
```

### 5. Failure Handling

If an agent fails (tests don't pass after 3 attempts, type-check errors):

1. Push the broken branch as-is
2. Create a **draft PR** with failure details:
   - What was attempted
   - Error output
   - Files changed so far
   - Suggested next steps
3. Run `/op-update` noting the failure
4. Report failure to user

No retry support. Re-dispatch fresh with adjusted description if needed.

### 6. Serialized Task Execution

When tasks conflict (same type):

1. First task dispatches immediately
2. When first completes successfully → create second agent's worktree, rebase on first's branch, then run
3. If first fails → still run second (from develop, not the failed branch), warn that first's changes are not included

### 7. Notifications

- **Per-agent**: Notify as each agent completes (one line: status + PR link)
- **Final summary**: When ALL agents done, show complete results table:

```
All 3 tasks complete:

| # | Status | PR                                    | Branch                          |
|---|--------|---------------------------------------|---------------------------------|
| 1 | PR     | https://github.com/org/repo/pull/51   | fix/extraction-amazingcanoeing  |
| 2 | PR     | https://github.com/org/repo/pull/52   | bug/1234-image-upload-fix       |
| 3 | DRAFT  | https://github.com/org/repo/pull/53   | fix/extraction-worldexpeditions |

Ready for review: PR #51, PR #52
Needs attention: PR #53 (draft — tests failing)
```

## Rules

1. **Single source of truth** — delegate to `/extraction-fix`, `/create-pr`, `/op-update`. Never duplicate their logic.
2. **Fully autonomous** — agents never ask the user. Pick simplest approach, document reasoning in PR.
3. **Worktree isolation** — never modify the user's working tree
4. **Background execution** — user is free to do other work
5. **Unique branch names** — ticket ID + label to avoid conflicts
6. **Never skip tests** — type-check + tests mandatory before any PR
7. **Never modify snapshots** — snapshots are ground truth
8. **PR to develop** — always target develop branch
9. **One task = one agent = one branch = one PR** — atomic units of work
10. **Pre-check importer server** — fail fast for extraction tasks if localhost:3030 is down
11. **Auto-update OP tickets** — each agent runs `/op-update` after PR creation
12. **Draft PR on failure** — push broken branch + draft PR with diagnostics, never silently discard work
