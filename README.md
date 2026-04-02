# TripcartHQ Claude Config

Shared Claude Code configuration for all TripcartHQ projects. Provides standardized commands, skills, rules, agents, and permissions — all installed at the project level.

## Quick Start

### Install into a project

```bash
git clone git@github.com:TripcartHQ/claude-config.git

# Install (prompts to create .claude-secrets on first run)
./setup.sh ~/projects/tripcart-builder --profile=fullstack-ts

# Install all profiles at once
./setup.sh ~/projects/tripcart-builder

# Install multiple profiles
./setup.sh ~/projects/tripcart-builder --profile=fullstack-ts --profile=laravel-php
```

The setup script creates `.claude-secrets` in the project root (gitignored) with project config and API keys. All values are loaded at runtime via environment variables.

### Add a single item later

```bash
./setup.sh ~/projects/tripcart-builder --add skill my-skill
./setup.sh ~/projects/tripcart-builder --add rule my-rule.md
./setup.sh ~/projects/tripcart-builder --add command my-cmd.md
./setup.sh ~/projects/tripcart-builder --add agent my-agent.md
```

### Update an existing project

```bash
./setup.sh ~/projects/tripcart-builder --update
```

Shows diffs and prompts accept/skip per file.

## What Gets Installed

Everything goes into the project's `.claude/` directory:

| Item | Description |
|------|-------------|
| `rules/common/` | Language-agnostic coding standards |
| `rules/typescript/` | TypeScript-specific patterns |
| `rules/*.md` | Project rules (nestjs, prisma, etc.) |
| `agents/` | Code reviewer, security auditor |
| `commands/` | create-pr, deliver, dispatch, op-create, op-read, op-update |
| `skills/` | interview, playwright-cli |
| `settings.json` | Shared permissions + deny list |

Plus `.claude-secrets` in the project root (gitignored).

## .claude-secrets

Created per project during setup. Contains project config and API keys:

```bash
export OP_BASE_URL="https://openproject.codewingsolutions.com"
export OP_PROJECT_SLUG="tripcart-new"
export OP_PROJECT_ID="5"
export GITHUB_ORG_REPO="TripcartHQ/tripcart-builder"
export BASE_BRANCH="develop"
export OPENPROJECT_API_KEY="your-api-key"
```

Commands use `$OP_BASE_URL`, `$OPENPROJECT_API_KEY` etc. at runtime. Add project-specific credentials (dashboard login, etc.) here too.

Source it in your shell profile:
```bash
echo '[ -f .claude-secrets ] && source .claude-secrets' >> ~/.zprofile
```

## Repo Structure

```
claude-config/
├── setup.sh                # Setup script
├── docs/
│   └── commands.md         # Command usage reference
├── profiles/               # Install profiles
│   ├── fullstack-ts.conf
│   └── laravel-php.conf
└── project/                # → .claude/ in target project
    ├── settings.json
    ├── agents/
    ├── commands/
    ├── rules/
    │   ├── common/
    │   ├── typescript/
    │   └── *.md
    ├── skills/
    └── templates/
```

## Symlink vs Copy

| Mode | When | Behavior |
|------|------|----------|
| **Symlink** (default) | All files | Edit once, all projects update |
| **Copy** (`--copy`) | Override default | Independent copies, no sync |

## Personal Overrides

Create `.claude/settings.local.json` in your project for personal permission overrides:

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

## Command Reference

See [docs/commands.md](docs/commands.md) for usage of all commands.
