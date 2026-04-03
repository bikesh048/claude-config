# Context Budget Management

> Borrowed from GSD's context rot prevention pattern.

## Rules

1. **Prefer small, focused sessions** over marathon sessions
2. **Commit frequently** — each commit is a save point that reduces context dependency
3. **Break large tasks into phases** — implement one phase per session if needed
4. **Read files on demand** — don't read entire codebases upfront
5. **Use agents for parallel research** — offload to sub-agents instead of accumulating context

## Warning Signs (Context Rot)

If you notice any of these, suggest compacting or starting a fresh session:
- Repeating instructions that were already given
- Forgetting earlier decisions or constraints
- Suggesting changes that conflict with prior work in the session
- Quality degradation in code output
- Losing track of which files were modified

## When to Compact

- After completing a major phase (commit first)
- Before starting a different area of the codebase
- When the session has been running for 30+ exchanges
- After large file reads that are no longer relevant

## Spec-Driven Development

For complex features:
1. Extract a spec FIRST (use /interview)
2. Save spec to `.claude/specs/`
3. Implement from the spec — it survives context compaction
4. The spec is the source of truth, not conversation history
