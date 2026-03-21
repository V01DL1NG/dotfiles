#!/usr/bin/env bash
# ============================================================================
# dock-config.sh — role-aware Dock layout manager
#
# Usage:
#   ./dock-config.sh                  # interactive TUI
#   ./dock-config.sh --apply work     # apply saved work config
#   ./dock-config.sh --apply personal # apply saved personal config
#   ./dock-config.sh --dry-run        # show commands, no changes
# ============================================================================
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=platform.sh
. "$SCRIPT_DIR/platform.sh"

# ── Config dir (overridable for tests) ───────────────────────────────────────
DOCK_CONFIG_DIR="${DOCK_CONFIG_DIR:-$SCRIPT_DIR/dock}"

# ── Argument parsing ──────────────────────────────────────────────────────────
DRY_RUN=false
MODE="interactive"
APPLY_ROLE=""

while [ $# -gt 0 ]; do
  case "$1" in
    --dry-run) DRY_RUN=true; shift ;;
    --apply)
      MODE="apply"
      APPLY_ROLE="${2:-}"
      if [ -z "$APPLY_ROLE" ] || [[ "$APPLY_ROLE" == --* ]]; then
        echo "Usage: $0 --apply <work|personal>" >&2
        exit 1
      fi
      shift 2
      ;;
    *)
      echo "Usage: $0 [--apply <work|personal>] [--dry-run]" >&2
      exit 1
      ;;
  esac
done

# ── Colors ────────────────────────────────────────────────────────────────────
BOLD='\033[1m'
PURPLE='\033[38;2;105;48;122m'
LAVENDER='\033[38;2;239;220;249m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
RESET='\033[0m'

info()    { echo -e "  ${LAVENDER}${1}${RESET}"; }
success() { echo -e "  ${GREEN}✓${RESET}  ${1}"; }
warn()    { echo -e "  ${YELLOW}!${RESET}  ${1}"; }
header()  { echo -e "\n${BOLD}${PURPLE}${1}${RESET}"; }

# ── run_cmd ───────────────────────────────────────────────────────────────────
run_cmd() {
  if [ "$DRY_RUN" = "true" ]; then
    echo "  [dry-run] $*"
  else
    "$@"
  fi
}

# ── macOS guard ───────────────────────────────────────────────────────────────
if [ "$DOTFILES_OS" != "macos" ]; then
  info "Skipping Dock configuration (macOS only)"
  exit 0
fi

# ── install_dockutil ──────────────────────────────────────────────────────────
# Ensures dockutil is available; installs via brew if missing.
install_dockutil() {
  if command -v dockutil >/dev/null 2>&1; then
    return
  fi
  info "Installing dockutil via Homebrew..."
  brew install dockutil
  if ! command -v dockutil >/dev/null 2>&1; then
    echo "dockutil not found after install — aborting" >&2
    exit 1
  fi
}

# ── apply_dock_config <role> ──────────────────────────────────────────────────
# Reads dock/<role>.txt and applies it via dockutil.
# Reads metadata comment headers for position and clear settings.
apply_dock_config() {
  local role="$1"
  local config_file="${DOCK_CONFIG_DIR}/${role}.txt"

  if [ ! -f "$config_file" ]; then
    warn "No Dock config for role '${role}' — skipping"
    exit 0
  fi

  if [ "$DRY_RUN" = "false" ]; then
    install_dockutil
  fi

  # Read position and clear from metadata comment headers
  local position="bottom"
  local clear_flag="yes"
  while IFS= read -r line; do
    case "$line" in
      "# dock-position: "*) position="${line#\# dock-position: }" ;;
      "# dock-clear: "*)    clear_flag="${line#\# dock-clear: }" ;;
    esac
  done < "$config_file"

  # Set Dock position (dockutil has no position flag — use defaults write)
  run_cmd defaults write com.apple.dock orientation -string "$position"

  # Clear existing Dock
  if [ "$clear_flag" = "yes" ]; then
    run_cmd dockutil --remove all --no-restart
  fi

  # Add apps and spacers from config
  while IFS= read -r line; do
    # Strip leading/trailing whitespace
    local trimmed
    trimmed="${line#"${line%%[![:space:]]*}"}"
    trimmed="${trimmed%"${trimmed##*[![:space:]]}"}"

    # Skip blank lines and comment lines
    [ -z "$trimmed" ] && continue
    case "$trimmed" in \#*) continue ;; esac

    if [ "$trimmed" = "---" ]; then
      run_cmd dockutil --add '' --type spacer --section apps --no-restart
    else
      if [ "$DRY_RUN" = "false" ] && [ ! -e "$trimmed" ]; then
        warn "Skipping missing app: $trimmed"
        continue
      fi
      run_cmd dockutil --add "$trimmed" --no-restart
    fi
  done < "$config_file"

  run_cmd killall Dock

  if [ "$DRY_RUN" = "false" ]; then
    success "Dock configured for role '${role}'"
  fi
}

