# OpenProject EOD Update

Post an end-of-day activity update on an OpenProject work package ticket.

## Usage

```
/op-update [ticket_id]
```

- `ticket_id` — Optional. If omitted, extract from current branch name (e.g., `task/1762-...` → `1762`)

## Configuration

Requires `OPENPROJECT_API_KEY` environment variable.
If not set in shell, read from `~/.claude/settings.json` → `env.OPENPROJECT_API_KEY`.

## Workflow

### 1. Resolve ticket ID

- If argument provided, use it
- Otherwise extract from branch name: `git branch --show-current` → parse numeric ID after prefix
- If neither works, ask the user

### 2. Gather context

Analyze the session's work to build the update:

```bash
git log --oneline ${BASE_BRANCH}..HEAD    # Commits on this branch
git diff ${BASE_BRANCH}...HEAD --stat     # Changed files
```

Also review any draft EOD file if it exists: `draft/eod-YYYY-MM-DD.md`

### 3. Build update comment

Format the update in **plain English** so non-technical team members can understand.
Avoid code-level details — describe what was done in terms of outcomes and features.

**Structure:**

```
**Updates:**
- <what was accomplished, in plain English>
- <link to PR if created>

**Next:**
- <what's planned next>

**Blockers:**
- <any blockers, or "None">

**ETA:**
- <"Completed", "On track", or specific date>
```

**Rules:**
- Start directly with `**Updates:**` — no header line, no emoji prefixes
- No "Links" section — PR/ticket links are inline with updates
- Write in plain English: "Added daily caching for imported pages" not "Implemented date-based folder partitioning in capture.service.ts"
- Include OP ticket links inline: `[OP#1762](${OP_BASE_URL}/projects/${OP_PROJECT_SLUG}/work_packages/1762/activity)`
- Include PR links inline if created: `[PR #144](https://github.com/${GITHUB_ORG_REPO}/pull/144)`

### 4. Confirm with user

Show the draft update and wait for user confirmation before posting.

### 5. Post to OpenProject

```bash
# Get lockVersion
LOCK=$(curl -s "${OP_BASE_URL}/api/v3/work_packages/${TICKET_ID}" \
  -u "apikey:${API_KEY}" | jq '.lockVersion')

# Post comment
curl -s -X POST \
  "${OP_BASE_URL}/api/v3/work_packages/${TICKET_ID}/activities?notify=false" \
  -H "Content-Type: application/json" \
  -u "apikey:${API_KEY}" \
  -d "$(jq -n --arg text "UPDATE_TEXT" '{"comment":{"raw":$text}}')"
```

### 6. Confirm success

Print confirmation with ticket link:
```
Posted EOD update to OP#1762
${OP_BASE_URL}/projects/${OP_PROJECT_SLUG}/work_packages/1762/activity
```

## Error Handling

- **Missing API key**: Read from `~/.claude-secrets` or prompt user
- **No branch/ticket ID**: Ask the user
- **API error**: Show error details, don't retry

## Constants

- **Base URL**: `${OP_BASE_URL}`
- **Project**: `${OP_PROJECT_SLUG}`

## Trigger Rules

- Only runs when explicitly invoked via `/op-update`
- Never auto-triggered from `/op-create` or other commands
