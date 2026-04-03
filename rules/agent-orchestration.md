# Agent Orchestration

## When to Use Agents

Use agents PROACTIVELY — don't wait for the user to ask.

| Situation | Agent | Why |
|-----------|-------|-----|
| Complex feature request | **planner** | Break down before coding |
| Code just written/modified | **code-reviewer** | Catch issues early |
| New feature or bug fix | **tdd-guide** | Tests first |
| Architectural decision | **architect** | Design before build |
| Security-sensitive code | **security-reviewer** | Before commits |
| Build fails | **build-error-resolver** | Diagnose fast |

## Parallel Execution

ALWAYS run independent agents in parallel:

```
# GOOD: 3 agents at once
Agent 1: Security analysis
Agent 2: Performance review
Agent 3: Type checking

# BAD: Sequential when not needed
First agent 1, wait, then agent 2, wait, then agent 3
```

## Multi-Perspective Analysis

For complex problems, use split-role sub-agents:
- Senior engineer (architecture)
- Security expert (vulnerabilities)
- QA engineer (edge cases)
- Performance analyst (bottlenecks)

## Task Tracking

Use TodoWrite for multi-step tasks:
- Track progress on each step
- Show granular implementation steps
- Verify understanding of instructions
- Enable real-time steering

A visible todo list reveals: out-of-order steps, missing items, wrong granularity.