# ── scan_apps ─────────────────────────────────────────────────────────────────
# Prints all .app paths found in /Applications and ~/Applications, one per line.
scan_apps() {
  local app
  for dir in "/Applications" "$HOME/Applications"; do
    [ -d "$dir" ] || continue
    for app in "$dir"/*.app; do
      [ -e "$app" ] && echo "$app"
    done
  done | sort -u
}

# ── fzf_app_picker <role> ─────────────────────────────────────────────────────
# Runs Stage 2. Sets SELECTED_APPS[] array.
# Uses fzf if available; falls back to numbered list + space-separated input.
# Note: fzf --multi returns items in input-list order, not selection order.
fzf_app_picker() {
  local role="$1"
  SELECTED_APPS=()

  local -a app_list
  mapfile -t app_list < <(scan_apps)

  if [ ${#app_list[@]} -eq 0 ]; then
    warn "No .app bundles found in /Applications or ~/Applications"
    return 1
  fi

  if ! command -v fzf >/dev/null 2>&1; then
    warn "fzf not found — using numbered list fallback"
    echo ""
    echo "  Installed apps:"
    local i=1
    for app in "${app_list[@]}"; do
      echo "  $i) $(basename "$app" .app)"
      (( i++ ))
    done
    echo ""
    echo "  Enter app numbers separated by spaces (e.g. 1 3 5):"
    read -r -p "  > " choices
    for idx in $choices; do
      if [[ "$idx" =~ ^[0-9]+$ ]] && (( idx >= 1 && idx <= ${#app_list[@]} )); then
        SELECTED_APPS+=("${app_list[$((idx - 1))]}")
      fi
    done
    return 0
  fi

  local selected
  selected="$(
    { echo "--- SPACER ---"; printf '%s\n' "${app_list[@]}"; } \
      | fzf --multi \
            --prompt "Select apps for ${role} Dock > " \
            --header "Space to select · Enter to confirm · fzf order = input order (edit file to reorder)" \
            --height "80%" \
            --reverse \
      || true
  )"

  while IFS= read -r line; do
    [ -z "$line" ] && continue
    SELECTED_APPS+=("$line")
  done <<< "$selected"
}

# ── dock_variant_stage ────────────────────────────────────────────────────────
# Runs Stage 3. Sets DOCK_POSITION and DOCK_CLEAR.
dock_variant_stage() {
  DOCK_POSITION="bottom"
  DOCK_CLEAR="yes"

  local choice

  # Dock position
  PS3="  Dock position: "
  select choice in "Bottom (default)" "Left" "Right"; do
    case "$REPLY" in
      1) DOCK_POSITION="bottom"; break ;;
      2) DOCK_POSITION="left";   break ;;
      3) DOCK_POSITION="right";  break ;;
      *) echo "  Enter 1, 2, or 3." ;;
    esac
  done || true

  # Clear existing Dock before applying
  PS3="  Clear existing Dock before applying? "
  select choice in "Yes (default)" "No"; do
    case "$REPLY" in
      1) DOCK_CLEAR="yes"; break ;;
      2) DOCK_CLEAR="no";  break ;;
      *) echo "  Enter 1 or 2." ;;
    esac
  done || true
}

# ── save_dock_config <role> ───────────────────────────────────────────────────
# Writes dock/<role>.txt from SELECTED_APPS[], DOCK_POSITION, DOCK_CLEAR.
save_dock_config() {
  local role="$1"
  local config_file="${DOCK_CONFIG_DIR}/${role}.txt"
  local content=""

  content+="# dock-position: ${DOCK_POSITION}"$'\n'
  content+="# dock-clear: ${DOCK_CLEAR}"$'\n'

  for entry in "${SELECTED_APPS[@]}"; do
    if [ "$entry" = "--- SPACER ---" ]; then
      content+="---"$'\n'
    else
      content+="${entry}"$'\n'
    fi
  done

  if [ "$DRY_RUN" = "true" ]; then
    echo ""
    info "Would write to: ${config_file}"
    echo "────────────────────────────────────────────"
    printf '%s' "$content"
    echo "────────────────────────────────────────────"
    return
  fi

  mkdir -p "$(dirname "$config_file")"
  printf '%s' "$content" > "$config_file"
  success "Saved config: ${config_file}"
}

# ── dock_customise_role <role> ────────────────────────────────────────────────
# Runs the full TUI for one role: picker → variants → save → apply.
dock_customise_role() {
  local role="$1"
  header "Dock — ${role}"

  # Stage 2: app picker
  fzf_app_picker "$role" || {
    warn "No apps found — skipping ${role} Dock config."
    return
  }

  if [ ${#SELECTED_APPS[@]} -eq 0 ]; then
    warn "No apps selected — skipping ${role} Dock config."
    return
  fi

  # Stage 3: variant choices
  dock_variant_stage

  # Save config
  save_dock_config "$role"

  # Apply immediately
  apply_dock_config "$role"

  echo ""
  info "Tip: edit ${DOCK_CONFIG_DIR}/${role}.txt to reorder apps (fzf preserves input order, not selection order)"
}

# ── dock_customise ────────────────────────────────────────────────────────────
# Orchestrates Stage 1 (role select) → dock_customise_role.
dock_customise() {
  header "Dock Customisation"

  local choice
  PS3="  Which role to configure? "
  select choice in "Work" "Personal" "Both"; do
    case "$REPLY" in
      1) dock_customise_role "work";                               break ;;
      2) dock_customise_role "personal";                           break ;;
      3) dock_customise_role "work"; dock_customise_role "personal"; break ;;
      *) echo "  Enter 1, 2, or 3." ;;
    esac
  done || true

  echo ""
  success "Dock customisation complete."
}

# ── Source-only guard (for testing) ──────────────────────────────────────────
if [ "${DOCK_CONFIG_SOURCE_ONLY:-}" = "1" ]; then
  return 0 2>/dev/null || exit 0
fi

# ── Dispatch ──────────────────────────────────────────────────────────────────
case "$MODE" in
  apply)
    apply_dock_config "$APPLY_ROLE"
    ;;
  interactive)
    if [ "$DRY_RUN" = "true" ]; then
      info "(dry-run mode — no files will be written)"
      dock_customise
    elif [ -t 0 ]; then
      printf "  Customise Dock layout? [Y/n] "
      read -r reply || true
      case "${reply:-y}" in
        [Nn]*) info "Skipping Dock customisation." ;;
        *)     dock_customise ;;
      esac
    else
      info "Non-interactive — skipping Dock customisation."
    fi
    ;;
esac
