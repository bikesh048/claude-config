# TripcartHQ Claude Config

Shared Claude Code configuration for all TripcartHQ projects. Provides standardized commands, skills, permissions, rules, and agent personas.

## Quick Start

### New team member (first time)

```bash
git clone git@github.com:TripcartHQ/claude-config.git
cd claude-config

# Install global rules, agents, and settings template
./install.sh --global

# Set up secrets
cp config/config.example.env ~/.claude-secrets
# Edit ~/.claude-secrets with your API keys
chmod 600 ~/.claude-secrets

# Add to your shell profile (~/.zprofile or ~/.zshrc)
echo '[ -f ~/.claude-secrets ] && source ~/.claude-secrets' >> ~/.zprofile
```

### Install into a project

```bash
# Option 1: Interactive (prompts for values)
./install.sh /path/to/your-project

# Option 2: From config file
cp config/config.example.env /path/to/your-project/.claude-config.env
# Edit .claude-config.env with project values
./install.sh /path/to/your-project --config=/path/to/your-project/.claude-config.env
```

### Update an existing project

Re-run the install script — it will overwrite commands/skills but skip files that already exist (settings.json, PR template).

## What Gets Installed

### Project-level (`.claude/`)

| Item | Description |
|------|-------------|
| `settings.json` | Shared permissions + deny list |
| `commands/op-create.md` | Create OpenProject work packages |
| `commands/op-read.md` | Read OP tickets with summary |
| `commands/op-update.md` | Post EOD updates to OP |
| `skills/create-pr/` | Full PR workflow with review + OP linking |
| `skills/op-update/` | EOD update skill with template |
| `skills/ticket/` | Quick ticket fetch |

### Global (`~/.claude/`)

| Item | Description |
|------|-------------|
| `rules/common/` | Language-agnostic coding standards |
| `rules/typescript/` | TypeScript-specific patterns |
| `agents/code-reviewer.md` | Code review agent (Sonnet) |
| `agents/security-auditor.md` | Security audit agent (Haiku, read-only) |
| `settings.json.template` | Baseline global settings |

## Configuration Tokens

The install script replaces these tokens in all command/skill files:

| Token | Example | Description |
|-------|---------|-------------|
| `{{OP_BASE_URL}}` | `https://openproject.codewingsolutions.com` | OpenProject instance URL |
| `{{OP_PROJECT_SLUG}}` | `tripcart-new` | OP project identifier |
| `{{OP_PROJECT_ID}}` | `5` | OP numeric project ID |
| `{{GITHUB_ORG_REPO}}` | `TripcartHQ/tripcart-builder` | GitHub org/repo |
| `{{BASE_BRANCH}}` | `develop` | Default PR target branch |

## Environment Variables

Required in your environment (via `~/.claude-secrets`):

| Variable | Purpose |
|----------|---------|
| `OPENPROJECT_API_KEY` | OP API authentication |

## Personal Overrides

After install, create `.claude/settings.local.json` in your project for personal permission overrides (auto-gitignored):

```json
{
  "permissions": {
    "allow": [
      "Bash(npx jest:*)",
      "Bash(docker compose *)"
    ]
  }
}
```

## Repo Structure

```
claude-config/
├── install.sh              # Install script
├── config/
│   └── config.example.env  # Project config template
├── project/                # → .claude/ in target project
│   ├── settings.json
│   ├── commands/
│   ├── skills/
│   └── templates/
└── global/                 # → ~/.claude/
    ├── rules/
    ├── agents/
    └── settings.json.template
```
