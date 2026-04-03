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
  $(basename "$0") <project-path> [--profile=<name>...] [--force]
  $(basename "$0") <project-path> --add <type> <name>
  $(basename "$0") <project-path> --clean
  $(basename "$0") --list-profiles

Options:
  --profile=<name>      Project profile (repeatable). No --profile = install all.
  --force               Replace existing files with symlinks (untrack from git too).
  --clean               Remove all symlinks created by setup (reset to clean state).
  --add <type> <name>   Add a single item. Type: skill, rule, command, agent.
  --list-profiles       List available profiles

Default behavior:
  - If file doesn't exist → create symlink + add to .gitignore
  - If file exists (not a symlink) → skip (use --force to replace)
  - If symlink exists and correct → skip
  - If symlink exists but stale → replace

Examples:
  $(basename "$0") ~/projects/tripcart-builder                        # install all profiles
  $(basename "$0") ~/projects/tripcart-builder --profile=fullstack-ts
  $(basename "$0") ~/projects/tripcart-builder --force                # replace existing files
  $(basename "$0") ~/projects/tripcart-builder --clean                # remove all symlinks
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
  local force="${3:-false}"

  # Already linked correctly — skip
  if [ -L "$dest" ] && [ "$src" = "$(realpath "$dest" 2>/dev/null)" ]; then
    return 1
  fi

  # Existing non-symlink file
  if [ -e "$dest" ] && [ ! -L "$dest" ]; then
    if [ "$force" = true ]; then
      # Untrack from git if tracked
      local rel_to_repo="${dest#"$(git -C "$(dirname "$dest")" rev-parse --show-toplevel 2>/dev/null)/"}"
      git -C "$(dirname "$dest")" rm --cached "$rel_to_repo" 2>/dev/null || true
      rm -f "$dest"
    else
      warn "Exists (not symlink): $(basename "$dest") — use --force to replace"
      return 1
    fi
  fi

  # Remove stale symlink
  [ -L "$dest" ] && rm -f "$dest"

  ln -s "$src" "$dest"
  return 0
}

# ---------- Ensure symlink is in .gitignore ----------
ensure_gitignored() {
  local project_path="$1"
  local file_path="$2"
  local gitignore="$project_path/.gitignore"
  local rel="${file_path#"$project_path/"}"

  if ! grep -qx "$rel" "$gitignore" 2>/dev/null; then
    echo "$rel" >> "$gitignore"
  fi
}

# ---------- Clean all symlinks ----------
clean_symlinks() {
  local project_path="$1"
  local target="$project_path/.claude"

  header "Cleaning symlinks from $target"

  local count=0
  for managed_dir in rules agents commands skills; do
    [ -d "$target/$managed_dir" ] || continue
    while IFS= read -r -d '' link; do
      rm "$link"
      info "Removed: ${link#"$target/"}"
      ((count++)) || true
    done < <(/usr/bin/find "$target/$managed_dir" -type l -print0 2>/dev/null)
  done

  # Clean .github template symlinks
  if [ -d "$project_path/.github" ]; then
    while IFS= read -r -d '' link; do
      rm "$link"
      info "Removed: ${link#"$project_path/"}"
      ((count++)) || true
    done < <(/usr/bin/find "$project_path/.github" -type l -print0 2>/dev/null)
  fi

  # Remove settings.json if it exists
  [ -f "$target/settings.json" ] && rm "$target/settings.json" && ((count++)) || true

  echo ""
  log "Removed $count file(s). Run setup.sh again to reinstall."
}

