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
  $(basename "$0") --global [--machine=mac|linux|windows]
  $(basename "$0") <project-path> --profile=<name> [--config=<file>] [--update] [--link]
  $(basename "$0") --list-profiles

Options:
  --global              Install global config (agents, rules) to ~/.claude/
  --machine=<name>      Machine profile (mac, linux, windows)
  --profile=<name>      Project profile (fullstack-ts, laravel-php)
  --config=<file>       Token values file (or uses .claude-config.env in project)
  --update              Update mode: show diffs, prompt accept/skip per file
  --link                Symlink mode: symlink files from claude-config into project
                        Edits in project flow back to claude-config automatically.
                        Files needing token replacement are copied (not linked).
  --list-profiles       List available profiles

Examples:
  $(basename "$0") --global --machine=mac
  $(basename "$0") ~/projects/tripcart-builder --profile=fullstack-ts
  $(basename "$0") ~/projects/tripcart-builder --profile=fullstack-ts --link
  $(basename "$0") ~/projects/tripcart-builder --profile=fullstack-ts --update
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

# ---------- Global install ----------
install_global() {
  local machine="${1:-}"
  local target="$HOME/.claude"

  header "Installing global config to $target"

  # Rules
  if [ -d "$target/rules" ]; then
    warn "~/.claude/rules/ already exists — skipping (won't overwrite customizations)"
  else
    cp -r "$SCRIPT_DIR/global/rules" "$target/rules"
    log "Installed rules/ (common + typescript)"
  fi

  # Agents
  mkdir -p "$target/agents"
  cp "$SCRIPT_DIR/global/agents/"*.md "$target/agents/"
  log "Installed agents/ (code-reviewer, security-auditor)"

  # Settings template
  if [ ! -f "$target/settings.json" ]; then
    cp "$SCRIPT_DIR/global/settings.json.template" "$target/settings.json"
    log "Created settings.json from template"
  else
    warn "~/.claude/settings.json already exists — skipping"
  fi

  # Machine profile
  if [ -n "$machine" ]; then
    local machine_file="$SCRIPT_DIR/config/machines/${machine}.env"
    if [ -f "$machine_file" ]; then
      cp "$machine_file" "$target/.machine-profile"
      log "Applied machine profile: $machine"
    else
      error "Machine profile not found: $machine_file"
      echo "  Available: mac, linux, windows"
      exit 1
    fi
  fi

  echo ""
  log "Global install complete!"
  echo "  Next: stow personal config from ~/dotfiles if needed"
}

# ---------- Token replacement ----------
replace_tokens() {
  local file="$1"
  local sed_i

  if [[ "$OSTYPE" == "darwin"* ]]; then
    sed_i="sed -i ''"
  else
    sed_i="sed -i"
  fi

  $sed_i \
    -e "s|{{OP_BASE_URL}}|${OP_BASE_URL}|g" \
    -e "s|{{OP_PROJECT_SLUG}}|${OP_PROJECT_SLUG}|g" \
    -e "s|{{OP_PROJECT_ID}}|${OP_PROJECT_ID}|g" \
    -e "s|{{GITHUB_ORG_REPO}}|${GITHUB_ORG_REPO}|g" \
    -e "s|{{BASE_BRANCH}}|${BASE_BRANCH}|g" \
    "$file"
}

