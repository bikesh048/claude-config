#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
BOLD='\033[1m'
NC='\033[0m'

log()   { echo -e "${GREEN}✔${NC} $1"; }
warn()  { echo -e "${YELLOW}⚠${NC} $1"; }
error() { echo -e "${RED}✘${NC} $1" >&2; }
info()  { echo -e "${BLUE}→${NC} $1"; }
header() { echo -e "\n${BOLD}$1${NC}"; }

usage() {
  cat <<EOF
Usage:
  $(basename "$0") <project-path> [--profile=<name>...] [--config=<file>] [--update] [--copy]
  $(basename "$0") <project-path> --add <type> <name> [--copy]
  $(basename "$0") --list-profiles

Options:
  --profile=<name>      Project profile (repeatable). No --profile = install all.
  --update              Update mode: show diffs, prompt accept/skip per file
  --copy                Copy mode: copy files instead of symlinking (default is symlink).
                        Use when you want project-specific overrides that don't flow back.
  --add <type> <name>   Add a single item to a project. Type: skill, rule, command, agent.
  --list-profiles       List available profiles

Symlink mode (default):
  Files are symlinked from claude-config into the project's .claude/ directory.
  Edits in the project flow back to claude-config automatically.
  Files needing token replacement are always copied (not linked).

Examples:
  $(basename "$0") ~/projects/tripcart-builder --profile=fullstack-ts
  $(basename "$0") ~/projects/tripcart-builder --profile=fullstack-ts --profile=laravel-php
  $(basename "$0") ~/projects/tripcart-builder                        # installs all profiles
  $(basename "$0") ~/projects/tripcart-builder --update
  $(basename "$0") ~/projects/tripcart-builder --add skill my-new-skill
  $(basename "$0") ~/projects/tripcart-builder --add rule my-rule.md
  $(basename "$0") ~/projects/tripcart-builder --add command my-cmd.md
  $(basename "$0") ~/projects/tripcart-builder --add agent my-agent.md
EOF
  exit 1
}

# ---------- List profiles ----------
list_profiles() {
  header "Available profiles:"
  for conf in "$SCRIPT_DIR/profiles/"*.conf; do
    # shellcheck disable=SC1090
    (
      source "$conf"
      printf "  ${BOLD}%-20s${NC} %s\n" "$PROFILE_NAME" "$PROFILE_DESC"
      printf "    Rules:    %s\n" "${RULES[*]}"
      printf "    Commands: %s\n" "${COMMANDS[*]}"
      printf "    Skills:   %s\n" "${SKILLS[*]}"
    )
    echo ""
  done
}

# ---------- Create .claude-secrets ----------
create_secrets() {
  local project_path="$1"
  local secrets_file="$project_path/.claude-secrets"

  if [ -f "$secrets_file" ]; then
    warn ".claude-secrets already exists — skipping"
    return
  fi

  header "Create .claude-secrets"
  echo "  This file stores project config and API keys (gitignored)."
  echo ""

  read -rp "OpenProject base URL: " OP_BASE_URL
  read -rp "OpenProject project slug: " OP_PROJECT_SLUG
  read -rp "OpenProject project ID: " OP_PROJECT_ID
  read -rp "GitHub org/repo: " GITHUB_ORG_REPO
  read -rp "Base branch [develop]: " BASE_BRANCH
  BASE_BRANCH="${BASE_BRANCH:-develop}"
  read -rp "OpenProject API key: " OPENPROJECT_API_KEY

  cat > "$secrets_file" << EOF
export OP_BASE_URL="${OP_BASE_URL}"
export OP_PROJECT_SLUG="${OP_PROJECT_SLUG}"
export OP_PROJECT_ID="${OP_PROJECT_ID}"
export GITHUB_ORG_REPO="${GITHUB_ORG_REPO}"
export BASE_BRANCH="${BASE_BRANCH}"
export OPENPROJECT_API_KEY="${OPENPROJECT_API_KEY}"
EOF
  chmod 600 "$secrets_file"
  log "Created .claude-secrets"

  # Add to .gitignore if not already there
  if ! grep -q '.claude-secrets' "$project_path/.gitignore" 2>/dev/null; then
    echo ".claude-secrets" >> "$project_path/.gitignore"
    log "Added .claude-secrets to .gitignore"
  fi
}

