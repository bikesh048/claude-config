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
  $(basename "$0") <project-path> [--profile=<name>...]
  $(basename "$0") <project-path> --add <type> <name>
  $(basename "$0") --list-profiles

Options:
  --profile=<name>      Project profile (repeatable). No --profile = install all.
  --add <type> <name>   Add a single item. Type: skill, rule, command, agent.
  --list-profiles       List available profiles

All files are symlinked from claude-config into the project's .claude/ directory.
Edits in the project flow back to claude-config automatically.
Running setup again is safe — it cleans stale symlinks and refreshes .gitignore.

Examples:
  $(basename "$0") ~/projects/tripcart-builder --profile=fullstack-ts
  $(basename "$0") ~/projects/tripcart-builder --profile=fullstack-ts --profile=laravel-php
  $(basename "$0") ~/projects/tripcart-builder                        # installs all profiles
  $(basename "$0") ~/projects/tripcart-builder --add command my-cmd.md
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
      printf "    Commands: %s\n" "${COMMANDS[*]}"
    )
    echo ""
  done
}

# ---------- Create settings.local.json ----------
create_local_settings() {
  local project_path="$1"
  local local_settings="$project_path/.claude/settings.local.json"

  # Ensure settings.local.json is gitignored
  local gitignore="$project_path/.gitignore"
  if ! grep -q 'settings.local.json' "$gitignore" 2>/dev/null; then
    echo ".claude/settings.local.json" >> "$gitignore"
    log "Added settings.local.json to .gitignore"
  fi

  if [ -f "$local_settings" ]; then
    warn "settings.local.json already exists — skipping"
    return
  fi

  header "Create settings.local.json"
  echo "  This file stores project config and API keys (gitignored)."
  echo ""

  read -rp "OpenProject base URL: " OP_BASE_URL
  read -rp "OpenProject project slug: " OP_PROJECT_SLUG
  read -rp "GitHub org/repo: " GITHUB_ORG_REPO
  read -rp "Base branch [develop]: " BASE_BRANCH
  BASE_BRANCH="${BASE_BRANCH:-develop}"
  read -rp "OpenProject API key: " OPENPROJECT_API_KEY

  cat > "$local_settings" << EOF
{
  "env": {
    "OP_BASE_URL": "${OP_BASE_URL}",
    "OP_PROJECT_SLUG": "${OP_PROJECT_SLUG}",
    "GITHUB_ORG_REPO": "${GITHUB_ORG_REPO}",
    "BASE_BRANCH": "${BASE_BRANCH}",
    "OPENPROJECT_API_KEY": "${OPENPROJECT_API_KEY}"
  }
}
EOF
  log "Created settings.local.json"
}

# ---------- Symlink a file ----------
symlink_file() {
  local src="$1"
  local dest="$2"

  # Already linked correctly — skip
  if [ -L "$dest" ] && [ "$src" = "$(realpath "$dest" 2>/dev/null)" ]; then
    return 1
  fi

  # Remove existing file/symlink
  [ -e "$dest" ] || [ -L "$dest" ] && rm -f "$dest"

  ln -s "$src" "$dest"
  return 0
}

# ---------- Ensure symlinks are in .gitignore ----------
ensure_gitignored() {
  local project_path="$1"
  local target="$project_path/.claude"
  local gitignore="$project_path/.gitignore"

  # Always gitignore settings.json (copied but managed by setup)
  if ! grep -qx '.claude/settings.json' "$gitignore" 2>/dev/null; then
    echo ".claude/settings.json" >> "$gitignore"
  fi

  # Check each symlink in managed dirs
  for managed_dir in rules agents commands skills; do
    [ -d "$target/$managed_dir" ] || continue
    while IFS= read -r -d '' link; do
      local rel="${link#"$project_path/"}"
      if ! grep -qx "$rel" "$gitignore" 2>/dev/null; then
        echo "$rel" >> "$gitignore"
      fi
    done < <(/usr/bin/find "$target/$managed_dir" -type l -print0 2>/dev/null)
  done

  # Check .github for template symlinks
  if [ -d "$project_path/.github" ]; then
    while IFS= read -r -d '' link; do
      local rel="${link#"$project_path/"}"
      if ! grep -qx "$rel" "$gitignore" 2>/dev/null; then
        echo "$rel" >> "$gitignore"
      fi
    done < <(/usr/bin/find "$project_path/.github" -type l -print0 2>/dev/null)
  fi
}

