# Command Reference

## Overview

```
/op         →  OpenProject ticket operations (read, create, update)
/deliver    →  Single task, end-to-end (the main workflow)
/dispatch   →  Multiple tasks in parallel (uses /deliver per task)
/pr         →  PR creation with code review
/interview  →  Deep discovery interview before implementation
/qa         →  Verify implementation (tests, AC, edge cases)
/retro      →  Session retrospective (capture learnings)
```

## /op

OpenProject ticket manager. One command for read, create, and update.

```
/op 1790                    # Read ticket
/op create 1322             # Create ticket under parent (asks for title/type)
/op create 1322 task        # Create with specified type
/op update                  # Post EOD update (ticket from branch)
/op update 1790             # Post EOD update on specific ticket
/op                         # Read ticket from current branch
```

Types: `bug`, `task`, `tech_debt`, `story`

## /deliver

End-to-end ticket implementation. The primary workflow command.

```
/deliver 1790               # Existing ticket
/deliver create 1322        # Create ticket under parent, then deliver
/deliver "fix broken upload" # Adhoc (no ticket)
```

**Flow:** /op read → plan + interview → branch → execute phase-by-phase → /pr → /op update

- Only pauses for human input during planning/interview
- Commits incrementally per phase, pushes after each
- Delegates to: `/op`, `/interview`, `/pr`

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

## /pr

Creates a GitHub PR with code review and template.

```
/pr
```

**Flow:** code review (mandatory) → docs update → pre-flight checks (tsc, tests) → push → create PR

- Uses `.github/pull_request_template.md`
- Links OP ticket automatically
- Architecture audit triggered if 10+ files or 500+ lines changed

## /interview

Structured discovery interview to surface gaps and tradeoffs before implementation.

```
/interview              # Interview about current work
/interview <topic>      # Interview about specific feature
```

Asks 2-4 questions per round across multiple dimensions (scope, technical, UX, edge cases). Produces a spec file.

## /qa

Verify the current branch's changes through automated and manual checks.

```
/qa                    # Full QA on current branch
/qa <feature>          # Focus on specific feature
```

**Flow:** gather scope → type-check + tests + lint → acceptance criteria → edge case review → browser verify (if UI) → report

## /retro

Capture learnings from the current session.

```
/retro                 # Session retrospective
```

Reviews what was done, captures patterns, suggests rule/command updates. Saves learnings to `.claude/memories/`.

## Command Relationships

```
/dispatch
  └── /deliver (per task)
        ├── /op (read/create ticket)
        ├── /interview (plan + discovery)
        ├── /qa (verify before PR)
        ├── /pr (push + PR)
        └── /op update (post progress)

/retro                   (standalone — end of session)
```