# ---------- Exclusion prompt ----------
# Reads array named $1, prompts for exclusions, writes result back via eval
prompt_exclusions() {
  local arr_name="$1"
  local label="$2"

  eval "local items=(\"\${${arr_name}[@]}\")"

  if [ ${#items[@]} -eq 0 ]; then
    return
  fi

  echo ""
  info "$label: ${items[*]}"
  read -rp "  Exclude any? (comma-separated names, or Enter to keep all): " exclusions

  if [ -n "$exclusions" ]; then
    local new_items=()
    IFS=',' read -ra excluded <<< "$exclusions"
    local trimmed_exclusions=()
    for e in "${excluded[@]}"; do
      trimmed_exclusions+=("$(echo "$e" | xargs)")
    done

    for item in "${items[@]}"; do
      local skip=false
      for exc in "${trimmed_exclusions[@]}"; do
        if [[ "$item" == "$exc" || "$item" == "${exc}.md" || "${item%.md}" == "$exc" ]]; then
          skip=true
          break
        fi
      done
      if [ "$skip" = false ]; then
        new_items+=("$item")
      else
        warn "Excluded: $item"
      fi
    done
    eval "${arr_name}=(\"\${new_items[@]}\")"
  fi
}

# ---------- Install a single file (symlink, copy, or update) ----------
install_file() {
  local src="$1"
  local dest="$2"
  local update_mode="${3:-false}"
  local link_mode="${4:-false}"

  if [ "$update_mode" = true ] && [ -f "$dest" ]; then
    # If already linked to the right place, no change needed
    if [ -L "$dest" ] && [ "$link_mode" = true ]; then
      if [ "$src" = "$(realpath "$dest")" ]; then
        return 1
      fi
    fi

    if diff -q "$src" "$dest" > /dev/null 2>&1; then
      return 1  # No change
    fi

    echo ""
    echo -e "${YELLOW}--- Changed: $(basename "$dest")${NC}"
    diff --color=auto "$dest" "$src" || true
    read -rp "  Accept update? [Y/n]: " answer
    if [[ "${answer:-Y}" =~ ^[Nn] ]]; then
      warn "Skipped: $(basename "$dest")"
      return 1
    fi
  fi

  # Remove existing file/symlink before installing
  [ -e "$dest" ] || [ -L "$dest" ] && rm -f "$dest"

  if [ "$link_mode" = true ]; then
    ln -s "$src" "$dest"
  else
    cp "$src" "$dest"
  fi
  return 0
}

# ---------- Project install ----------
install_project() {
  local project_path="$1"
  local profile_name="$2"
  local update_mode="${3:-false}"
  local link_mode="${4:-false}"

  if [ ! -d "$project_path" ]; then
    error "Project path not found: $project_path"
    exit 1
  fi

  # Load profile
  local profile_file="$SCRIPT_DIR/profiles/${profile_name}.conf"
  if [ ! -f "$profile_file" ]; then
    error "Profile not found: $profile_name"
    echo "  Available profiles:"
    for f in "$SCRIPT_DIR/profiles/"*.conf; do
      echo "    - $(basename "${f%.conf}")"
    done
    exit 1
  fi

  # shellcheck disable=SC1090
  source "$profile_file"

  header "Profile: $PROFILE_NAME"
  echo "  $PROFILE_DESC"

  # Create .claude-secrets if it doesn't exist
  create_secrets "$project_path"

  # Show what will be installed and allow exclusions
  header "Review items to install"
  prompt_exclusions RULES "Rules"
  prompt_exclusions COMMANDS "Commands"
  prompt_exclusions SKILLS "Skills"

  local target="$project_path/.claude"
  mkdir -p "$target"

  local mode_label="copy"
  if [ "$link_mode" = true ]; then
    mode_label="link"
  fi

  # --- Install settings ---
  header "Installing to $target (mode: $mode_label)"

  # settings.json is always copied (project-specific permissions)
  if install_file "$SCRIPT_DIR/project/settings.json" "$target/settings.json" "$update_mode" false; then
    log "Installed settings.json (copied)"
  fi

  # --- Install shared rule directories (common, typescript, etc.) ---
  if [ ${#SHARED_RULES_DIRS[@]} -gt 0 ]; then
    for dir in "${SHARED_RULES_DIRS[@]}"; do
      local src_dir="$SCRIPT_DIR/project/rules/$dir"
      if [ -d "$src_dir" ]; then
        mkdir -p "$target/rules/$dir"
        for rule_file in "$src_dir"/*.md; do
          [ -f "$rule_file" ] || continue
          local fname
          fname="$(basename "$rule_file")"
          if install_file "$rule_file" "$target/rules/$dir/$fname" "$update_mode" "$link_mode"; then
            log "Installed rule: $dir/$fname"
          fi
        done
      else
        warn "Shared rules dir not found: $dir (skipped)"
      fi
    done
  fi

  # --- Install project-specific rules ---
  if [ ${#RULES[@]} -gt 0 ]; then
    mkdir -p "$target/rules"
    for rule in "${RULES[@]}"; do
      local src="$SCRIPT_DIR/project/rules/$rule"
      if [ -f "$src" ]; then
        if install_file "$src" "$target/rules/$rule" "$update_mode" "$link_mode"; then
          log "Installed rule: $rule"
        fi
      else
        warn "Rule not found: $rule (skipped)"
      fi
    done
  fi

  # --- Install agents ---
  if [ ${#AGENTS[@]} -gt 0 ]; then
    mkdir -p "$target/agents"
    for agent in "${AGENTS[@]}"; do
      local src="$SCRIPT_DIR/project/agents/$agent"
      if [ -f "$src" ]; then
        if install_file "$src" "$target/agents/$agent" "$update_mode" "$link_mode"; then
          log "Installed agent: $agent"
        fi
      else
        warn "Agent not found: $agent (skipped)"
      fi
    done
  fi

  # --- Install commands ---
  if [ ${#COMMANDS[@]} -gt 0 ]; then
    mkdir -p "$target/commands"
    for cmd in "${COMMANDS[@]}"; do
      local src="$SCRIPT_DIR/project/commands/$cmd"
      if [ -f "$src" ]; then
        if install_file "$src" "$target/commands/$cmd" "$update_mode" "$link_mode"; then
          log "Installed command: $cmd"
        fi
      else
        warn "Command not found: $cmd (skipped)"
      fi
    done
  fi

  # --- Install skills ---
  if [ ${#SKILLS[@]} -gt 0 ]; then
    for skill in "${SKILLS[@]}"; do
      local src_dir="$SCRIPT_DIR/project/skills/$skill"
      if [ -d "$src_dir" ]; then
        mkdir -p "$target/skills/$skill"
        local skill_changed=false
        while IFS= read -r -d '' file; do
          local rel="${file#"$src_dir"/}"
          mkdir -p "$target/skills/$skill/$(dirname "$rel")"
          if install_file "$file" "$target/skills/$skill/$rel" "$update_mode" "$link_mode"; then
            skill_changed=true
          fi
        done < <(/usr/bin/find "$src_dir" -type f -print0)
        if [ "$skill_changed" = true ]; then
          log "Installed skill: $skill"
        fi
      else
        warn "Skill not found: $skill (skipped)"
      fi
    done
  fi


  # --- Install templates ---
  if [ ${#TEMPLATES[@]} -gt 0 ]; then
    mkdir -p "$project_path/.github"
    for tmpl in "${TEMPLATES[@]}"; do
      local src="$SCRIPT_DIR/project/templates/$tmpl"
      if [ -f "$src" ]; then
        local dest="$project_path/.github/$tmpl"
        if [ "$update_mode" = true ]; then
          if install_file "$src" "$dest" "$update_mode" "$link_mode"; then
            log "Installed template: $tmpl"
          fi
        elif [ ! -f "$dest" ]; then
          install_file "$src" "$dest" false "$link_mode"
          log "Installed template: $tmpl"
        else
          warn "Template already exists: $tmpl (skipped)"
        fi
      fi
    done
  fi

  # --- Save config version ---
  echo "$profile_name:$(date +%Y%m%d%H%M%S):$mode_label" > "$target/.config-version"

  echo ""
  log "Profile installed: $PROFILE_NAME (mode: $mode_label)"
  echo ""
  if [ "$link_mode" = true ]; then
    echo "  All files symlinked to claude-config repo."
    echo "  Edits in .claude/ flow back to claude-config automatically."
  fi
  echo "  Config loaded at runtime from .claude-secrets."
}

# ---------- Add single item ----------
add_item() {
  local project_path="$1"
  local item_type="$2"
  local item_name="$3"
  local link_mode="${4:-true}"

  if [ ! -d "$project_path" ]; then
    error "Project path not found: $project_path"
    exit 1
  fi

  local target="$project_path/.claude"

  case "$item_type" in
    skill)
      local src_dir="$SCRIPT_DIR/project/skills/$item_name"
      if [ ! -d "$src_dir" ]; then
        error "Skill not found: $item_name"
        echo "  Available:"
        for d in "$SCRIPT_DIR/project/skills/"*/; do
          echo "    - $(basename "$d")"
        done
        exit 1
      fi
      mkdir -p "$target/skills/$item_name"
      while IFS= read -r -d '' file; do
        local rel="${file#"$src_dir"/}"
        mkdir -p "$target/skills/$item_name/$(dirname "$rel")"
        install_file "$file" "$target/skills/$item_name/$rel" false "$link_mode"
      done < <(/usr/bin/find "$src_dir" -type f -print0)
      log "Added skill: $item_name"
      ;;
    rule)
      local src="$SCRIPT_DIR/project/rules/$item_name"
      if [ ! -f "$src" ]; then
        error "Rule not found: $item_name"
        echo "  Available:"
        ls "$SCRIPT_DIR/project/rules/"
        exit 1
      fi
      mkdir -p "$target/rules"
      install_file "$src" "$target/rules/$item_name" false "$link_mode"
      log "Added rule: $item_name"
      ;;
    command)
      local src="$SCRIPT_DIR/project/commands/$item_name"
      if [ ! -f "$src" ]; then
        error "Command not found: $item_name"
        echo "  Available:"
        ls "$SCRIPT_DIR/project/commands/"
        exit 1
      fi
      mkdir -p "$target/commands"
      install_file "$src" "$target/commands/$item_name" false "$link_mode"
      log "Added command: $item_name"
      ;;
    agent)
      local src="$SCRIPT_DIR/project/agents/$item_name"
      if [ ! -f "$src" ]; then
        error "Agent not found: $item_name"
        echo "  Available:"
        ls "$SCRIPT_DIR/project/agents/"
        exit 1
      fi
      mkdir -p "$target/agents"
      install_file "$src" "$target/agents/$item_name" false "$link_mode"
      log "Added agent: $item_name"
      ;;
    *)
      error "Unknown type: $item_type (use: skill, rule, command, agent)"
      exit 1
      ;;
  esac
}

