#!/usr/bin/env bash
# font-config.sh — Nerd Font detection and configuration TUI
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DRY_RUN=false

# ── Platform ──────────────────────────────────────────────────────────────────
# shellcheck source=platform.sh
source "$SCRIPT_DIR/platform.sh"

# ── Colors ────────────────────────────────────────────────────────────────────
BOLD='\033[1m'
PURPLE='\033[38;2;105;48;122m'
LAVENDER='\033[38;2;239;220;249m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
RED='\033[0;31m'
RESET='\033[0m'

info()    { echo -e "  ${LAVENDER}${1}${RESET}"; }
success() { echo -e "  ${GREEN}✓${RESET}  ${1}"; }
warn()    { echo -e "  ${YELLOW}!${RESET}  ${1}"; }
error()   { echo -e "  ${RED}✗${RESET}  ${1}" >&2; }
header()  { echo -e "\n${BOLD}${PURPLE}${1}${RESET}"; }

# ── run_cmd ───────────────────────────────────────────────────────────────────
run_cmd() {
  if [ "$DRY_RUN" = "true" ]; then
    echo "  [dry-run] $*"
  else
    "$@"
  fi
}

# ── Source-only guard (place after ALL function definitions) ──────────────────
[ "${FONT_CONFIG_SOURCE_ONLY:-}" = "1" ] && return 0

# ── Dispatch ──────────────────────────────────────────────────────────────────
case "${1:-}" in
  --status)   echo "status: not yet implemented"; exit 0 ;;
  --dry-run)  DRY_RUN=true; echo "dry-run: not yet implemented"; exit 0 ;;
  "")         echo "TUI: not yet implemented"; exit 0 ;;
  *)          echo "Usage: font-config.sh [--status|--dry-run]" >&2; exit 1 ;;
esac
