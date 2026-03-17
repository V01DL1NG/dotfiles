#!/usr/bin/env bash
# ============================================================================
# macos-defaults.sh — apply curated macOS system defaults
#
# Usage:
#   ./macos-defaults.sh                        # interactive: preset picker → fzf
#   ./macos-defaults.sh minimal                # apply minimal preset, no interaction
#   ./macos-defaults.sh opinionated            # apply all settings, no interaction
#   ./macos-defaults.sh --dry-run              # interactive, print commands only
#   ./macos-defaults.sh minimal --dry-run      # minimal preset, print commands only
#   ./macos-defaults.sh opinionated --dry-run  # opinionated preset, print commands only
# ============================================================================
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=platform.sh
. "$SCRIPT_DIR/platform.sh"

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

# ── macOS version helper ──────────────────────────────────────────────────────
_macos_major() { sw_vers -productVersion | cut -d. -f1; }

# ── macOS guard ───────────────────────────────────────────────────────────────
if [ "$DOTFILES_OS" != "macos" ]; then
  info "Skipping macOS defaults (macOS only)"
  exit 0
fi

# ── Argument parsing ──────────────────────────────────────────────────────────
PRESET="${1:-}"      # minimal | opinionated | --dry-run | ""
DRY_RUN=false

if [ "$PRESET" = "--dry-run" ]; then
  DRY_RUN=true
  PRESET=""
elif [ "${2:-}" = "--dry-run" ]; then
  DRY_RUN=true
fi

if [ -n "$PRESET" ] && [ "$PRESET" != "minimal" ] && [ "$PRESET" != "opinionated" ]; then
  error "Unknown preset: $PRESET"
  error "Usage: $0 [minimal|opinionated] [--dry-run]"
  exit 1
fi

# ── Settings arrays ───────────────────────────────────────────────────────────
# Each entry is the exact string shown in fzf: "[Category]  Description"
# MINIMAL_SETTINGS appear first in fzf input so the minimal bind can select them.

MINIMAL_SETTINGS=(
  "[Keyboard]     Fast key repeat"
  "[Keyboard]     Short key repeat delay"
  "[Keyboard]     Disable autocorrect"
  "[Trackpad]     Tap to click"
  "[Finder]       Show all file extensions"
  "[Finder]       No .DS_Store on network/USB"
  "[Screenshots]  Save to ~/Desktop/Screenshots"
  "[System]       Expand save panel"
  "[System]       Expand print panel"
)

EXTRA_SETTINGS=(
  "[Keyboard]     Disable smart quotes"
  "[Keyboard]     Disable smart dashes"
  "[Keyboard]     Disable auto-capitalize"
  "[Trackpad]     Three-finger drag"
  "[Finder]       Show hidden files"
  "[Finder]       Show full path in title bar"
  "[Finder]       Show status bar"
  "[Finder]       Default to list view"
  "[Finder]       Keep folders on top"
  "[Dock]         Auto-hide"
  "[Dock]         Remove auto-hide delay"
  "[Dock]         Icon size 48px"
  "[Dock]         Scale minimize effect"
  "[Dock]         Don't show recent apps"
  "[Screenshots]  Save as PNG"
  "[Screenshots]  Disable screenshot shadow"
  "[System]       Disable crash reporter"
  "[System]       Show battery percentage"
  "[System]       24-hour clock"
  "[System]       Fast window resize"
  "[Safari]       Enable developer menu"
  "[Safari]       Show full URL"
  "[TextEdit]     Default to plain text"
)

# ── Dry-run wrapper ───────────────────────────────────────────────────────────
# Use run_cmd() for every defaults write, mkdir call.
# restart_services() uses raw killall guarded by an early-return in dry-run mode.
run_cmd() {
  if [ "$DRY_RUN" = "true" ]; then
    echo "  $*"
  else
    "$@"
  fi
}
