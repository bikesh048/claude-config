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
  $(basename "$0") <project-path> [--force]
  $(basename "$0") <project-path> --add <type> [name]
  $(basename "$0") <project-path> --remove [type] [name]
  $(basename "$0") --list [type]

Setup (default):
  Symlinks all commands and templates into the project's .claude/ directory.
  Creates settings.local.json on first run (project config + API keys).

Add extras:
  --add rule [name]       Add one or all rules
  --add agent [name]      Add one or all agents
  --add skill [name]      Add one or all skills
  --add command [name]    Add one or all commands
  --list [type]           List available items (commands, rules, agents, skills)

Remove:
  --remove                Remove all symlinks
  --remove rule [name]    Remove one or all rules
  --remove agent [name]   Remove one or all agents
  --remove skill [name]   Remove one or all skills
  --remove command [name] Remove one or all commands

Options:
  --force                 Replace existing files with symlinks (untrack from git)

Examples:
  $(basename "$0") ~/projects/tripcart-builder
  $(basename "$0") ~/projects/tripcart-builder --force
  $(basename "$0") ~/projects/tripcart-builder --add rule security.md
  $(basename "$0") ~/projects/tripcart-builder --add rule                # add all rules
  $(basename "$0") ~/projects/tripcart-builder --add agent code-reviewer.md
  $(basename "$0") ~/projects/tripcart-builder --remove command op.md
  $(basename "$0") ~/projects/tripcart-builder --remove                  # remove everything
EOF
  exit 1
}

# ---------- Create settings.local.json ----------
create_local_settings() {
  local project_path="$1"
  local target="$project_path/.claude"
  mkdir -p "$target"
  local local_settings="$target/settings.local.json"

  # Ensure gitignored
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
  echo "  Project config and API keys (gitignored)."
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

  # Already linked correctly
  if [ -L "$dest" ] && [ "$src" = "$(realpath "$dest" 2>/dev/null)" ]; then
    return 1
  fi

  # Existing non-symlink file
  if [ -e "$dest" ] && [ ! -L "$dest" ]; then
    if [ "$force" = true ]; then
      local repo_root
      repo_root="$(git -C "$(dirname "$dest")" rev-parse --show-toplevel 2>/dev/null || echo "")"
      if [ -n "$repo_root" ]; then
        local rel="${dest#"$repo_root/"}"
        git -C "$repo_root" rm --cached "$rel" 2>/dev/null || true
      fi
      rm -f "$dest"
    else
      warn "Exists (not symlink): $(basename "$dest") — use --force to replace"
      return 1
    fi
  fi

  [ -L "$dest" ] && rm -f "$dest"
  ln -s "$src" "$dest"
  return 0
}

# ---------- Ensure file is in .gitignore ----------
ensure_gitignored() {
  local project_path="$1"
  local file_path="$2"
  local gitignore="$project_path/.gitignore"
  local rel="${file_path#"$project_path/"}"

  if ! grep -qx "$rel" "$gitignore" 2>/dev/null; then
    echo "$rel" >> "$gitignore"
  fi
}

