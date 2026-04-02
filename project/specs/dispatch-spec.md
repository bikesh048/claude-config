# /dispatch — Parallel Agent Task Runner Spec

## Overview

A single command that accepts multiple tasks, detects conflicts, and dispatches each to an isolated worktree agent that autonomously implements, tests, creates a PR, and updates the OpenProject ticket. No human confirmation required — fully autonomous from input to PR.

## Input Format

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

### Task Parsing

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

Model override syntax `[opus]` or `[sonnet]` takes precedence over auto-selection.

## Execution Flow

### 1. Validate

- Working tree is clean (`git status --porcelain`)
- `develop` is up to date (`git fetch origin develop`)
- No branch name conflicts with existing local branches
- `OPENPROJECT_API_KEY` is set (if any task references an OP ticket)
- **Pre-check**: Ping `localhost:3030` if any extraction tasks are present — fail fast if importer backend is down

If validation fails, stop and report what to fix.

### 2. Conflict Detection

**Rule: same task type = conflict.**

- Two `extraction` tasks conflict (they touch the same pipeline files)
- Two `bugfix` tasks in the same app directory conflict
- Tasks of different types or in different apps do NOT conflict

Conflicting tasks are serialized: the second waits for the first to complete, then rebases on the first's branch before starting.

Non-conflicting tasks run in parallel.

### 3. Display & Dispatch (no confirmation)

Show the dispatch plan table, then immediately launch agents:

```
Dispatching 3 tasks:

| # | Type       | Ticket  | Model  | Branch                        | Status    |
|---|------------|---------|--------|-------------------------------|-----------|
| 1 | extraction | OP#1235 | sonnet | fix/extraction-amazingcanoeing | parallel  |
| 2 | bugfix     | OP#1234 | opus   | bug/1234-image-upload-fix      | parallel  |
| 3 | extraction | OP#1236 | sonnet | fix/extraction-worldexpeditions | waits #1 |

Launching agents...
```

No confirmation pause. Display is informational only.

### 4. Agent Execution

Each agent runs in an isolated worktree (`isolation: "worktree"`, `run_in_background: true`).

#### Extraction agents

1. Run the full `/extraction-fix` workflow (parse → diagnose → fix → verify)
2. Commit: `fix: <short description>`
3. Run `/create-pr` (code review, docs update, pre-flight checks, PR creation)
4. Run `/op-update` on the ticket (if OP ticket provided)
5. Report results

#### Bugfix / Feature / Adhoc agents

1. Read ticket context via `/op-read` (if OP ticket)
2. Pick simplest approach autonomously — no asking, document reasoning in PR
3. Implement changes
4. Type-check + unit tests (fix up to 3 attempts)
5. Commit with conventional message: `<type>(module): description [Refs: OP#<ID>]`
6. Run `/create-pr` (code review, docs update, pre-flight checks, PR creation)
7. Run `/op-update` on the ticket (if OP ticket provided)
8. Report results

#### Autonomy rules

- Agents **never ask** the user questions mid-task
- They pick the simplest viable approach and document their reasoning in the PR description
- User reviews the decision during PR review

### 5. Failure Handling

If an agent fails (tests don't pass after 3 attempts, type-check errors):

1. Push the broken branch as-is
2. Create a **draft PR** with failure details in the description:
   - What was attempted
   - Error output
   - Files changed so far
   - Suggested next steps
3. Run `/op-update` noting the failure
4. Report failure to user

**No retry support.** If a task fails, inspect the draft PR, then re-dispatch fresh with an adjusted description if needed.

### 6. Notifications

- **Per-agent**: Brief notification as each agent completes (one line: status + PR link or failure summary)
- **Final summary**: When ALL agents are done, show complete results table:

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

## Serialized Task Execution

When tasks conflict (same type):

1. First task dispatches immediately
2. When first task completes successfully:
   - Create the second agent's worktree
   - Rebase on the first task's branch
   - Then run the second task
3. If first task fails:
   - Still run the second task (from develop, not the failed branch)
   - Warn that the first task's changes are not included

## Key Constraints

1. **Single source of truth**: Delegate to `/extraction-fix`, `/create-pr`, `/op-update` — never duplicate their logic
2. **Worktree isolation**: Never modify user's working tree
3. **Background execution**: User is free to do other work
4. **Unique branch names**: Ticket ID + label to avoid conflicts
5. **Never skip tests**: Type-check + tests mandatory before any PR
6. **Never modify snapshots**: Snapshots are ground truth
7. **PR to develop**: Always target develop branch
8. **One task = one agent = one branch = one PR**: Atomic units of work
9. **Pre-check importer server**: Fail fast for extraction tasks if localhost:3030 is down
10. **Auto-update OP tickets**: Each agent runs `/op-update` after PR creation

## Structure

Single command file: `.claude/commands/dispatch.md`

No promotion to skill needed until complexity warrants it. Follows the project principle: no premature abstraction.
