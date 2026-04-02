---
name: interview
description: Interview the user about a plan, feature, or task to surface gaps, tradeoffs, and edge cases before implementation. Produces a spec file.
triggers:
  - interview
  - interview me
  - ask me about the plan
---

# Interview — Deep Discovery Before Implementation

Systematically interview the user about a plan, feature, or task. Surfaces technical decisions, UX tradeoffs, edge cases, and concerns that would otherwise emerge mid-implementation. Outputs a spec file.

## Usage

```
/interview                          # Interview about current work (branch/ticket context)
/interview <topic or description>   # Interview about a specific feature or plan
```

## Input: $ARGUMENTS

## Workflow

### 1. Identify the Subject

Determine what to interview about:
- If `$ARGUMENTS` provided, use that as the topic
- If on a feature branch, extract the ticket/feature from branch name
- If a plan file exists in `.claude/specs/`, read it as starting context
- If recent `/dispatch` or `/deliver` work, use that context

### 2. Research Before Asking

Before the first question, silently gather context:
- Read relevant service `CLAUDE.md` files (detect from topic keywords)
- Check existing specs in `.claude/specs/`
- Check existing commands/skills that relate to the topic
- Read recent commits on the branch (`git log --oneline -10`)

This ensures questions are **informed, not generic**.

### 3. Interview Using AskUserQuestion

Ask 2-4 questions per round by prompting the user directly. Continue for multiple rounds until all dimensions are covered.

**Question Dimensions** (cover all, in roughly this order):

**Round 1 — Scope & Intent**
- What problem does this solve? Who benefits?
- What's in scope vs explicitly out of scope?
- Are there existing patterns in the codebase to follow?

**Round 2 — Technical Implementation**
- Which services/modules are affected?
- What are the data flow / API contracts?
- Are there performance implications (caching, N+1, payload size)?
- What happens at the boundary between services?

**Round 3 — Edge Cases & Failure**
- What happens when it fails? (network, auth, bad data)
- What happens with concurrent users/requests?
- Are there backwards compatibility concerns?
- What about the shared database (Laravel coexistence)?

**Round 4 — UX & User Impact** (if applicable)
- What does the user see during loading/error states?
- Is this behind a feature flag or immediate rollout?
- Does this change existing behavior or is it additive?

**Round 5 — Tradeoffs & Concerns**
- What are you most worried about?
- Is there a simpler version we should ship first?
- Any deadline or dependency pressure?

**Question Rules:**
- Never ask obvious questions answerable by reading the code
- Always provide 2-4 concrete options (not open-ended)
- When the user says "what should I do?" or "what works best?", give your recommendation and ask them to confirm
- When the user doesn't understand, rephrase with a concrete example
- Skip dimensions that don't apply (e.g., no UX questions for a backend-only change)
- Stop when all relevant dimensions are covered — don't pad with filler questions

### 4. Write Spec

After interview is complete, write a spec file to `.claude/specs/<topic-slug>-spec.md`:

```markdown
# <Feature Name> Spec

## Overview
<1-2 sentence summary>

## Decisions

| Decision | Choice | Rationale |
|----------|--------|-----------|
| <question topic> | <what was decided> | <why> |
| ... | ... | ... |

## Scope
- **In scope**: ...
- **Out of scope**: ...

## Technical Design
<Service detection, data flow, API contracts, affected modules>

## Edge Cases & Error Handling
<What was discussed about failures, concurrency, backwards compat>

## Implementation Phases (if multi-step)
<Phase 1, Phase 2, etc. with dependencies>

## Open Questions
<Anything unresolved that needs further investigation>
```

### 5. Report

Tell the user:
- Spec file path
- Summary of key decisions (3-5 bullets)
- Suggested next step (e.g., "ready for `/dispatch`" or "needs Phase 1 first")

## Key Principles

- **Be opinionated**: When the user asks for a recommendation, give one. Don't be neutral.
- **Be concrete**: Use examples from their codebase, not abstract concepts.
- **Be efficient**: Skip questions where the answer is obvious from context.
- **Be deep**: Ask follow-up questions when answers reveal complexity.
- **Respect the user's time**: 3-5 rounds max. If it's a simple feature, 2 rounds is enough.