# ---------- Load config ----------
load_config() {
  local config_file="$1"

  if [ ! -f "$config_file" ]; then
    error "Config file not found: $config_file"
    exit 1
  fi

  # shellcheck disable=SC1090
  source "$config_file"

  local missing=()
  [ -z "${OP_BASE_URL:-}" ] && missing+=("OP_BASE_URL")
  [ -z "${OP_PROJECT_SLUG:-}" ] && missing+=("OP_PROJECT_SLUG")
  [ -z "${OP_PROJECT_ID:-}" ] && missing+=("OP_PROJECT_ID")
  [ -z "${GITHUB_ORG_REPO:-}" ] && missing+=("GITHUB_ORG_REPO")
  [ -z "${BASE_BRANCH:-}" ] && missing+=("BASE_BRANCH")

  if [ ${#missing[@]} -gt 0 ]; then
    error "Missing required config vars: ${missing[*]}"
    exit 1
  fi
}

# ---------- Interactive config ----------
interactive_config() {
  header "Enter project token values"
  echo ""

  read -rp "OpenProject base URL: " OP_BASE_URL
  OP_BASE_URL="${OP_BASE_URL:?OpenProject base URL is required}"

  read -rp "OpenProject project slug: " OP_PROJECT_SLUG
  OP_PROJECT_SLUG="${OP_PROJECT_SLUG:?OpenProject project slug is required}"

  read -rp "OpenProject project ID: " OP_PROJECT_ID
  OP_PROJECT_ID="${OP_PROJECT_ID:?OpenProject project ID is required}"

  read -rp "GitHub org/repo: " GITHUB_ORG_REPO
  GITHUB_ORG_REPO="${GITHUB_ORG_REPO:?GitHub org/repo is required}"

  read -rp "Base branch [main]: " BASE_BRANCH
  BASE_BRANCH="${BASE_BRANCH:-main}"

  export OP_BASE_URL OP_PROJECT_SLUG OP_PROJECT_ID GITHUB_ORG_REPO BASE_BRANCH
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

# ---------- Check if file contains token placeholders ----------
has_tokens() {
  grep -q '{{.\+}}' "$1" 2>/dev/null
}

# ---------- Install a single file (copy, link, or update) ----------
install_file() {
  local src="$1"
  local dest="$2"
  local update_mode="${3:-false}"
  local link_mode="${4:-false}"
  local needs_tokens="${5:-false}"

  if [ "$update_mode" = true ] && [ -f "$dest" ]; then
    # For symlinks in update mode, compare against the resolved source
    local cmp_src="$src"
    if [ -L "$dest" ]; then
      local current_target
      current_target="$(readlink "$dest")"
      # If already linked to the right place, no change needed
      if [ "$link_mode" = true ] && [ "$needs_tokens" = false ]; then
        local abs_src
        abs_src="$(cd "$(dirname "$src")" && pwd)/$(basename "$src")"
        local abs_target
        abs_target="$(cd "$(dirname "$dest")" && pwd)/$current_target"
        if [ "$abs_src" = "$(realpath "$dest")" ]; then
          return 1  # Already linked correctly
        fi
      fi
    fi

    if diff -q "$cmp_src" "$dest" > /dev/null 2>&1; then
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

  if [ "$link_mode" = true ] && [ "$needs_tokens" = false ]; then
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
  local config_file="${3:-}"
  local update_mode="${4:-false}"
  local link_mode="${5:-false}"

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

  # Load token config
  if [ -n "$config_file" ]; then
    load_config "$config_file"
  elif [ -f "$project_path/.claude-config.env" ]; then
    load_config "$project_path/.claude-config.env"
    log "Loaded config from $project_path/.claude-config.env"
  else
    interactive_config
  fi

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
  if install_file "$SCRIPT_DIR/project/settings.json" "$target/settings.json" "$update_mode" false false; then
    log "Installed settings.json (copied)"
  fi

  # --- Install rules ---
  if [ ${#RULES[@]} -gt 0 ]; then
    mkdir -p "$target/rules"
    for rule in "${RULES[@]}"; do
      local src="$SCRIPT_DIR/project/rules/$rule"
      if [ -f "$src" ]; then
        if install_file "$src" "$target/rules/$rule" "$update_mode" "$link_mode" false; then
          log "Installed rule: $rule"
        fi
      else
        warn "Rule not found: $rule (skipped)"
      fi
    done
  fi

  # --- Install commands ---
  if [ ${#COMMANDS[@]} -gt 0 ]; then
    mkdir -p "$target/commands"
    for cmd in "${COMMANDS[@]}"; do
      local src="$SCRIPT_DIR/project/commands/$cmd"
      if [ -f "$src" ]; then
        local cmd_has_tokens=false
        if has_tokens "$src"; then
          cmd_has_tokens=true
        fi
        if install_file "$src" "$target/commands/$cmd" "$update_mode" "$link_mode" "$cmd_has_tokens"; then
          if [ "$cmd_has_tokens" = true ]; then
            replace_tokens "$target/commands/$cmd"
            log "Installed command: $cmd (copied — has tokens)"
          else
            log "Installed command: $cmd"
          fi
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
        local skill_has_tokens=false
        while IFS= read -r -d '' file; do
          local rel="${file#"$src_dir"/}"
          mkdir -p "$target/skills/$skill/$(dirname "$rel")"
          local file_has_tokens=false
          if has_tokens "$file"; then
            file_has_tokens=true
            skill_has_tokens=true
          fi
          if install_file "$file" "$target/skills/$skill/$rel" "$update_mode" "$link_mode" "$file_has_tokens"; then
            skill_changed=true
          fi
        done < <(find "$src_dir" -type f -print0)

        # Replace tokens only in copied files (not symlinks)
        if [ "$skill_changed" = true ] && [ "$skill_has_tokens" = true ]; then
          while IFS= read -r -d '' md_file; do
            if [ ! -L "$md_file" ]; then
              replace_tokens "$md_file"
            fi
          done < <(find "$target/skills/$skill" -name "*.md" -print0)
        fi
        if [ "$skill_changed" = true ]; then
          log "Installed skill: $skill"
        fi
      else
        warn "Skill not found: $skill (skipped)"
      fi
    done
  fi

  # --- Install specs ---
  if [ ${#SPECS[@]} -gt 0 ]; then
    mkdir -p "$target/specs"
    for spec in "${SPECS[@]}"; do
      local src="$SCRIPT_DIR/project/specs/$spec"
      if [ -f "$src" ]; then
        if install_file "$src" "$target/specs/$spec" "$update_mode" "$link_mode" false; then
          log "Installed spec: $spec"
        fi
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
          if install_file "$src" "$dest" "$update_mode" "$link_mode" false; then
            log "Installed template: $tmpl"
          fi
        elif [ ! -f "$dest" ]; then
          install_file "$src" "$dest" false "$link_mode" false
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
  log "Project install complete! (profile: $PROFILE_NAME, mode: $mode_label)"
  echo ""
  echo "  Tokens applied:"
  echo "    OP_BASE_URL     = $OP_BASE_URL"
  echo "    OP_PROJECT_SLUG = $OP_PROJECT_SLUG"
  echo "    OP_PROJECT_ID   = $OP_PROJECT_ID"
  echo "    GITHUB_ORG_REPO = $GITHUB_ORG_REPO"
  echo "    BASE_BRANCH     = $BASE_BRANCH"
  echo ""
  if [ "$link_mode" = true ]; then
    echo "  Link mode active:"
    echo "    - Most files are symlinked to claude-config repo"
    echo "    - Edits in .claude/ flow back to claude-config automatically"
    echo "    - Files with token placeholders were copied (not linked)"
    echo "    - Add symlinked dirs to .gitignore if not committing them"
  else
    echo "  Next steps:"
    echo "    1. Review .claude/settings.json and adjust allow/deny as needed"
    echo "    2. Create .claude/settings.local.json for personal overrides"
    echo "    3. Commit .claude/ to your project repo"
  fi
}

# ---------- Parse args ----------
GLOBAL=false
MACHINE=""
PROJECT_PATH=""
PROFILE=""
CONFIG_FILE=""
UPDATE=false
LINK=false

if [ $# -eq 0 ]; then
  usage
fi

for arg in "$@"; do
  case "$arg" in
    --global)           GLOBAL=true ;;
    --machine=*)        MACHINE="${arg#--machine=}" ;;
    --profile=*)        PROFILE="${arg#--profile=}" ;;
    --config=*)         CONFIG_FILE="${arg#--config=}" ;;
    --update)           UPDATE=true ;;
    --link)             LINK=true ;;
    --list-profiles)    list_profiles; exit 0 ;;
    --help|-h)          usage ;;
    -*)                 error "Unknown flag: $arg"; usage ;;
    *)
      if [ -z "$PROJECT_PATH" ]; then
        PROJECT_PATH="$arg"
      else
        error "Unexpected argument: $arg"; usage
      fi
      ;;
  esac
done

# ---------- Execute ----------
if [ "$GLOBAL" = true ]; then
  install_global "$MACHINE"
  exit 0
fi

if [ -z "$PROJECT_PATH" ]; then
  error "Project path required"
  usage
fi

if [ -z "$PROFILE" ]; then
  echo "Select a profile:"
  select_idx=0
  profiles=()
  for conf in "$SCRIPT_DIR/profiles/"*.conf; do
    name="$(basename "${conf%.conf}")"
    profiles+=("$name")
    # shellcheck disable=SC1090
    (source "$conf"; printf "  %d) %-20s %s\n" "$((select_idx + 1))" "$name" "$PROFILE_DESC")
    ((select_idx++))
  done
  echo ""
  read -rp "Enter profile number or name: " choice

  if [[ "$choice" =~ ^[0-9]+$ ]] && [ "$choice" -ge 1 ] && [ "$choice" -le ${#profiles[@]} ]; then
    PROFILE="${profiles[$((choice - 1))]}"
  else
    PROFILE="$choice"
  fi
fi

install_project "$PROJECT_PATH" "$PROFILE" "$CONFIG_FILE" "$UPDATE" "$LINK"
