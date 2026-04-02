# OpenProject Work Package Reader

Read an OpenProject work package and output a concise summary for planning.

## Usage

```
/op-read [ticket_id]
```

- If `ticket_id` is omitted, extract from the current git branch name (e.g. `bug/1723-fix-...` -> `1723`)

## Configuration

Requires `OPENPROJECT_API_KEY` environment variable.

## Workflow

### 1. Resolve ticket ID

```bash
TICKET_ID="${1:-$(git branch --show-current | grep -oE '[0-9]+' | head -1)}"
```

If no ticket ID can be resolved, ask the user.

### 2. Fetch ticket via API

```bash
curl -s \
  "${OP_BASE_URL}/api/v3/work_packages/${TICKET_ID}" \
  -H "Content-Type: application/json" \
  -u "apikey:${OPENPROJECT_API_KEY}" \
  | jq '{
    id: .id,
    subject: .subject,
    type: ._embedded.type.name,
    status: ._embedded.status.name,
    priority: ._embedded.priority.name,
    assignee: ._embedded.assignee.name,
    description: .description.raw,
    createdAt: .createdAt,
    updatedAt: .updatedAt
  }'
```

### 3. Output format

Present the ticket as a compact summary. Keep it under 300 tokens:

```
## OP#<id>: <subject>

**Type:** <type> | **Status:** <status> | **Priority:** <priority> | **Assignee:** <assignee>

### Description
<description — truncate to key points if very long, preserve acceptance criteria>

### Acceptance Criteria
<extract from description if present, otherwise note "not specified">
```

Rules:
- Strip HTML tags from description, output as plain markdown
- If description is longer than 500 words, summarize to key requirements and acceptance criteria only
- If description contains a URL (e.g. the page to fix), highlight it prominently
- Do NOT fetch child tickets or relations — keep it minimal
- After outputting the summary, ask: **"Create branch and start working, or need more context?"**

### 4. Start working (optional)

If the user wants to start working, create a branch and begin:

**Branch naming** — derive from ticket type and ID:

| Type       | Prefix       |
|------------|--------------|
| Bug        | `bug/`       |
| Task       | `task/`      |
| Tech Debt  | `tech-debt/` |
| User story | `story/`     |

Slugify the subject (lowercase, spaces to hyphens, strip special chars, max 50 chars):
`${PREFIX}${TICKET_ID}-${SLUG}` → e.g. `bug/1750-fix-cache-invalidation-on-publish`

Show proposed branch name, let user override, then:

```bash
git checkout ${BASE_BRANCH} && git pull origin ${BASE_BRANCH} && git checkout -b "${BRANCH}"
```

**Update ticket status** to "In progress" (status ID: 7):

The OpenProject API requires `lockVersion` for PATCH requests to prevent conflicts.
Always fetch the current `lockVersion` before updating:

```bash
# 1. Get current lockVersion
LOCK=$(curl -s "${OP_BASE_URL}/api/v3/work_packages/${TICKET_ID}" \
  -u "apikey:${OPENPROJECT_API_KEY}" | jq '.lockVersion')

# 2. Update with lockVersion
curl -s -X PATCH \
  "${OP_BASE_URL}/api/v3/work_packages/${TICKET_ID}" \
  -H "Content-Type: application/json" \
  -u "apikey:${OPENPROJECT_API_KEY}" \
  -d "{\"lockVersion\": ${LOCK}, \"_links\":{\"status\":{\"href\":\"/api/v3/statuses/7\"}}}"
```

If status update fails (e.g. invalid transition for user's role), warn but continue — not blocking.

Then ask: **"Branch created. Ready to plan the implementation?"**
If yes, invoke `/plan` based on the ticket description.

**Error cases**:
- Dirty working tree → warn, ask to stash/commit first
- Branch already exists → ask to switch to it instead

### 5. Error handling

- **Missing API key**: Prompt user to set `OPENPROJECT_API_KEY`
- **404 Not Found**: Invalid ticket ID — ask user to verify
- **401 Unauthorized**: API key invalid or expired

## Constants

- **Base URL**: `${OP_BASE_URL}`
- **Project**: `${OP_PROJECT_SLUG}`
- **Ticket URL pattern**: `${OP_BASE_URL}/projects/${OP_PROJECT_SLUG}/work_packages/${TICKET_ID}`
