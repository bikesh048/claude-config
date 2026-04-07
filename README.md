# TripcartHQ Claude Config

Shared Claude Code configuration for the organization. Symlinks commands, rules, agents, and skills into any project.

## Quick Start

**macOS / Linux / Git Bash:**
```bash
git clone git@github.com:TripcartHQ/claude-config.git
cd claude-config

# 1. Choose what to install by default
./setup.sh --config

# 2. Install into a project
./setup.sh ~/projects/tripcart-builder

# First run prompts for settings.local.json (API keys, project config)
```

**Windows (PowerShell):**
```powershell
git clone git@github.com:TripcartHQ/claude-config.git
cd claude-config

# Requires Developer Mode or run PowerShell as Administrator
# Settings > System > For developers > Developer Mode

# 1. Choose what to install by default
.\setup.ps1 -Config

# 2. Install into a project
.\setup.ps1 C:\projects\tripcart-builder
```

## For New Team Members

**macOS / Linux:**
1. Clone this repo
2. Run `./setup.sh --config` to pick your defaults
3. Run `./setup.sh ~/projects/your-project` (or just `./setup.sh` and type the path)
4. Fill in `settings.local.json` when prompted
5. Done

**Windows:**
1. Clone this repo
2. Enable Developer Mode (Settings > System > For developers) **or** run PowerShell as Administrator
3. Run `.\setup.ps1 -Config` to pick your defaults
4. Run `.\setup.ps1 C:\projects\your-project`
5. Fill in `settings.local.json` when prompted
6. Done

## Usage

**macOS / Linux / Git Bash:**
```bash
# Configure what gets installed by default (interactive wizard)
./setup.sh --config

# Install into a project (uses defaults.conf)
./setup.sh                                                        # prompts for path
./setup.sh ~/projects/your-project

# Replace existing files with symlinks
./setup.sh ~/projects/your-project --force

# Add extras beyond defaults
./setup.sh ~/projects/your-project --add rule                     # all rules
./setup.sh ~/projects/your-project --add rule security.md          # specific rule
./setup.sh ~/projects/your-project --add agent code-reviewer.md
./setup.sh ~/projects/your-project --add skill playwright-cli

# Remove
./setup.sh ~/projects/your-project --remove                       # remove everything
./setup.sh ~/projects/your-project --remove command op.md          # specific file
./setup.sh ~/projects/your-project --remove rule                   # all rules

# List available items
./setup.sh --list                                                  # everything
./setup.sh --list rule                                             # just rules
```

**Windows (PowerShell):**
```powershell
# Configure what gets installed by default (interactive wizard)
.\setup.ps1 -Config

# Install into a project (uses defaults.conf)
.\setup.ps1                                                       # prompts for path
.\setup.ps1 C:\projects\your-project

# Replace existing files with symlinks
.\setup.ps1 C:\projects\your-project -Force

# Add extras beyond defaults
.\setup.ps1 C:\projects\your-project -Add rule                    # all rules
.\setup.ps1 C:\projects\your-project -Add rule security.md        # specific rule
.\setup.ps1 C:\projects\your-project -Add agent code-reviewer.md
.\setup.ps1 C:\projects\your-project -Add skill playwright-cli

# Remove
.\setup.ps1 C:\projects\your-project -Remove                      # remove everything
.\setup.ps1 C:\projects\your-project -Remove command op.md        # specific file
.\setup.ps1 C:\projects\your-project -Remove rule                 # all rules

# List available items
.\setup.ps1 -List                                                  # everything
.\setup.ps1 -List rule                                             # just rules
```

## defaults.conf

Controls what gets installed by default. Each developer has their own (gitignored).
Run `./setup.sh --config` to configure interactively, or edit manually.

```bash
# defaults.conf
COMMANDS=("deliver.md" "dispatch.md" "op.md" "pr.md" "interview.md")
RULES=("coding-style.md" "git-workflow.md")
AGENTS=("code-reviewer.md")
SKILLS=()
TEMPLATES=(all)
INSTALL_SETTINGS=false
```

- Use `(all)` for everything in a category
- List specific files: `("security.md" "testing.md")`
- Empty `()` to skip
- Running setup syncs with defaults — adds new items, removes items no longer listed

## What's Available

| Category | Items |
|----------|-------|
| `commands/` | op, deliver, dispatch, pr, interview |
| `rules/` | coding-style, commit-format, development-workflow, git-workflow, patterns, performance, security, testing, typescript/* |
| `agents/` | code-reviewer, security-auditor |
| `skills/` | (add your own) |
| `templates/` | pull_request_template |

Use `./setup.sh --list` to see the full list.

## How It Works

- All shared files are **symlinked** — edits flow back to claude-config
- Symlinked files are **auto-added to .gitignore** (per file, not per directory)
- Project-specific files in the same dirs are **not affected**
- Running setup **syncs** with defaults.conf — adds missing, removes extras
- Existing non-symlink files are **skipped** (prompted to replace, or use `--force`)

## settings.local.json

Created per project on first run. Loaded by Claude Code automatically at session start (zero context cost):

```json
{
  "env": {
    "OP_BASE_URL": "https://your-openproject.example.com",
    "OP_PROJECT_SLUG": "your-project",
    "GITHUB_ORG_REPO": "YourOrg/your-repo",
    "BASE_BRANCH": "develop",
    "OPENPROJECT_API_KEY": "your-api-key"
  }
}
```

**How to get your OpenProject API key:**
My Account -> Access Tokens -> API -> Generate

## Repo Structure

```
claude-config/
├── setup.sh                      # Setup script (macOS/Linux/Git Bash)
├── setup.ps1                     # Setup script (Windows PowerShell)
├── defaults.conf.example         # Default config template
├── settings.json                 # Shared permissions template
├── settings.local.json.example   # Project env template
├── docs/commands.md              # Command usage reference
├── commands/                     # /op, /deliver, /dispatch, /pr, /interview
├── rules/                        # Coding standards + typescript/
├── agents/                       # code-reviewer, security-auditor
├── skills/                       # Reusable skill references
└── templates/                    # PR template
```

## Command Reference

See [docs/commands.md](docs/commands.md)
