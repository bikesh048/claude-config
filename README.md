# TripcartHQ Claude Config

Shared Claude Code configuration for all TripcartHQ projects. Provides standardized commands, skills, rules, agents, and permissions — all installed at the project level.

## Quick Start

### New team member

```bash
git clone git@github.com:TripcartHQ/claude-config.git
cd claude-config

# Set up secrets
cp config.example.env ~/.claude-secrets
# Edit ~/.claude-secrets with your API keys
chmod 600 ~/.claude-secrets

# Add to your shell profile (~/.zprofile or ~/.zshrc)
echo '[ -f ~/.claude-secrets ] && source ~/.claude-secrets' >> ~/.zprofile
```

### Install into a project

```bash
# Option 1: Interactive (prompts for values)
./setup.sh /path/to/your-project --profile=fullstack-ts

# Option 2: From config file
cp config.example.env /path/to/your-project/.claude-config.env
# Edit .claude-config.env with project values
./setup.sh /path/to/your-project --profile=fullstack-ts
```

By default, files are **symlinked** back to this repo. Edits in any project flow back here automatically. Use `--copy` if you want independent copies instead.

### Add a single item

```bash
./setup.sh /path/to/project --add skill my-skill
./setup.sh /path/to/project --add rule my-rule.md
./setup.sh /path/to/project --add command my-cmd.md
./setup.sh /path/to/project --add agent my-agent.md
```

### Update an existing project

```bash
./setup.sh /path/to/your-project --profile=fullstack-ts --update
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

## Configuration Tokens

The install script replaces these tokens in files that need project-specific values (these files are copied, not symlinked):

| Token | Description |
|-------|-------------|
| `{{OP_BASE_URL}}` | OpenProject instance URL |
| `{{OP_PROJECT_SLUG}}` | OP project identifier |
| `{{OP_PROJECT_ID}}` | OP numeric project ID |
| `{{GITHUB_ORG_REPO}}` | GitHub org/repo |
| `{{BASE_BRANCH}}` | Default PR target branch |

## Environment Variables

Required in your environment (via `~/.claude-secrets`):

| Variable | Purpose |
|----------|---------|
| `OPENPROJECT_API_KEY` | OP API authentication |

## Repo Structure

```
claude-config/
├── setup.sh              # Install script
├── config.example.env      # Token values template
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
    │   ├── common/         # Shared coding standards
    │   ├── typescript/     # TS-specific rules
    │   └── *.md            # Project rules
    ├── skills/
    └── templates/
```

## Symlink vs Copy

| Mode | When | Behavior |
|------|------|----------|
| **Symlink** (default) | Shared files | Edit once, all projects update |
| **Copy** (auto) | Files with `{{tokens}}` | Project-specific values baked in |
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
