# Investigate — Root-Cause Debugging

> Iron rule: NO fixes without investigation first.

Systematic debugging that identifies the root cause before any code changes.

## Usage

```
/investigate                       # Investigate current issue
/investigate "images not loading"  # Investigate specific problem
```

## Input: $ARGUMENTS

## Workflow

### 1. Define the problem

State clearly:
- **What's happening** vs **what should happen**
- **When** did it start (commit, deploy, config change?)
- **Who** is affected (all users, specific flow, specific env?)
- **How** to reproduce

### 2. Gather evidence

```bash
# Recent changes
git log --oneline -20
git diff HEAD~5..HEAD --stat

# Error logs
# (project-specific — check console, server logs, build output)
```

Do NOT skip this step. Read error messages carefully.

### 3. Form hypotheses

List 2-3 possible causes, ranked by likelihood:

```
Hypotheses:
1. [Most likely] <cause> — because <evidence>
2. [Possible] <cause> — because <evidence>
3. [Unlikely] <cause> — would explain <symptom> but not <other symptom>
```

### 4. Test hypotheses

For each hypothesis, starting with most likely:
- **What would confirm it?** (a specific test or check)
- **Run the test** (read code, add a log, check config)
- **Result:** confirmed or ruled out

```
Testing hypothesis 1:
  Check: <what to verify>
  Result: CONFIRMED / RULED OUT
  Evidence: <what we found>
```

### 5. Identify root cause

After testing:
```
Root cause: <precise description>
Evidence: <what confirmed it>
Ruled out: <what we eliminated and why>
```

### 6. Propose fix

Only NOW propose a fix:
- **Minimal fix** — smallest change that resolves the issue
- **Proper fix** — if the minimal fix is a band-aid, what's the right solution?
- **Prevention** — how to prevent this class of issue

### 7. Implement

Apply the fix with a clear commit:
```
fix(<scope>): <what was fixed>

Root cause: <one-line explanation>
Refs: OP#<ticket>
```

## Rules

1. **Never guess-and-fix** — investigate first, always
2. **Read the error message** — the answer is often right there
3. **One change at a time** — don't shotgun multiple fixes
4. **Verify the fix** — reproduce the issue, apply fix, confirm resolved
5. **Document the root cause** — in the commit message, not just "fixed bug"
