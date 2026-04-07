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

## Custom Fields Reference (Single Source of Truth)

All ticket types share these **common fields**:

| API Field | Display Name | Notes |
|-----------|-------------|-------|
| `id` | ID | |
| `subject` | Subject | |
| `._embedded.type.name` | Type | |
| `._embedded.status.name` | Status | |
| `._embedded.priority.name` | Priority | |
| `._embedded.assignee.name` | Assignee | May be null |
| `._embedded.parent` | Parent | Use `._links.parent.title` for name |
| `.description.raw` | Description | Markdown format |
| `.customField24.raw` | Steps to Reproduce | Numbered list — Bug type only |
| `.customField25.raw` | Expected Behavior | Bullet points — Bug type only |
| `.customField26.raw` | Actual Behavior | Bullet points — Bug type only |
| `.customField30.raw` | Acceptance Criteria | Markdown checklist — `- [ ]` items (non-Bug types) |
| `.customField31` | Branch | Quick Snippets field |
| `.startDate` | Start Date | |
| `.dueDate` | Due Date | May be null |
| `.estimatedTime` | Estimated Time | ISO 8601 duration |
| `.spentTime` | Spent Time | ISO 8601 duration |
| `.createdAt` | Created | |
| `.updatedAt` | Updated | |

**Tech Debt** type has additional fields:

| API Field | Display Name | Notes |
|-----------|-------------|-------|
| `.customField33.raw` | Pain Points | Why this matters — markdown |
| `.customField34.raw` | Current State | How things work now — markdown |
| `.customField35.raw` | Proposed Solution | Target architecture — markdown |
| `.customField37.raw` | Risks & Mitigations | Risk table — markdown |
| `.customField38.raw` | Implementation Plan | Phased steps — markdown |

Use these field mappings in **both Read and Create** actions.

---

## Action: Read

Read a ticket and output a planning summary.

### 1. Resolve ticket ID

```bash
TICKET_ID="${1:-$(git branch --show-current | grep -oE '[0-9]+' | head -1)}"
```

If no ticket ID can be resolved, ask the user.

### 2. Fetch ticket via API

Fetch the **full response** (do not filter with jq). Extract common fields for all types, plus type-specific fields based on the ticket type.

```bash
curl -s \
  "${OP_BASE_URL}/api/v3/work_packages/${TICKET_ID}" \
  -H "Content-Type: application/json" \
  -u "apikey:${OPENPROJECT_API_KEY}"
```

Extract fields per the **Custom Fields Reference** above.

### 3. Output format

**Common header (all types):**

```
## OP#<id>: <subject>

**Type:** <type> | **Status:** <status> | **Priority:** <priority> | **Assignee:** <assignee>
**Parent:** <parent or "none"> | **Branch:** `<branch or "not set">`
**Start:** <startDate> | **Due:** <dueDate or "not set"> | **Estimate:** <estimatedTime or "not set">

### Description
<description — truncate to key points if very long, preserve acceptance criteria>
```

**Additional sections for Bug type:**

```
### Steps to Reproduce
<customField24 content>

### Actual Behavior
<customField26 content>

### Expected Behavior
<customField25 content>
```

**Additional sections for Tech Debt:**

```
### Pain Points
<customField33 content>

### Current State
<customField34 content>

### Proposed Solution
<customField35 content>

### Risks & Mitigations
<customField37 content>

### Implementation Plan
<customField38 content>
```

**Footer (all types):**

```
### Acceptance Criteria
<read from customField30 if present, otherwise note "not specified">
```

Rules:
- Strip HTML tags, output as plain markdown
- If any section > 500 words, summarize to key points
- Highlight URLs prominently
- Only show Tech Debt sections that have content (skip empty/null)
- Do NOT fetch child tickets or relations
- After output, ask: **"Create branch and start working, or need more context?"**

### 4. Start working (optional)

If user wants to start:

**Branch name** — use the exact name from the ticket's **Quick Snippets** custom field.
Do NOT generate or slugify the branch name — always read it from the ticket API response.

Extract from the API response:
```bash
BRANCH=$(curl -s "${OP_BASE_URL}/api/v3/work_packages/${TICKET_ID}" \
  -u "apikey:${OPENPROJECT_API_KEY}" | jq -r '.customField31 // empty')
```

If Quick Snippets is empty, ask the user for the branch name.

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
- **Always generate description and acceptance criteria from conversation context** — do NOT create bare tickets with just a title

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

Always set `startDate` to today.

**Always include `description` and `customField30` (Acceptance Criteria):**
- Generate the **description** from conversation context — summarize what the work involves
- Generate **acceptance criteria** (`customField30`) as a markdown checklist (`- [ ]` items) covering all verifiable outcomes
- Do NOT leave these empty or ask the user to provide them — you have the context, use it