# ---------- Parse args ----------
PROJECT_PATH=""
PROFILES=()
UPDATE=false
LINK=true
ADD_TYPE=""
ADD_NAME=""

if [ $# -eq 0 ]; then
  usage
fi

for arg in "$@"; do
  case "$arg" in
    --profile=*)        PROFILES+=("${arg#--profile=}") ;;
    --update)           UPDATE=true ;;
    --copy)             LINK=false ;;
    --add)              ADD_TYPE="__pending__" ;;
    --list-profiles)    list_profiles; exit 0 ;;
    --help|-h)          usage ;;
    -*)                 error "Unknown flag: $arg"; usage ;;
    *)
      if [ "$ADD_TYPE" = "__pending__" ]; then
        ADD_TYPE="$arg"
      elif [ -n "$ADD_TYPE" ] && [ "$ADD_TYPE" != "__pending__" ] && [ -z "$ADD_NAME" ]; then
        ADD_NAME="$arg"
      elif [ -z "$PROJECT_PATH" ]; then
        PROJECT_PATH="$arg"
      else
        error "Unexpected argument: $arg"; usage
      fi
      ;;
  esac
done

# ---------- Execute ----------

# Handle --add command
if [ -n "$ADD_TYPE" ] && [ "$ADD_TYPE" != "__pending__" ]; then
  if [ -z "$PROJECT_PATH" ]; then
    error "Project path required with --add"
    usage
  fi
  if [ -z "$ADD_NAME" ]; then
    error "Name required: --add <type> <name>"
    usage
  fi
  add_item "$PROJECT_PATH" "$ADD_TYPE" "$ADD_NAME" "$LINK"
  exit 0
fi

if [ -z "$PROJECT_PATH" ]; then
  error "Project path required"
  usage
fi

# No --profile given → install all profiles
if [ ${#PROFILES[@]} -eq 0 ]; then
  for conf in "$SCRIPT_DIR/profiles/"*.conf; do
    PROFILES+=("$(basename "${conf%.conf}")")
  done
  info "No --profile specified — installing all: ${PROFILES[*]}"
fi

for profile in "${PROFILES[@]}"; do
  install_project "$PROJECT_PATH" "$profile" "$UPDATE" "$LINK"
done
