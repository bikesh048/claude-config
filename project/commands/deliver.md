# Deliver — End-to-End Ticket Implementation

Single entry point for all development work. Handles ticket reading/creation, planning with interview, phase-by-phase execution with incremental commits, PR creation, and ticket updates.

## Usage

```
/deliver 1790                       # Existing ticket
/deliver create 1322                # Create ticket under parent, then deliver
/deliver "fix the broken upload"    # Adhoc — no ticket
```

## Input: $ARGUMENTS

## Routing

| Input | Flow |
|-------|------|
| `<number>` | **Existing ticket** — read and deliver |
| `create <parent_id>` | **New ticket** — plan, create, then deliver |
| `"<description>"` | **Adhoc** — no ticket, plan and deliver |

## Flow 1: Existing Ticket

```
/op <id> → plan + interview → branch → execute → /create-pr → /op update
```

### Step 1: Read Ticket

Run `/op ${ticket_id}` to fetch:
- Description, acceptance criteria (`customField30`)
- Quick Snippets (branch name — this is the session contract)

**Do NOT ask "Create branch and start working?"** — proceed automatically.

### Step 2: Plan + Interview

Analyze the ticket scope:

- **Small fix** (single file, clear change): Skip planning, go straight to Step 3
- **Medium/Large task**: Generate a plan, then interview the user inline:
  - Ask about technical tradeoffs, ambiguous decisions, scope boundaries
  - Merge answers into the plan
  - Save plan to `.claude/plans/`
  - **This is the ONLY human checkpoint** — everything after is autonomous

### Step 3: Branch

Use the **exact branch name from Quick Snippets** (Step 1). Never generate a different name.

```bash
git checkout ${BASE_BRANCH} && git pull origin ${BASE_BRANCH}
git checkout -b <exact-branch-from-quick-snippets>
```

If already on the correct branch, continue. Update ticket status to "In progress".

### Step 4-7: Execute → Ship

Same as Steps 4-7 below (shared across all flows).

## Flow 2: New Ticket

```
plan + interview → /op create <parent> → branch → execute → /create-pr → /op update
```

### Step 1: Plan + Interview

No ticket exists yet — plan from the description:

1. Generate implementation plan
2. Interview the user about tradeoffs and decisions
3. Save plan to `.claude/plans/`
4. **This is the ONLY human checkpoint**

### Step 2: Create Ticket

Run `/op create ${parent_id}` automatically using the plan output:
- **Type**: auto-detect from plan (feat → task, fix → bug)
- **Title**: derive from plan objective (short, <70 chars)
- **Description**: problem + solution + architecture + phases from plan
- **Acceptance Criteria** (`customField30`): derive from plan verification steps

### Step 3: Branch

Use the **exact branch name from Quick Snippets** (Step 2).

```bash
git checkout ${BASE_BRANCH} && git pull origin ${BASE_BRANCH}
git checkout -b <exact-branch-from-quick-snippets>
```

### Step 4-7: Execute → Ship

Same as below.

## Flow 3: Adhoc (No Ticket)

```
plan + interview → branch → execute → /create-pr
```

Same as Flow 2 but skip `/op create` and `/op update`. Branch name derived from description:
`fix/<slug>` or `chore/<slug>`.

## Shared Steps (all flows)

### Step 4: Execute Phase-by-Phase

For each implementation phase in the plan (or single phase for small fixes):

**a. Implement** — write/modify files as specified in the plan

**b. Validate**
- Type-check: `pnpm run type-check` (in affected app directory)
- Tests: `pnpm run test` (in affected app directory)
- If validation fails, fix before moving on (up to 3 attempts)

**c. Commit** — stage only files relevant to this phase
```
feat(envctl): add CLI dispatcher and config loading (phase 1/4)

Refs: OP#${TICKET_ID}
```
- Convention: `<type>(<scope>): <description> (phase N/M)`
- Push after each commit: `git push -u origin <branch>`

**d. Next phase** — do NOT batch phases, commit after each one

### Step 5: Final Validation

After all phases:
1. Run full type-check across affected directories
2. Run full test suite
3. Walk through acceptance criteria — verify each item passes
4. If any AC item not met, implement it before proceeding

### Step 6: Create PR

Run `/create-pr` which handles:
- Code review (code-reviewer agent, mandatory)
- Architecture audit (if 10+ files or 500+ lines changed)
- Pre-flight checks (tsc, tests, lint)
- Doc updates if needed
- PR creation using `.github/pull_request_template.md`

### Step 7: Update Ticket

If ticket ID available, run `/op update` with progress summary.

## When to Ask the User

Only pause for human input during **Step 2 (Plan + Interview)**. Everything else is autonomous.

Exception — stop and ask if:
1. **Tests failing after 3 fix attempts** — something structural is wrong
2. **Breaking change detected** — affects shared interfaces or public APIs

## Commit Strategy

Small, incremental commits — one per plan phase:
```
feat(envctl): add CLI dispatcher and config loading (phase 1/4)
feat(envctl): add GoCD API client and get command (phase 2/4)
feat(envctl): add interactive wizard and mutation commands (phase 3/4)
feat(envctl): add package.json bin entry and docs (phase 4/4)
```

For small fixes (no plan phases): single commit.

## Error Handling

- **No API key**: Stop, ask user to set `OPENPROJECT_API_KEY`
- **Ticket not found**: Ask for correct ID
- **Dirty working tree**: Ask to stash or commit first
- **Push fails**: Keep local changes, print retry command
- **Phase validation fails after 3 attempts**: Commit what works, note failure, continue
- **PR creation fails**: Show error, ask user to resolve

## Rules

1. **Plan is truth** — all decisions made during interview, don't re-decide during execution
2. **Branch contract** — Quick Snippets branch name flows through entire workflow unchanged
3. **Phase = commit** — never batch multiple phases into one commit
4. **Push early** — push after each commit (work is never lost)
5. **AC is the exit gate** — all acceptance criteria must pass before PR
6. **Single source of truth** — delegate to `/op`, `/create-pr`
7. **No scope creep** — implement only what the plan specifies
