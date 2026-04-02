---
name: op-update
description: Post EOD activity update on an OpenProject work package ticket. Extracts ticket ID from branch name or accepts it as argument.
triggers:
  - op update
  - update ticket
  - update openproject
  - post comment on ticket
  - eod update
---

# OpenProject Activity Update

Post an EOD update comment on an OpenProject work package's activity feed.

## Usage

```
/op-update [ticket_id]
```

- If `ticket_id` is omitted, extract from the current git branch name (e.g. `bug/1722-fix-...` → `1722`)

## Configuration

Requires `OPENPROJECT_API_KEY` environment variable. Set it in your shell profile or `.env`:

```bash
export OPENPROJECT_API_KEY="your-api-key-here"
```

The API key authenticates as the `apikey` user via HTTP Basic Auth.

## Workflow

### 1. Resolve ticket ID

Extract the ticket number from the argument or current branch:

```bash
# From branch name: bug/1722-fix-... → 1722, feature/1800-add-... → 1800
TICKET_ID=$(git branch --show-current | grep -oE '[0-9]+' | head -1)
```

If no ticket ID can be resolved, ask the user.

### 2. Gather context

Collect information from git and GitHub to populate the template:

```bash
git log --oneline {{BASE_BRANCH}}..HEAD
git diff {{BASE_BRANCH}}...HEAD --stat
gh pr view --json url -q .url 2>/dev/null
```

### 3. Build comment using EOD template

Use the template from `.claude/skills/op-update/eod-template.md`.

Fill in each section from the gathered context:
- **Progress Today**: Summarize from commit messages — what was completed
- **Next Steps**: Infer from remaining TODOs, open issues, or ask the user
- **Blockers**: Default to "None" unless the user specifies
- **ETA**: Ask the user or default to "On track"
- **Links**: Auto-fill PR link and ticket link; staging link if available

Before posting, show the filled template to the user for confirmation.

### 4. Post comment via API

```bash
curl -s -X POST \
  "{{OP_BASE_URL}}/api/v3/work_packages/${TICKET_ID}/activities?notify=false" \
  -H "Content-Type: application/json" \
  -u "apikey:${OPENPROJECT_API_KEY}" \
  -d "$(jq -n --arg text "${COMMENT}" '{"comment":{"raw":$text}}')"
```

**API details:**
- **Endpoint**: `POST /api/v3/work_packages/{id}/activities`
- **Auth**: HTTP Basic — username `apikey`, password is the API key
- **Body**: `{"comment": {"raw": "markdown text"}}`
- **Query param**: `notify=false` to suppress email notifications (set to `true` if notifications desired)

### 5. Verify

Check the response for success (`201 Created`) or error. On success, print:

```
Posted EOD update on OP#1722: {{OP_BASE_URL}}/projects/{{OP_PROJECT_SLUG}}/work_packages/1722/activity
```

## Error Handling

- **Missing API key**: Prompt user to set `OPENPROJECT_API_KEY`
- **403 Forbidden**: API key lacks permission — user needs `add work package notes` permission
- **404 Not Found**: Invalid ticket ID
- **Network error**: Print error and suggest manual update

## Constants

- **Base URL**: `{{OP_BASE_URL}}`
- **Project**: `{{OP_PROJECT_SLUG}}`
- **Activity URL pattern**: `{{OP_BASE_URL}}/projects/{{OP_PROJECT_SLUG}}/work_packages/${TICKET_ID}/activity`