**For Bug type**, use dedicated custom fields — do NOT embed these sections in the description:

```json
{
  "description": {
    "raw": "## Description\n\n<concise summary of what the bug is>"
  },
  "customField24": {
    "raw": "1. <step 1>\n2. <step 2>\n3. <step 3>"
  },
  "customField26": {
    "raw": "- <what currently happens>"
  },
  "customField25": {
    "raw": "- <expected outcome, point 1>\n- <expected outcome, point 2>"
  }
}
```

Field mapping for Bug type:
| Field | Custom Field | Format |
|-------|-------------|--------|
| Steps to Reproduce | `customField24` | Numbered list |
| Actual Behavior | `customField26` | Bullet points |
| Expected Behavior | `customField25` | Bullet points |

Do NOT include `customField30` (Acceptance Criteria) for Bug tickets — leave it empty.

**For all other types:**

```json
{
  "description": {"raw": "## Summary\n\n..."},
  "customField30": {"raw": "- [ ] ...\n- [ ] ..."}
}
```

**For Tech Debt type**, also ask for and include these fields (per **Custom Fields Reference**):

| Field | Prompt | Required |
|-------|--------|----------|
| `customField33` | Pain Points — why does this matter? | Yes |
| `customField34` | Current State — how does it work now? | Yes |
| `customField35` | Proposed Solution — what's the target? | Yes |
| `customField37` | Risks & Mitigations | Optional |
| `customField38` | Implementation Plan | Optional |

Add as markdown custom fields in the create payload:
```json
{
  "customField33": {"raw": "..."},
  "customField34": {"raw": "..."},
  "customField35": {"raw": "..."},
  "customField37": {"raw": "..."},
  "customField38": {"raw": "..."}
}
```

Skip optional fields if user doesn't provide them.

### 4. Generate branch name and update ticket

Derive branch name from ticket type and ID:

| Type | Prefix |
|------|--------|
| Bug | `bug/` |
| Task | `task/` |
| Tech Debt | `tech-debt/` |
| User story | `story/` |

Slugify subject: `${PREFIX}${TICKET_ID}-${SLUG}` — lowercase, replace spaces `/` `.` `:` with hyphens, strip `://` and `https` and `http` prefixes, strip remaining non-alphanumeric except hyphens, collapse consecutive hyphens, trim trailing hyphens, no length limit.

**Write the branch name to the ticket's Quick Snippets field** (`customField31`) so it becomes the source of truth:

```bash
LOCK=$(curl -s "${OP_BASE_URL}/api/v3/work_packages/${NEW_ID}" \
  -u "apikey:${OPENPROJECT_API_KEY}" | jq '.lockVersion')

curl -s -X PATCH \
  "${OP_BASE_URL}/api/v3/work_packages/${NEW_ID}" \
  -H "Content-Type: application/json" \
  -u "apikey:${OPENPROJECT_API_KEY}" \
  -d "{\"lockVersion\": ${LOCK}, \"customField31\": \"${BRANCH}\"}"
```

### 5. Report

```
Created OP#1750 (Bug): "Fix cache invalidation on publish"
  Parent: OP#1722
  URL: ${OP_BASE_URL}/projects/${OP_PROJECT_SLUG}/work_packages/1750
  Branch: bug/1750-fix-cache-invalidation-on-publish
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

- **Missing API key**: Prompt user to set `OPENPROJECT_API_KEY` in `.claude/settings.local.json`
- **404 Not Found**: Invalid ticket ID
- **401 Unauthorized**: API key invalid or expired
- **403 Forbidden**: Insufficient permissions
- **422 Validation**: Show error details

## Credentials

Read credentials from `.claude/settings.local.json` in the project root:

```json
{
  "env": {
    "OP_BASE_URL": "https://...",
    "OP_PROJECT_SLUG": "...",
    "OPENPROJECT_API_KEY": "...",
    "GITHUB_ORG_REPO": "...",
    "BASE_BRANCH": "..."
  }
}
```

**Before any API call**, read `.claude/settings.local.json` and extract:
- `OP_BASE_URL` — strip trailing slash
- `OP_PROJECT_SLUG`
- `OPENPROJECT_API_KEY`
- `BASE_BRANCH` (for git operations)
- `GITHUB_ORG_REPO` (for PR links)

Do NOT rely on shell environment variables — always read from this file.

## Constants

- **Ticket URL**: `${OP_BASE_URL}/projects/${OP_PROJECT_SLUG}/work_packages/${ID}`
