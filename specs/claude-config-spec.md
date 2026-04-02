# Claude Config System Spec

## Overview

Centralized Claude Code configuration for TripcartHQ projects. Two repos work together:

1. **`TripcartHQ/claude-config`** (team-shared) — curated rules, commands, skills, agents, profiles
2. **`bikeshrestha/dotfiles`** (personal) — personal agents, hooks, scripts, extra commands via GNU Stow

## Architecture

```
┌──────────────────────────────────────────────────┐
│  claude-config (team repo)                       │
│                                                  │
│  global/          → ~/.claude/ (agents, rules)   │
│  project/         → <repo>/.claude/ (committed)  │
│  profiles/        preset bundles per stack        │
│  config/          machine profiles + templates    │
│  install.sh       profile-based installer         │
└──────────────────────────────────────────────────┘
         │ install.sh --global
         ▼
┌──────────────────────────────────────────────────┐
│  ~/.claude/                                      │
│                                                  │
│  ① Team config (from claude-config/global)       │
│  ② Personal config (from dotfiles/claude/.claude)│
│     → stow symlinks, never overwrites team files │
└──────────────────────────────────────────────────┘
         │ install.sh <project-path> --profile=fullstack-ts
         ▼
┌──────────────────────────────────────────────────┐
│  <project>/.claude/   (committed to project git) │
│                                                  │
│  settings.json    permissions + deny list         │
│  commands/        OP + PR commands                │
│  skills/          project skills                  │
│  rules/           stack-specific rules            │
│  specs/           feature specs                   │
│  templates/       PR template                     │
└──────────────────────────────────────────────────┘
```

## Profiles

### `fullstack-ts` (NestJS + Next.js + Prisma + Gutenberg)

**Rules:** nestjs.md, nextjs.md, prisma.md, gutenberg.md, cache.md, env-management.md, pipeline.md
**Commands:** create-pr, deliver, dispatch, op-create, op-read, op-update
**Skills:** create-pr, op-update, ticket, domain-support, extraction-fix, import-fix, playwright-cli, learned
**Templates:** pull_request_template.md

### `laravel-php` (Laravel + PHP)

**Rules:** laravel.md, cache.md, env-management.md, pipeline.md (+ PHP-specific rules TBD)
**Commands:** create-pr, deliver, op-create, op-read, op-update
**Skills:** create-pr, op-update, ticket
**Templates:** pull_request_template.md

### Shared across all profiles

**Commands:** op-create, op-read, op-update, create-pr
**Skills:** create-pr, op-update, ticket
**Rules:** pipeline.md, env-management.md

## Install Script Behavior

### Global install

```bash
./install.sh --global
```

1. Copies `global/agents/` → `~/.claude/agents/`
2. Copies `global/rules/` → `~/.claude/rules/`
3. Applies `global/settings.json.template` → `~/.claude/settings.json` (skip if exists)
4. Creates machine profile from template if not present

### Project install

```bash
./install.sh /path/to/project --profile=fullstack-ts
```

1. Reads profile definition (list of rules, commands, skills, templates)
2. Prints full list of what will be installed
3. Prompts: `Exclude any? (comma-separated names or Enter to skip):`
4. Replaces tokens (`{{OP_BASE_URL}}`, `{{GITHUB_ORG_REPO}}`, etc.) from:
   - `.claude-config.env` in the target project (if exists), OR
   - Interactive prompts for missing values
5. Copies selected items into `<project>/.claude/`
6. Files are committed to the project repo (not symlinked)

### Update flow

```bash
./install.sh /path/to/project --profile=fullstack-ts --update
```

1. Compares each file in claude-config with the project's `.claude/`
2. Shows diff for changed files
3. Prompts accept/skip per file
4. Skips files not in the profile

## Machine Profiles

Located in `config/machines/`:

```
config/
├── config.example.env        # Token values (OP_BASE_URL, etc.)
├── machines/
│   ├── mac.env               # macOS-specific: Homebrew paths, etc.
│   ├── linux.env             # Linux-specific: apt paths, etc.
│   └── windows.env           # WSL-specific paths
```

Machine profiles provide:
- MCP server connection strings (MySQL host/port differ per machine)
- Absolute paths (statusline script, etc.)
- Platform-specific tool paths

Applied during `--global` install:
```bash
./install.sh --global --machine=mac
```

## Personal Config (dotfiles)

Structure in `~/dotfiles/`:

```
dotfiles/
├── claude/
│   └── .claude/
│       ├── agents/           # Personal agents (15 total)
│       ├── commands/         # Personal commands (60+)
│       ├── hooks/            # Hook configs
│       ├── scripts/          # Hook scripts (session-start, observe, etc.)
│       ├── skills/           # Personal skills (25+)
│       └── AGENTS.md         # Agent index
├── zsh/
│   └── .zshrc
├── nvim/
│   └── .config/nvim/
└── wezterm/
    └── .config/wezterm/
```

### Install order (team wins on conflicts)

```bash
# 1. Install team config first
cd ~/projects/claude-config
./install.sh --global --machine=mac

# 2. Stow personal config on top (--no-folding prevents dir merges)
cd ~/dotfiles
stow --no-folding claude
# Stow will skip files that already exist (team files), only add new ones
```

### Conflict resolution

- Team files installed first are **never overwritten** by personal stow
- If `stow` reports a conflict, the team version stays
- Personal config only adds files that don't exist in team config
- To override a team file personally: remove the team copy, then stow creates the personal symlink

## Token Replacement

| Token | Example Value | Source |
|-------|--------------|--------|
| `{{OP_BASE_URL}}` | `https://openproject.codewingsolutions.com` | config.env |
| `{{OP_PROJECT_SLUG}}` | `tripcart-new` | config.env |
| `{{OP_PROJECT_ID}}` | `5` | config.env |
| `{{GITHUB_ORG_REPO}}` | `TripcartHQ/tripcart-builder` | config.env |
| `{{BASE_BRANCH}}` | `develop` | config.env |

## Repo Structure (Final)

```
claude-config/
├── install.sh
├── README.md
├── config/
│   ├── config.example.env
│   └── machines/
│       ├── mac.env
│       ├── linux.env
│       └── windows.env
├── profiles/
│   ├── fullstack-ts.conf
│   └── laravel-php.conf
├── global/
│   ├── agents/
│   ├── rules/
│   │   ├── common/
│   │   └── typescript/
│   └── settings.json.template
├── project/
│   ├── settings.json
│   ├── commands/
│   ├── skills/
│   ├── rules/
│   ├── specs/
│   └── templates/
└── draft/
```

## Implementation Phases

### Phase 1: Core installer
- Profile definitions (`fullstack-ts.conf`, `laravel-php.conf`)
- Rewrite `install.sh` with profile selection + exclusion prompt
- Machine profile support (`--machine` flag)
- Token replacement from config.env

### Phase 2: Personal config in dotfiles
- Create `dotfiles/claude/.claude/` structure
- Move personal agents, hooks, scripts, commands, skills from `~/.claude/`
- Document stow install order in dotfiles README

### Phase 3: Laravel profile
- Create Laravel/PHP-specific rules
- Test install on legacy tripcart Laravel project
- Add PHP rules to `global/rules/php/`

### Phase 4: Update flow
- `--update` flag for install.sh
- File diffing and selective accept/skip
- Version tracking (optional: `.claude/.config-version` file)
