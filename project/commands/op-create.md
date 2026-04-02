# OpenProject Work Package Creation

Create a new work package (ticket) in OpenProject as a child of a given parent ticket.

## Usage

```
/op-create <parent_ticket_id> <type> [title]
```

- `parent_ticket_id` — The parent work package ID (e.g. `1722`)
- `type` — One of: `bug`, `task`, `tech_debt`, `story`
- `title` — Optional; if omitted, ask the user

## Type Mapping

Confirmed type IDs from OpenProject instance:

| Shorthand   | OpenProject Type | Type href path           |
|-------------|------------------|--------------------------|
| `bug`       | Bug              | `/api/v3/types/7`        |
| `task`      | Task             | `/api/v3/types/1`        |
| `tech_debt` | Tech Debt        | `/api/v3/types/10`       |
| `story`     | User story       | `/api/v3/types/6`        |

Other available types: Milestone(2), Summary task(3), Feature(4), Epic(5), Released(8), Test Case(9), Polish Pack(11), Technical Spike(12).

## Configuration

Requires `OPENPROJECT_API_KEY` environment variable (same as `op-update`).

```bash
export OPENPROJECT_API_KEY="your-api-key-here"
```

## Workflow

### 0. Ensure you're on develop

Before starting, switch to the `${BASE_BRANCH}` branch and pull latest:

```bash
git checkout ${BASE_BRANCH} && git pull origin ${BASE_BRANCH}
```

If the working tree is dirty, warn the user and ask to stash/commit first.

### 1. Validate inputs

- Confirm `OPENPROJECT_API_KEY` is set
- Validate `type` is one of the allowed values
- If `title` is not provided, ask the user for it
- Optionally ask for a description (default: empty)

### 2. Fetch parent ticket to confirm it exists

```bash
curl -s "${OP_BASE_URL}/api/v3/work_packages/${PARENT_ID}" \
  -u "apikey:${OPENPROJECT_API_KEY}" | jq '{id, subject: .subject, status: ._links.status.title}'
```

Print the parent ticket subject so the user can confirm it's the right one.

### 3. Resolve type ID

If type IDs haven't been confirmed yet, fetch from the types endpoint:

```bash
curl -s "${OP_BASE_URL}/api/v3/types" \
  -u "apikey:${OPENPROJECT_API_KEY}"
```

Find the matching type by name (case-insensitive). Map `tech_debt` to "Tech Debt" or similar.

### 4. Build and confirm payload

Show the user a summary before creating:

```
Creating work package:
  Parent:  #1722 — "Build page rendering pipeline"
  Type:    Bug
  Title:   "Fix cache invalidation on publish"
```

Wait for user confirmation.

### 5. Create work package via API

**IMPORTANT**: The project href must use the numeric project ID, not the slug.
Get it from the parent ticket: `._links.project.href` (currently `/api/v3/projects/${OP_PROJECT_ID}`).

```bash
curl -s -X POST \
  "${OP_BASE_URL}/api/v3/work_packages" \
  -H "Content-Type: application/json" \
  -u "apikey:${OPENPROJECT_API_KEY}" \
  -d '{
    "subject": "TITLE_HERE",
    "startDate": "YYYY-MM-DD",
    "_links": {
      "type": { "href": "/api/v3/types/TYPE_ID" },
      "project": { "href": "/api/v3/projects/${OP_PROJECT_ID}" },
      "parent": { "href": "/api/v3/work_packages/PARENT_ID" }
    }
  }'
```

**Always set `startDate` to today's date** (e.g. `2026-03-25`).

If description is provided, add `"description": {"raw": "DESCRIPTION"}` to the body.

### 6. Verify and report

On success (`201 Created`), extract the new ticket ID and derive the branch name using
the naming convention from Step 7. Print a summary with **Quick Snippets** for easy copy-paste:

```
✔ Created OP#1750 (Bug): "Fix cache invalidation on publish"
  Parent: OP#1722
  URL: ${OP_BASE_URL}/projects/${OP_PROJECT_SLUG}/work_packages/1750

Quick Snippets:
  Branch:   bug/1750-fix-cache-invalidation-on-publish
  Checkout: git checkout -b bug/1750-fix-cache-invalidation-on-publish
```

Then ask: **"Create branch and start working?"**

### 7. Start working (optional)

If the user wants to start, create a branch and begin:

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

## Error Handling

- **Missing API key**: Prompt user to set `OPENPROJECT_API_KEY`
- **Invalid type**: Show allowed types: `bug`, `task`, `tech_debt`, `story`
- **403 Forbidden**: API key lacks permission to create work packages
- **404 on parent**: Parent ticket ID not found
- **422 Validation error**: Show the error details from the response

## Constants

- **Base URL**: `${OP_BASE_URL}`
- **Project**: `${OP_PROJECT_SLUG}`
- **Work Package URL pattern**: `${OP_BASE_URL}/projects/${OP_PROJECT_SLUG}/work_packages/${ID}`
