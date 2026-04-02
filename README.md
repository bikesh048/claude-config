# TripcartHQ Claude Config

Shared Claude Code configuration for all TripcartHQ projects. Provides standardized commands, skills, rules, agents, and permissions — all installed at the project level.

## Quick Start

### Install into a project

```bash
git clone git@github.com:TripcartHQ/claude-config.git

# Install (prompts to create settings.local.json on first run)
./setup.sh ~/projects/tripcart-builder --profile=fullstack-ts

# Install all profiles at once
./setup.sh ~/projects/tripcart-builder

# Install multiple profiles
./setup.sh ~/projects/tripcart-builder --profile=fullstack-ts --profile=laravel-php
```

Or create `settings.local.json` manually:
```bash
cp /path/to/claude-config/settings.local.example.json ~/projects/your-project/.claude/settings.local.json
# Edit with your values
```

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
| `settings.json` | Shared permissions (committed) |
| `settings.local.json` | Project config + API keys (gitignored) |

## settings.local.json

Created per project during setup. Contains project config and API keys — loaded automatically by Claude Code at session start, zero context cost.

```json
{
  "env": {
    "OP_BASE_URL": "https://openproject.codewingsolutions.com",
    "OP_PROJECT_SLUG": "tripcart-new",
    "OP_PROJECT_ID": "5",
    "GITHUB_ORG_REPO": "TripcartHQ/tripcart-builder",
    "BASE_BRANCH": "develop",
    "OPENPROJECT_API_KEY": "your-api-key"
  }
}
```

Commands use `$OP_BASE_URL`, `$OPENPROJECT_API_KEY` etc. at runtime. Add project-specific credentials (dashboard login, etc.) to the `env` section too.

## Repo Structure

```
claude-config/
├── setup.sh                      # Setup script
├── settings.local.example.json   # Settings template
├── docs/
│   └── commands.md               # Command usage reference
├── profiles/
│   ├── fullstack-ts.conf
│   └── laravel-php.conf
└── project/                      # -> .claude/ in target project
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

## Command Reference

See [docs/commands.md](docs/commands.md) for usage of all commands.