# ---------- Project install ----------
install_project() {
  local project_path="$1"
  local profile_name="$2"
  local force="${3:-false}"

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

  # --- settings.json (copied) ---
  local settings_dest="$target/settings.json"
  [ -e "$settings_dest" ] || [ -L "$settings_dest" ] && rm -f "$settings_dest"
  cp "$SCRIPT_DIR/config/settings.json" "$settings_dest"
  ensure_gitignored "$project_path" "$settings_dest"
  log "Installed settings.json (copied)"

  # --- Rules ---
  mkdir -p "$target/rules"
  for rule_file in "$SCRIPT_DIR/config/rules/"*.md; do
    [ -f "$rule_file" ] || continue
    local fname
    fname="$(basename "$rule_file")"
    if symlink_file "$rule_file" "$target/rules/$fname" "$force"; then
      ensure_gitignored "$project_path" "$target/rules/$fname"
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
          if symlink_file "$rule_file" "$target/rules/$dir/$fname" "$force"; then
            ensure_gitignored "$project_path" "$target/rules/$dir/$fname"
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
        if symlink_file "$src" "$target/agents/$agent" "$force"; then
          ensure_gitignored "$project_path" "$target/agents/$agent"
          log "Installed agent: $agent"
        fi
      fi
    done
  fi

  # --- Commands ---
  if [ ${#COMMANDS[@]} -gt 0 ]; then
    mkdir -p "$target/commands"
    for cmd in "${COMMANDS[@]}"; do
      local src="$SCRIPT_DIR/config/commands/$cmd"
      if [ -f "$src" ]; then
        if symlink_file "$src" "$target/commands/$cmd" "$force"; then
          ensure_gitignored "$project_path" "$target/commands/$cmd"
          log "Installed command: $cmd"
        fi
      fi
    done
  fi

  # --- Skills ---
  if [ ${#SKILLS[@]} -gt 0 ]; then
    for skill in "${SKILLS[@]}"; do
      local src_dir="$SCRIPT_DIR/config/skills/$skill"
      if [ -d "$src_dir" ]; then
        mkdir -p "$target/skills/$skill"
        while IFS= read -r -d '' file; do
          local rel="${file#"$src_dir"/}"
          mkdir -p "$target/skills/$skill/$(dirname "$rel")"
          if symlink_file "$file" "$target/skills/$skill/$rel" "$force"; then
            ensure_gitignored "$project_path" "$target/skills/$skill/$rel"
          fi
        done < <(/usr/bin/find "$src_dir" -type f -print0)
        log "Installed skill: $skill"
      fi
    done
  fi

  # --- Templates ---
  if [ ${#TEMPLATES[@]} -gt 0 ]; then
    mkdir -p "$project_path/.github"
    for tmpl in "${TEMPLATES[@]}"; do
      local src="$SCRIPT_DIR/config/templates/$tmpl"
      if [ -f "$src" ]; then
        if symlink_file "$src" "$project_path/.github/$tmpl" "$force"; then
          ensure_gitignored "$project_path" "$project_path/.github/$tmpl"
          log "Installed template: $tmpl"
        fi
      fi
    done
  fi

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
        ensure_gitignored "$project_path" "$target/skills/$item_name/$rel"
      done < <(/usr/bin/find "$src_dir" -type f -print0)
      log "Added skill: $item_name"
      ;;
    rule)
      local src="$SCRIPT_DIR/config/rules/$item_name"
      [ -f "$src" ] || { error "Rule not found: $item_name"; exit 1; }
      mkdir -p "$target/rules"
      symlink_file "$src" "$target/rules/$item_name"
      ensure_gitignored "$project_path" "$target/rules/$item_name"
      log "Added rule: $item_name"
      ;;
    command)
      local src="$SCRIPT_DIR/config/commands/$item_name"
      [ -f "$src" ] || { error "Command not found: $item_name"; exit 1; }
      mkdir -p "$target/commands"
      symlink_file "$src" "$target/commands/$item_name"
      ensure_gitignored "$project_path" "$target/commands/$item_name"
      log "Added command: $item_name"
      ;;
    agent)
      local src="$SCRIPT_DIR/config/agents/$item_name"
      [ -f "$src" ] || { error "Agent not found: $item_name"; exit 1; }
      mkdir -p "$target/agents"
      symlink_file "$src" "$target/agents/$item_name"
      ensure_gitignored "$project_path" "$target/agents/$item_name"
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
FORCE=false
CLEAN=false
ADD_TYPE=""
ADD_NAME=""

if [ $# -eq 0 ]; then
  usage
fi

for arg in "$@"; do
  case "$arg" in
    --profile=*)        PROFILES+=("${arg#--profile=}") ;;
    --force)            FORCE=true ;;
    --clean)            CLEAN=true ;;
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

[ -z "$PROJECT_PATH" ] && { error "Project path required"; usage; }

# Handle --clean
if [ "$CLEAN" = true ]; then
  clean_symlinks "$PROJECT_PATH"
  exit 0
fi

# Handle --add
if [ -n "$ADD_TYPE" ] && [ "$ADD_TYPE" != "__pending__" ]; then
  [ -z "$ADD_NAME" ] && { error "Name required: --add <type> <name>"; usage; }
  add_item "$PROJECT_PATH" "$ADD_TYPE" "$ADD_NAME"
  exit 0
fi

# No --profile → install all
if [ ${#PROFILES[@]} -eq 0 ]; then
  for conf in "$SCRIPT_DIR/profiles/"*.conf; do
    PROFILES+=("$(basename "${conf%.conf}")")
  done
  info "No --profile specified — installing all: ${PROFILES[*]}"
fi

for profile in "${PROFILES[@]}"; do
  install_project "$PROJECT_PATH" "$profile" "$FORCE"
done
