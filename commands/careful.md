# Careful — Safety Guardrails

Enable extra safety checks for the current session. Warns before any destructive or risky action.

## Usage

```
/careful                           # Enable safety mode
```

## What It Does

When active, Claude will pause and confirm before:

### Destructive Operations
- `rm -rf`, `rm -r` on directories
- `git reset --hard`, `git clean -fd`
- `git push --force`
- Dropping database tables or collections
- Deleting cloud resources

### Risky Changes
- Modifying authentication or authorization code
- Changing database migrations
- Editing CI/CD pipeline configs
- Modifying environment variable handling
- Changing API endpoints that external services depend on

### Scope Expansion
- Touching files outside the current task scope
- Modifying shared utilities used by multiple modules
- Changing interfaces or types used across the codebase

## Confirmation Format

When a risky action is detected:

```
CAREFUL: This action is potentially destructive.

Action: git reset --hard HEAD~3
Risk: Permanently discards 3 commits of work
Reversible: NO

Proceed? [y/N]
```

## When to Use

- Debugging production issues
- Working in unfamiliar code
- Making changes to shared infrastructure
- When tired or rushed
- During incidents or high-stress situations

## Rules

- Default answer is always NO (safe by default)
- Show what will happen and whether it's reversible
- Suggest safer alternatives when possible
- Never auto-approve destructive actions in careful mode
