# Retro — Session Retrospective

> Inspired by gstack's /retro command.

Capture learnings from the current session before ending.

## Usage

```
/retro                 # Retrospective on current session
```

## Workflow

### 1. Review session activity

```bash
git log --oneline --since="8 hours ago"
git diff --stat HEAD~5..HEAD
```

Look at what was accomplished, how many commits, what areas were touched.

### 2. Capture learnings

Ask the user (or self-reflect if autonomous):

**What went well?**
- What approaches worked on first try?
- What tools/patterns were effective?

**What was harder than expected?**
- Where did we hit friction?
- What took multiple attempts?

**What should we do differently?**
- Any process improvements?
- Missing tools or automation?
- Rules that should be added/updated?

### 3. Extract patterns

If any reusable patterns were discovered:
- Save to `.claude/memories/` as a learned pattern
- Include: problem, solution, when to apply

Example:
```markdown
---
name: batch-api-calls
description: Use Promise.allSettled for parallel API calls with independent error handling
---
When making multiple independent API calls, use Promise.allSettled instead of
Promise.all to prevent one failure from canceling others.
```

### 4. Update rules (if needed)

If the session revealed a gap in rules or commands:
- Suggest specific changes to claude-config
- Note which rule/command to update and why

### 5. Summary

Output a concise session summary:

```
## Session Retro

**Duration:** ~X hours
**Commits:** N
**Files changed:** M

### Accomplished
- <what was done>

### Learnings
- <key takeaways>

### Action Items
- [ ] <any follow-ups>
```

## Rules

- Keep it brief — 2 minutes, not 20
- Focus on actionable insights, not status reporting
- If nothing was learned, that's fine — say so