# ---------- Install items of a type ----------
install_type() {
  local project_path="$1"
  local type="$2"
  local name="${3:-}"
  local force="${4:-false}"
  local target="$project_path/.claude"

  local src_dir="$SCRIPT_DIR/$type"

  # Skills are directories, everything else is files
  if [ "$type" = "skills" ]; then
    if [ -n "$name" ]; then
      # Single skill
      local skill_dir="$src_dir/$name"
      [ -d "$skill_dir" ] || { error "Skill not found: $name"; return 1; }
      mkdir -p "$target/skills/$name"
      while IFS= read -r -d '' file; do
        local rel="${file#"$skill_dir"/}"
        mkdir -p "$target/skills/$name/$(dirname "$rel")"
        if symlink_file "$file" "$target/skills/$name/$rel" "$force"; then
          ensure_gitignored "$project_path" "$target/skills/$name/$rel"
        fi
      done < <(/usr/bin/find "$skill_dir" -type f -print0)
      log "Installed skill: $name"
    else
      # All skills
      for skill_dir in "$src_dir"/*/; do
        [ -d "$skill_dir" ] || continue
        local sname
        sname="$(basename "$skill_dir")"
        install_type "$project_path" "skills" "$sname" "$force"
      done
    fi
    return
  fi

  # Map type to target subdir
  local target_subdir="$type"

  if [ -n "$name" ]; then
    # Single file
    local src="$src_dir/$name"
    [ -f "$src" ] || { error "$type not found: $name"; return 1; }
    mkdir -p "$target/$target_subdir"
    if symlink_file "$src" "$target/$target_subdir/$name" "$force"; then
      ensure_gitignored "$project_path" "$target/$target_subdir/$name"
      log "Installed $type: $name"
    fi
  else
    # All files (including subdirs for rules)
    mkdir -p "$target/$target_subdir"
    for src in "$src_dir"/*.md; do
      [ -f "$src" ] || continue
      local fname
      fname="$(basename "$src")"
      if symlink_file "$src" "$target/$target_subdir/$fname" "$force"; then
        ensure_gitignored "$project_path" "$target/$target_subdir/$fname"
        log "Installed $type: $fname"
      fi
    done
    # Subdirs (e.g. rules/typescript/)
    for subdir in "$src_dir"/*/; do
      [ -d "$subdir" ] || continue
      local dname
      dname="$(basename "$subdir")"
      mkdir -p "$target/$target_subdir/$dname"
      for src in "$subdir"*.md; do
        [ -f "$src" ] || continue
        local fname
        fname="$(basename "$src")"
        if symlink_file "$src" "$target/$target_subdir/$dname/$fname" "$force"; then
          ensure_gitignored "$project_path" "$target/$target_subdir/$dname/$fname"
          log "Installed $type: $dname/$fname"
        fi
      done
    done
  fi
}

# ---------- Remove items ----------
remove_items() {
  local project_path="$1"
  local type="${2:-}"
  local name="${3:-}"
  local target="$project_path/.claude"

  if [ -z "$type" ]; then
    # Remove everything
    header "Removing all symlinks from $target"
    local count=0
    for dir in rules agents commands skills templates; do
      [ -d "$target/$dir" ] || continue
      while IFS= read -r -d '' link; do
        rm "$link"
        info "Removed: ${link#"$target/"}"
        ((count++)) || true
      done < <(/usr/bin/find "$target/$dir" -type l -print0 2>/dev/null)
    done
    # .github templates
    if [ -d "$project_path/.github" ]; then
      while IFS= read -r -d '' link; do
        rm "$link"
        info "Removed: ${link#"$project_path/"}"
        ((count++)) || true
      done < <(/usr/bin/find "$project_path/.github" -type l -print0 2>/dev/null)
    fi
    [ -f "$target/settings.json" ] && rm "$target/settings.json" && ((count++)) || true
    log "Removed $count file(s). Run setup.sh again to reinstall."
    return
  fi

  local target_subdir="$type"

  if [ -n "$name" ]; then
    # Remove specific item
    if [ "$type" = "skills" ]; then
      local skill_dir="$target/skills/$name"
      if [ -d "$skill_dir" ]; then
        rm -rf "$skill_dir"
        log "Removed skill: $name"
      else
        warn "Skill not found: $name"
      fi
    else
      local dest="$target/$target_subdir/$name"
      if [ -L "$dest" ] || [ -f "$dest" ]; then
        rm -f "$dest"
        log "Removed $type: $name"
      else
        warn "$type not found: $name"
      fi
    fi
  else
    # Remove all of type
    local dir="$target/$target_subdir"
    if [ -d "$dir" ]; then
      local count=0
      while IFS= read -r -d '' link; do
        rm "$link"
        ((count++)) || true
      done < <(/usr/bin/find "$dir" -type l -print0 2>/dev/null)
      log "Removed $count $type symlink(s)"
    else
      warn "No $type installed"
    fi
  fi
}

# ---------- Clean stale symlinks ----------
clean_stale() {
  local target="$1"
  local stale_count=0
  for dir in rules agents commands skills templates; do
    [ -d "$target/$dir" ] || continue
    while IFS= read -r -d '' link; do
      if [ ! -e "$link" ]; then
        rm "$link"
        warn "Removed stale: ${link#"$target/"}"
        ((stale_count++)) || true
      fi
    done < <(/usr/bin/find "$target/$dir" -type l -print0 2>/dev/null)
  done
  if [ "$stale_count" -gt 0 ]; then
    log "Cleaned $stale_count stale symlink(s)"
  fi
}

