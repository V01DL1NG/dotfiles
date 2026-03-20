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

  install_dockutil

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

# ── dock_customise (stub — implemented in Task 5) ─────────────────────────────
dock_customise()  { echo "dock_customise: not yet implemented"; }

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