# ---------- Project install ----------
install_project() {
  local project_path="$1"
  local profile_name="$2"

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

  # Create settings.local.json if needed
  create_local_settings "$project_path"

  local target="$project_path/.claude"
  mkdir -p "$target"

  # --- Clean stale symlinks ---
  local stale_count=0
  for managed_dir in rules agents commands skills; do
    [ -d "$target/$managed_dir" ] || continue
    while IFS= read -r -d '' link; do
      if [ ! -e "$link" ]; then
        rm "$link"
        warn "Removed stale symlink: ${link#"$target/"}"
        ((stale_count++)) || true
      fi
    done < <(/usr/bin/find "$target/$managed_dir" -type l -print0 2>/dev/null)
  done
  if [ "$stale_count" -gt 0 ]; then
    log "Cleaned $stale_count stale symlink(s)"
  fi

  header "Installing to $target"

  # --- settings.json (copied — may differ per project) ---
  local settings_dest="$target/settings.json"
  [ -e "$settings_dest" ] || [ -L "$settings_dest" ] && rm -f "$settings_dest"
  cp "$SCRIPT_DIR/config/settings.json" "$settings_dest"
  log "Installed settings.json (copied)"

  # --- Rules (top-level = shared, subdirs = profile-specific) ---
  mkdir -p "$target/rules"
  for rule_file in "$SCRIPT_DIR/config/rules/"*.md; do
    [ -f "$rule_file" ] || continue
    local fname
    fname="$(basename "$rule_file")"
    if symlink_file "$rule_file" "$target/rules/$fname"; then
      log "Installed rule: $fname"
    fi
  done

  if [ ${#SHARED_RULES_DIRS[@]} -gt 0 ]; then
    for dir in "${SHARED_RULES_DIRS[@]}"; do
      local src_dir="$SCRIPT_DIR/config/rules/$dir"
      if [ -d "$src_dir" ]; then
        mkdir -p "$target/rules/$dir"
        for rule_file in "$src_dir"/*.md; do
          [ -f "$rule_file" ] || continue
          local fname
          fname="$(basename "$rule_file")"
          if symlink_file "$rule_file" "$target/rules/$dir/$fname"; then
            log "Installed rule: $dir/$fname"
          fi
        done
      fi
    done
  fi

  # --- Agents ---
  if [ ${#AGENTS[@]} -gt 0 ]; then
    mkdir -p "$target/agents"
    for agent in "${AGENTS[@]}"; do
      local src="$SCRIPT_DIR/config/agents/$agent"
      if [ -f "$src" ]; then
        if symlink_file "$src" "$target/agents/$agent"; then
          log "Installed agent: $agent"
        fi
      else
        warn "Agent not found: $agent (skipped)"
      fi
    done
  fi

  # --- Commands ---
  if [ ${#COMMANDS[@]} -gt 0 ]; then
    mkdir -p "$target/commands"
    for cmd in "${COMMANDS[@]}"; do
      local src="$SCRIPT_DIR/config/commands/$cmd"
      if [ -f "$src" ]; then
        if symlink_file "$src" "$target/commands/$cmd"; then
          log "Installed command: $cmd"
        fi
      else
        warn "Command not found: $cmd (skipped)"
      fi
    done
  fi

  # --- Skills ---
  if [ ${#SKILLS[@]} -gt 0 ]; then
    for skill in "${SKILLS[@]}"; do
      local src_dir="$SCRIPT_DIR/config/skills/$skill"
      if [ -d "$src_dir" ]; then
        mkdir -p "$target/skills/$skill"
        local skill_changed=false
        while IFS= read -r -d '' file; do
          local rel="${file#"$src_dir"/}"
          mkdir -p "$target/skills/$skill/$(dirname "$rel")"
          if symlink_file "$file" "$target/skills/$skill/$rel"; then
            skill_changed=true
          fi
        done < <(/usr/bin/find "$src_dir" -type f -print0)
        if [ "$skill_changed" = true ]; then
          log "Installed skill: $skill"
        fi
      fi
    done
  fi

  # --- Templates ---
  if [ ${#TEMPLATES[@]} -gt 0 ]; then
    mkdir -p "$project_path/.github"
    for tmpl in "${TEMPLATES[@]}"; do
      local src="$SCRIPT_DIR/config/templates/$tmpl"
      if [ -f "$src" ]; then
        if symlink_file "$src" "$project_path/.github/$tmpl"; then
          log "Installed template: $tmpl"
        fi
      fi
    done
  fi

  # --- Update .gitignore ---
  ensure_gitignored "$project_path"

  echo ""
  log "Profile installed: $PROFILE_NAME"
  echo "  All files symlinked to claude-config repo."
  echo "  Edits in .claude/ flow back to claude-config automatically."
}

# ---------- Add single item ----------
add_item() {
  local project_path="$1"
  local item_type="$2"
  local item_name="$3"

  if [ ! -d "$project_path" ]; then
    error "Project path not found: $project_path"
    exit 1
  fi

  local target="$project_path/.claude"

  case "$item_type" in
    skill)
      local src_dir="$SCRIPT_DIR/config/skills/$item_name"
      if [ ! -d "$src_dir" ]; then
        error "Skill not found: $item_name"
        echo "  Available:"
        for d in "$SCRIPT_DIR/config/skills/"*/; do echo "    - $(basename "$d")"; done
        exit 1
      fi
      mkdir -p "$target/skills/$item_name"
      while IFS= read -r -d '' file; do
        local rel="${file#"$src_dir"/}"
        mkdir -p "$target/skills/$item_name/$(dirname "$rel")"
        symlink_file "$file" "$target/skills/$item_name/$rel"
      done < <(/usr/bin/find "$src_dir" -type f -print0)
      log "Added skill: $item_name"
      ;;
    rule)
      local src="$SCRIPT_DIR/config/rules/$item_name"
      [ -f "$src" ] || { error "Rule not found: $item_name"; exit 1; }
      mkdir -p "$target/rules"
      symlink_file "$src" "$target/rules/$item_name"
      log "Added rule: $item_name"
      ;;
    command)
      local src="$SCRIPT_DIR/config/commands/$item_name"
      [ -f "$src" ] || { error "Command not found: $item_name"; exit 1; }
      mkdir -p "$target/commands"
      symlink_file "$src" "$target/commands/$item_name"
      log "Added command: $item_name"
      ;;
    agent)
      local src="$SCRIPT_DIR/config/agents/$item_name"
      [ -f "$src" ] || { error "Agent not found: $item_name"; exit 1; }
      mkdir -p "$target/agents"
      symlink_file "$src" "$target/agents/$item_name"
      log "Added agent: $item_name"
      ;;
    *)
      error "Unknown type: $item_type (use: skill, rule, command, agent)"
      exit 1
      ;;
  esac

  # Refresh .gitignore after adding
  ensure_gitignored "$project_path"
}

# ---------- Parse args ----------
PROJECT_PATH=""
PROFILES=()
ADD_TYPE=""
ADD_NAME=""

if [ $# -eq 0 ]; then
  usage
fi

for arg in "$@"; do
  case "$arg" in
    --profile=*)        PROFILES+=("${arg#--profile=}") ;;
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

# Handle --add
if [ -n "$ADD_TYPE" ] && [ "$ADD_TYPE" != "__pending__" ]; then
  [ -z "$PROJECT_PATH" ] && { error "Project path required with --add"; usage; }
  [ -z "$ADD_NAME" ] && { error "Name required: --add <type> <name>"; usage; }
  add_item "$PROJECT_PATH" "$ADD_TYPE" "$ADD_NAME"
  exit 0
fi

[ -z "$PROJECT_PATH" ] && { error "Project path required"; usage; }

# No --profile → install all
if [ ${#PROFILES[@]} -eq 0 ]; then
  for conf in "$SCRIPT_DIR/profiles/"*.conf; do
    PROFILES+=("$(basename "${conf%.conf}")")
  done
  info "No --profile specified — installing all: ${PROFILES[*]}"
fi

for profile in "${PROFILES[@]}"; do
  install_project "$PROJECT_PATH" "$profile"
done
