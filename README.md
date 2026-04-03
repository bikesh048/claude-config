# TripcartHQ Claude Config

Shared Claude Code configuration for the organization. Symlinks commands, rules, agents, and skills into any project.

## Quick Start

```bash
git clone git@github.com:TripcartHQ/claude-config.git
cd claude-config

# Install into a project (symlinks commands + PR template)
./setup.sh ~/projects/tripcart-builder

# First run prompts for settings.local.json (API keys, project config)
```

## Usage

```bash
# Default setup — commands + templates
./setup.sh ~/projects/your-project

# Replace existing files with symlinks
./setup.sh ~/projects/your-project --force

# Add extras
./setup.sh ~/projects/your-project --add rule                    # all rules
./setup.sh ~/projects/your-project --add rule security.md         # specific rule
./setup.sh ~/projects/your-project --add agent code-reviewer.md
./setup.sh ~/projects/your-project --add skill playwright-cli

# Remove
./setup.sh ~/projects/your-project --remove                      # remove everything
./setup.sh ~/projects/your-project --remove command op.md         # specific file
./setup.sh ~/projects/your-project --remove rule                  # all rules
```

## What Gets Installed

**By default** (every project):
- `commands/` — op, deliver, dispatch, pr, interview
- `templates/` — PR template (to `.github/`)
- `settings.json` — shared permissions (copied)
- `settings.local.json` — project config + API keys (created on first run, gitignored)

**Via --add** (optional per project):
- `rules/` — coding standards (coding-style, security, testing, etc.)
- `rules/typescript/` — TypeScript-specific patterns
- `agents/` — code-reviewer, security-auditor
- `skills/` — reusable skill references

## How It Works

- All shared files are **symlinked** — edits flow back to claude-config
- Symlinked files are **auto-added to .gitignore** (per file, not per directory)
- Project-specific files in the same dirs are **not affected**
- Running setup again is **idempotent** — skips existing, cleans stale symlinks
- `--force` replaces existing files and untracks them from git

## settings.local.json

Created per project on first run. Loaded by Claude Code automatically at session start (zero context cost):

```json
{
  "env": {
    "OP_BASE_URL": "https://openproject.codewingsolutions.com",
    "OP_PROJECT_SLUG": "tripcart-new",
    "GITHUB_ORG_REPO": "TripcartHQ/tripcart-builder",
    "BASE_BRANCH": "develop",
    "OPENPROJECT_API_KEY": "your-api-key"
  }
}
```

## Repo Structure

```
claude-config/
├── setup.sh
├── settings.json                 # Shared permissions
├── settings.local.json.example   # Template for project config
├── docs/commands.md              # Command usage reference
├── commands/                     # Installed by default
│   ├── op.md
│   ├── deliver.md
│   ├── dispatch.md
│   ├── pr.md
│   └── interview.md
├── templates/                    # Installed by default
│   └── pull_request_template.md
├── rules/                        # Available via --add
│   ├── *.md
│   └── typescript/
└── agents/                       # Available via --add
    ├── code-reviewer.md
    └── security-auditor.md
```

## For New Team Members

1. Clone this repo
2. Run `./setup.sh ~/projects/your-project`
3. Fill in `settings.local.json` when prompted
4. Done — commands are available

## Command Reference

See [docs/commands.md](docs/commands.md)
