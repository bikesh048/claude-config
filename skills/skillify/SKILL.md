---
name: skillify
description: Extract reusable patterns from the current session or codebase and save as a SKILL.md file.
---

# Skillify — Extract Patterns into Skills

Turn recurring patterns, workflows, or solutions discovered during a session into reusable SKILL.md files.

## Usage

```
/skillify                          # Extract from current session
/skillify <topic>                  # Extract skill about specific topic
```

## Workflow

### 1. Identify the pattern

Review the current session for:
- A problem that was solved in a non-obvious way
- A workflow that could be reused across projects
- A tool/API usage pattern worth documenting
- A debugging approach that worked

### 2. Extract the skill

Structure as a SKILL.md:

```markdown
---
name: <skill-name>
description: <one-line description>
---

# <Skill Title>

## Problem
<What problem does this solve?>

## Solution
<Step-by-step approach>

## When to Use
<Triggers — when should this skill be applied?>

## Example
<Concrete example from the session>
```

### 3. Save location

Ask where to save:
- **claude-config** (`skills/<name>/SKILL.md`) — shared across org
- **Project** (`.claude/skills/<name>/SKILL.md`) — project-specific

### 4. Verify

- Skill name is descriptive and unique
- Description is searchable
- Steps are concrete, not vague
- Example is real, not hypothetical

## Rules

- One skill per file — keep focused
- Include real examples from the session
- Don't create skills for one-off solutions
- The skill should save time when the pattern recurs