# ---------- Default install ----------
install_default() {
  local project_path="$1"
  local force="${2:-false}"
  local target="$project_path/.claude"

  # Load defaults (copy from example if missing)
  if [ ! -f "$SCRIPT_DIR/defaults.conf" ]; then
    cp "$SCRIPT_DIR/defaults.conf.example" "$SCRIPT_DIR/defaults.conf"
    log "Created defaults.conf from example"
  fi
  # shellcheck disable=SC1091
  source "$SCRIPT_DIR/defaults.conf"

  create_local_settings "$project_path"
  mkdir -p "$target"
  clean_stale "$target"

  header "Installing to $target"

  # settings.json (copied)
  local settings_dest="$target/settings.json"
  [ -e "$settings_dest" ] || [ -L "$settings_dest" ] && rm -f "$settings_dest"
  cp "$SCRIPT_DIR/settings.json" "$settings_dest"
  ensure_gitignored "$project_path" "$settings_dest"
  log "Installed settings.json (copied)"

  # Install each type from defaults.conf
  for type_var in COMMANDS RULES AGENTS SKILLS; do
    local type_dir
    case "$type_var" in
      COMMANDS) type_dir="commands" ;;
      RULES)    type_dir="rules" ;;
      AGENTS)   type_dir="agents" ;;
      SKILLS)   type_dir="skills" ;;
    esac

    eval "local items=(\"\${${type_var}[@]+\"\${${type_var}[@]}\"}\")"
    if [ ${#items[@]} -eq 0 ] || [ -z "${items[0]}" ]; then
      continue
    fi

    if [ "${items[0]}" = "all" ]; then
      install_type "$project_path" "$type_dir" "" "$force"
    else
      for item in "${items[@]}"; do
        install_type "$project_path" "$type_dir" "$item" "$force"
      done
    fi
  done

  # Templates (symlink to both .github/ and .claude/templates/)
  eval "local templates=(\"\${TEMPLATES[@]+\"\${TEMPLATES[@]}\"}\")"
  if [ ${#templates[@]} -gt 0 ] && [ -n "${templates[0]}" ]; then
    mkdir -p "$project_path/.github" "$target/templates"
    local tmpl_files=()
    if [ "${templates[0]}" = "all" ]; then
      for f in "$SCRIPT_DIR/templates/"*.md; do [ -f "$f" ] && tmpl_files+=("$f"); done
    else
      for t in "${templates[@]}"; do [ -f "$SCRIPT_DIR/templates/$t" ] && tmpl_files+=("$SCRIPT_DIR/templates/$t"); done
    fi
    for tmpl in "${tmpl_files[@]}"; do
      local fname
      fname="$(basename "$tmpl")"
      # .github/ (GitHub reads this)
      if symlink_file "$tmpl" "$project_path/.github/$fname" "$force"; then
        ensure_gitignored "$project_path" "$project_path/.github/$fname"
      fi
      # .claude/templates/ (commands reference this)
      if symlink_file "$tmpl" "$target/templates/$fname" "$force"; then
        ensure_gitignored "$project_path" "$target/templates/$fname"
      fi
      log "Installed template: $fname"
    done
  fi

  echo ""
  log "Setup complete!"
  echo "  Use --list to see available items."
  echo "  Use --add/--remove to customize."
}

# ---------- List available items ----------
list_items() {
  local type="${1:-}"

  list_dir() {
    local dir="$1"
    local label="$2"
    if [ -d "$SCRIPT_DIR/$dir" ]; then
      echo -e "\n${BOLD}$label:${NC}"
      if [ "$dir" = "skills" ]; then
        for d in "$SCRIPT_DIR/$dir"/*/; do
          [ -d "$d" ] || continue
          echo "  $(basename "$d")"
        done
      else
        for f in "$SCRIPT_DIR/$dir"/*.md; do
          [ -f "$f" ] || continue
          echo "  $(basename "$f")"
        done
        # Subdirs (e.g. rules/typescript/)
        for d in "$SCRIPT_DIR/$dir"/*/; do
          [ -d "$d" ] || continue
          local dname
          dname="$(basename "$d")"
          for f in "$d"*.md; do
            [ -f "$f" ] || continue
            echo "  $dname/$(basename "$f")"
          done
        done
      fi
    fi
  }

  if [ -z "$type" ]; then
    list_dir "commands" "Commands"
    list_dir "rules" "Rules"
    list_dir "agents" "Agents"
    list_dir "skills" "Skills"
    list_dir "templates" "Templates"
  else
    case "$type" in
      commands|command) list_dir "commands" "Commands" ;;
      rules|rule)      list_dir "rules" "Rules" ;;
      agents|agent)    list_dir "agents" "Agents" ;;
      skills|skill)    list_dir "skills" "Skills" ;;
      templates|template) list_dir "templates" "Templates" ;;
      *) error "Unknown type: $type"; exit 1 ;;
    esac
  fi
}

