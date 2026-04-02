# Command Reference

## Overview

```
/deliver  →  Single task, end-to-end (the main workflow)
/dispatch →  Multiple tasks in parallel (uses /deliver per task)
/create-pr → PR creation with code review
/op-create → Create OpenProject ticket
/op-read   → Read OpenProject ticket
/op-update → Post EOD update to ticket
/interview → Deep discovery interview before implementation
```

## /deliver

End-to-end ticket implementation. The primary workflow command.

```
/deliver OP#1790                      # Existing ticket
/deliver 1322 "build envctl"          # New ticket under parent #1322
/deliver "fix broken image upload"    # Adhoc (no ticket)
```

**Flow:** read ticket → plan + interview → branch → execute phase-by-phase → create PR → update ticket

- Only pauses for human input during planning/interview
- Commits incrementally per phase, pushes after each
- Delegates to: `/op-read`, `/interview`, `/create-pr`, `/op-update`

## /dispatch

Parallel agent task runner. Spawns isolated agents, each running `/deliver`.

```
/dispatch
task1: OP#1234 fix broken image upload
task2: OP#1235 extraction fix for amazingcanoeing.com
task3: OP#1240 add redis TTL config [opus]
```

Single task shorthand:
```
/dispatch OP#1234 fix broken image upload
```

- Auto-detects task type (bugfix, feature, extraction, adhoc)
- Auto-selects model (Sonnet/Opus) — override with `[opus]` or `[sonnet]`
- Detects conflicts between same-type tasks and serializes them
- Each agent runs in an isolated worktree
- Delegates to: `/deliver` per task

## /create-pr

Creates a GitHub PR with code review and template.

```
/create-pr
```

**Flow:** code review (mandatory) → docs update → pre-flight checks (tsc, tests) → push → create PR

- Uses `.github/pull_request_template.md`
- Links OP ticket automatically
- Architecture audit triggered if 10+ files or 500+ lines changed

## /op-create

Create an OpenProject work package.

```
/op-create <parent_id> <type> "<subject>" "[description]"
```

Types: `bug`, `task`, `tech_debt`, `story`

## /op-read

Read an OpenProject ticket and output a planning summary.

```
/op-read [ticket_id]
```

If `ticket_id` is omitted, extracts from current branch name (e.g. `bug/1723-fix-...` -> `1723`).

## /op-update

Post an EOD progress update as a comment on a ticket.

```
/op-update [ticket_id]
```

Gathers context from recent commits, fills EOD template (Progress, Next Steps, Blockers, ETA, Links), confirms with user, then posts.

## /interview

Structured discovery interview to surface gaps and tradeoffs before implementation.

```
/interview              # Interview about current work
/interview <topic>      # Interview about specific feature
```

Asks 2-4 questions per round across multiple dimensions (scope, technical, UX, edge cases). Produces a spec file in `.claude/specs/`.

## Command Relationships

```
/dispatch
  └── /deliver (per task)
        ├── /op-read (fetch ticket)
        ├── /interview (plan + discovery)
        ├── /create-pr (push + PR)
        └── /op-update (post progress)

/op-create  (standalone — create new tickets)
```
