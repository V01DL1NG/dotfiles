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

# ── Stubs ─────────────────────────────────────────────────────────────────────
install_dockutil() { echo "install_dockutil: not yet implemented"; }
apply_dock_config() { echo "apply_dock_config: not yet implemented"; }
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
