# Land — Merge and Verify Deployment

Merge a PR, wait for CI, and verify the deployment is healthy.

## Usage

```
/land                              # Land current branch's PR
/land <pr-number>                  # Land specific PR
```

## Workflow

### 1. Find PR

```bash
# From current branch
PR_NUM=$(gh pr view --json number -q '.number')

# Or from argument
PR_NUM=$1
```

### 2. Pre-merge checks

```bash
gh pr checks $PR_NUM
```

Verify:
- All CI checks pass
- Required reviews approved
- No merge conflicts

If checks are failing, show which ones and stop.

### 3. Merge

```bash
gh pr merge $PR_NUM --squash --delete-branch
```

Use squash merge to keep history clean.

### 4. Wait for deploy

```bash
# Watch for deploy (project-specific)
# Check CI/CD pipeline status
gh run list --branch ${BASE_BRANCH} --limit 3
```

Poll until deployment completes (or timeout after 10 minutes).

### 5. Verify production

After deploy:
- Check application health endpoint if available
- Check for new error logs
- Verify the specific feature/fix works

```
Deployment verified:
  PR: #155 merged
  Deploy: completed (2m 30s)
  Health: OK
```

### 6. Update ticket

If ticket ID is available, run `/op update` with completion status.

## Rules

- Never merge with failing CI checks
- Always verify after deploy
- If deploy fails, revert immediately and investigate
- Don't land on Friday afternoon (unless urgent)
