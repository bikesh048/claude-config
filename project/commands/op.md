# OpenProject Ticket Manager

Single command for all OpenProject ticket operations.

## Usage

```
/op 1790                            # Read ticket
/op create 1322                     # Create ticket under parent
/op create 1322 task                # Create with type (bug, task, tech_debt, story)
/op update                          # Post EOD update (ticket from branch)
/op update 1790                     # Post EOD update on specific ticket
```

## Input: $ARGUMENTS

## Routing

Parse arguments to determine action:

| Input | Action |
|-------|--------|
| `<number>` | **Read** ticket |
| `create <parent_id>` | **Create** under parent (ask for title/type) |
| `create <parent_id> <type>` | **Create** with specified type |
| `update` | **Update** (ticket ID from branch) |
| `update <number>` | **Update** specific ticket |
| _(no args)_ | **Read** (ticket ID from branch) |

---

## Action: Read

Read a ticket and output a planning summary.

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

```
## OP#<id>: <subject>

**Type:** <type> | **Status:** <status> | **Priority:** <priority> | **Assignee:** <assignee>

### Description
<description — truncate to key points if very long, preserve acceptance criteria>

### Acceptance Criteria
<extract from description if present, otherwise note "not specified">
```

Rules:
- Strip HTML tags, output as plain markdown
- If description > 500 words, summarize to key requirements and acceptance criteria
- Highlight URLs prominently
- Do NOT fetch child tickets or relations
- After output, ask: **"Create branch and start working, or need more context?"**

### 4. Start working (optional)

If user wants to start:

**Branch naming** — derive from ticket type and ID:

| Type | Prefix |
|------|--------|
| Bug | `bug/` |
| Task | `task/` |
| Tech Debt | `tech-debt/` |
| User story | `story/` |

Slugify subject: `${PREFIX}${TICKET_ID}-${SLUG}` (max 50 chars)

```bash
git checkout ${BASE_BRANCH} && git pull origin ${BASE_BRANCH} && git checkout -b "${BRANCH}"
```

Update ticket status to "In progress" (status ID: 7):

```bash
LOCK=$(curl -s "${OP_BASE_URL}/api/v3/work_packages/${TICKET_ID}" \
  -u "apikey:${OPENPROJECT_API_KEY}" | jq '.lockVersion')

curl -s -X PATCH \
  "${OP_BASE_URL}/api/v3/work_packages/${TICKET_ID}" \
  -H "Content-Type: application/json" \
  -u "apikey:${OPENPROJECT_API_KEY}" \
  -d "{\"lockVersion\": ${LOCK}, \"_links\":{\"status\":{\"href\":\"/api/v3/statuses/7\"}}}"
```

---

## Action: Create

Create a new ticket under a parent.

### 1. Validate

- Confirm `OPENPROJECT_API_KEY` is set
- Fetch parent ticket to confirm it exists, print subject for confirmation
- If type not provided, ask (default: `task`)
- Ask for title

### 2. Type mapping

| Shorthand | OpenProject Type | Type href |
|-----------|-----------------|-----------|
| `bug` | Bug | `/api/v3/types/7` |
| `task` | Task | `/api/v3/types/1` |
| `tech_debt` | Tech Debt | `/api/v3/types/10` |
| `story` | User story | `/api/v3/types/6` |

### 3. Create via API

```bash
PROJECT_HREF=$(curl -s "${OP_BASE_URL}/api/v3/work_packages/${PARENT_ID}" \
  -u "apikey:${OPENPROJECT_API_KEY}" | jq -r '._links.project.href')

curl -s -X POST \
  "${OP_BASE_URL}/api/v3/work_packages" \
  -H "Content-Type: application/json" \
  -u "apikey:${OPENPROJECT_API_KEY}" \
  -d '{
    "subject": "TITLE_HERE",
    "startDate": "YYYY-MM-DD",
    "_links": {
      "type": { "href": "/api/v3/types/TYPE_ID" },
      "project": { "href": "'"${PROJECT_HREF}"'" },
      "parent": { "href": "/api/v3/work_packages/PARENT_ID" }
    }
  }'
```

Always set `startDate` to today. If description provided, add `"description": {"raw": "..."}`.

### 4. Report

```
Created OP#1750 (Bug): "Fix cache invalidation on publish"
  Parent: OP#1722
  URL: ${OP_BASE_URL}/projects/${OP_PROJECT_SLUG}/work_packages/1750

Quick Snippets:
  Branch:   bug/1750-fix-cache-invalidation-on-publish
  Checkout: git checkout -b bug/1750-fix-cache-invalidation-on-publish
```

Then ask: **"Create branch and start working?"**

---

## Action: Update

Post an EOD progress update as a comment on a ticket.

### 1. Resolve ticket ID

From argument or branch name: `git branch --show-current | grep -oE '[0-9]+' | head -1`

### 2. Gather context

```bash
git log --oneline ${BASE_BRANCH}..HEAD
git diff ${BASE_BRANCH}...HEAD --stat
```

### 3. Build update comment

Format in **plain English** (non-technical team members should understand):

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

Rules:
- Start directly with `**Updates:**` — no header, no emoji
- Write in plain English, not code-level details
- Include ticket/PR links inline

### 4. Confirm with user, then post

```bash
LOCK=$(curl -s "${OP_BASE_URL}/api/v3/work_packages/${TICKET_ID}" \
  -u "apikey:${OPENPROJECT_API_KEY}" | jq '.lockVersion')

curl -s -X POST \
  "${OP_BASE_URL}/api/v3/work_packages/${TICKET_ID}/activities?notify=false" \
  -H "Content-Type: application/json" \
  -u "apikey:${OPENPROJECT_API_KEY}" \
  -d "$(jq -n --arg text "UPDATE_TEXT" '{"comment":{"raw":$text}}')"
```

---

## Error Handling

- **Missing API key**: Prompt user to set `OPENPROJECT_API_KEY`
- **404 Not Found**: Invalid ticket ID
- **401 Unauthorized**: API key invalid or expired
- **403 Forbidden**: Insufficient permissions
- **422 Validation**: Show error details

## Constants

- **Base URL**: `${OP_BASE_URL}`
- **Project**: `${OP_PROJECT_SLUG}`
- **Ticket URL**: `${OP_BASE_URL}/projects/${OP_PROJECT_SLUG}/work_packages/${ID}`
