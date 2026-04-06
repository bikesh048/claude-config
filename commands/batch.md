# Batch — Run Command on Multiple Items

Execute a command or action across multiple files, URLs, or items in parallel.

## Usage

```
/batch <command> <items...>
/batch <command> --from <file>
```

## Examples

```
/batch fix *.test.ts                          # Fix all failing test files
/batch review src/modules/*.ts                # Review multiple files
/batch "add type annotations" utils/*.js      # Transform multiple files
```

## Input: $ARGUMENTS

## Routing

| Input | Action |
|-------|--------|
| `<command> <glob>` | Expand glob, run command on each |
| `<command> --from <file>` | Read items from file (one per line) |
| `<command> item1 item2 ...` | Run on listed items |

## Workflow

### 1. Parse items

- If glob pattern → expand to file list
- If `--from <file>` → read lines from file
- Otherwise → treat remaining args as items

### 2. Plan execution

Show the plan before executing:

```
Batch: "add type annotations"
Items: 12 files
  src/utils/cache.js
  src/utils/logger.js
  ...

Proceed? [Y/n]
```

### 3. Execute

For each item, run as a parallel sub-agent when items are independent.

- **File operations** (review, fix, refactor): parallel agents with `isolation: "worktree"` if needed
- **Sequential operations** (migrations, ordered transforms): run in order

Track progress:
```
[1/12] ✔ cache.js
[2/12] ✔ logger.js
[3/12] ✘ parser.js — error: ...
[4/12] ... running
```

### 4. Report

```
Batch complete: 11/12 succeeded, 1 failed

Failed:
  parser.js — Could not infer types for dynamic import

Summary:
  12 files processed
  47 type annotations added
  1 file needs manual attention
```

## Rules

- Always show plan before executing
- Use parallel agents for independent items
- Track and report progress
- Don't stop on individual failures — continue and report all
