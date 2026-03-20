#!/usr/bin/env bash
# ============================================================================
# touchid-sudo.sh — enable TouchID for sudo (iTerm2 + tmux)
#
# Usage:
#   ./touchid-sudo.sh              # install
#   ./touchid-sudo.sh --revert     # clean uninstall (requires working sudo)
#   ./touchid-sudo.sh --status     # show current state
#   ./touchid-sudo.sh --dry-run    # show what would be written, no changes
# ============================================================================
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=platform.sh
. "$SCRIPT_DIR/platform.sh"

# ── Colors ────────────────────────────────────────────────────────────────────
BOLD='\033[1m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
RED='\033[0;31m'
CYAN='\033[0;36m'
RESET='\033[0m'

info()    { echo -e "  ${CYAN}${1}${RESET}"; }
success() { echo -e "  ${GREEN}✓${RESET}  ${1}"; }
warn()    { echo -e "  ${YELLOW}!${RESET}  ${1}"; }
error()   { echo -e "  ${RED}✗${RESET}  ${1}" >&2; }
header()  { echo -e "\n${BOLD}${1}${RESET}"; }

# ── macOS guard ───────────────────────────────────────────────────────────────
if [ "$DOTFILES_OS" != "macos" ]; then
  info "Skipping TouchID sudo setup (macOS only)"
  exit 0
fi

# ── Arg parsing ───────────────────────────────────────────────────────────────
COMMAND="install"
case "${1:-}" in
  --revert)   COMMAND="revert" ;;
  --status)   COMMAND="status" ;;
  --dry-run)  COMMAND="dry-run" ;;
  "")         COMMAND="install" ;;
  *)
    echo "Usage: $0 [--revert|--status|--dry-run]" >&2
    exit 1
    ;;
esac

# ── Main dispatch (stubs) ─────────────────────────────────────────────────────
case "$COMMAND" in
  install)  echo "install: not yet implemented" ;;
  revert)   echo "revert: not yet implemented" ;;
  status)   echo "status: not yet implemented" ;;
  dry-run)  echo "dry-run: not yet implemented" ;;
esac