# ---------- Parse args ----------
PROJECT_PATH=""
FORCE=false
REMOVE=false
ADD_TYPE=""
ADD_NAME=""
REMOVE_TYPE=""
REMOVE_NAME=""

if [ $# -eq 0 ]; then
  usage
fi

args=("$@")
i=0
while [ $i -lt ${#args[@]} ]; do
  arg="${args[$i]}"
  case "$arg" in
    --force)  FORCE=true ;;
    --list)
      list_type=""
      if [ $((i+1)) -lt ${#args[@]} ] && [[ "${args[$((i+1))]}" =~ ^(rules|agents|commands|skills|templates|rule|agent|command|skill|template)$ ]]; then
        ((i++))
        list_type="${args[$i]}"
      fi
      list_items "$list_type"
      exit 0
      ;;
    --remove)
      REMOVE=true
      # Check if next arg is a type (not a flag or path)
      if [ $((i+1)) -lt ${#args[@]} ] && [[ "${args[$((i+1))]}" =~ ^(rules|agents|commands|skills|rule|agent|command|skill)$ ]]; then
        ((i++))
        REMOVE_TYPE="${args[$i]}"
        # Normalize singular to plural
        [[ "$REMOVE_TYPE" == "rule" ]] && REMOVE_TYPE="rules"
        [[ "$REMOVE_TYPE" == "agent" ]] && REMOVE_TYPE="agents"
        [[ "$REMOVE_TYPE" == "command" ]] && REMOVE_TYPE="commands"
        [[ "$REMOVE_TYPE" == "skill" ]] && REMOVE_TYPE="skills"
        # Check for optional name
        if [ $((i+1)) -lt ${#args[@]} ] && [[ ! "${args[$((i+1))]}" == --* ]]; then
          ((i++))
          REMOVE_NAME="${args[$i]}"
        fi
      fi
      ;;
    --add)
      if [ $((i+1)) -lt ${#args[@]} ]; then
        ((i++))
        ADD_TYPE="${args[$i]}"
        # Normalize singular to plural
        [[ "$ADD_TYPE" == "rule" ]] && ADD_TYPE="rules"
        [[ "$ADD_TYPE" == "agent" ]] && ADD_TYPE="agents"
        [[ "$ADD_TYPE" == "command" ]] && ADD_TYPE="commands"
        [[ "$ADD_TYPE" == "skill" ]] && ADD_TYPE="skills"
        # Check for optional name
        if [ $((i+1)) -lt ${#args[@]} ] && [[ ! "${args[$((i+1))]}" == --* ]]; then
          ((i++))
          ADD_NAME="${args[$i]}"
        fi
      else
        error "--add requires a type"; usage
      fi
      ;;
    --help|-h) usage ;;
    -*)        error "Unknown flag: $arg"; usage ;;
    *)
      if [ -z "$PROJECT_PATH" ]; then
        PROJECT_PATH="$arg"
      else
        error "Unexpected argument: $arg"; usage
      fi
      ;;
  esac
  ((i++))
done

# ---------- Execute ----------

[ -z "$PROJECT_PATH" ] && { error "Project path required"; usage; }
[ ! -d "$PROJECT_PATH" ] && { error "Project path not found: $PROJECT_PATH"; exit 1; }

if [ "$REMOVE" = true ]; then
  remove_items "$PROJECT_PATH" "$REMOVE_TYPE" "$REMOVE_NAME"
  exit 0
fi

if [ -n "$ADD_TYPE" ]; then
  install_type "$PROJECT_PATH" "$ADD_TYPE" "$ADD_NAME" "$FORCE"
  exit 0
fi

install_default "$PROJECT_PATH" "$FORCE"
