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

# ── detect_terminal_font_status ───────────────────────────────────────────────
# Usage: detect_terminal_font_status TERMINAL [CONFIG_PATH_OVERRIDE]
# TERMINAL ∈ {ghostty, kitty, vscode, iterm2}
# CONFIG_PATH_OVERRIDE — if given, skips installed check, checks this path instead
# Echoes: not_installed | installed_not_configured | installed_configured
detect_terminal_font_status() {
  local terminal="$1"
  local config_override="${2:-}"

  case "$terminal" in
    ghostty)
      local config_path="${config_override:-$HOME/.config/ghostty/config}"
      if [ -z "$config_override" ]; then
        if [ "$DOTFILES_OS" = "macos" ]; then
          [ -d "/Applications/Ghostty.app" ] || { echo "not_installed"; return; }
        else
          command -v ghostty >/dev/null 2>&1 || { echo "not_installed"; return; }
        fi
      fi
      [ -f "$config_path" ] || { echo "installed_not_configured"; return; }
      grep -q "font-family = FiraCode Nerd Font" "$config_path" \
        && echo "installed_configured" \
        || echo "installed_not_configured"
      ;;
    kitty)
      local config_path="${config_override:-$HOME/.config/kitty/kitty.conf}"
      if [ -z "$config_override" ]; then
        if [ "$DOTFILES_OS" = "macos" ]; then
          [ -d "/Applications/kitty.app" ] || { echo "not_installed"; return; }
        else
          command -v kitty >/dev/null 2>&1 || { echo "not_installed"; return; }
        fi
      fi
      [ -f "$config_path" ] || { echo "installed_not_configured"; return; }
      grep -q "font_family.*FiraCode" "$config_path" \
        && echo "installed_configured" \
        || echo "installed_not_configured"
      ;;
    vscode)
      local settings_path
      if [ -n "$config_override" ]; then
        settings_path="$config_override"
      else
        command -v code >/dev/null 2>&1 || { echo "not_installed"; return; }
        if [ "$DOTFILES_OS" = "macos" ]; then
          settings_path="$HOME/Library/Application Support/Code/User/settings.json"
        else
          settings_path="$HOME/.config/Code/User/settings.json"
        fi
      fi
      [ -f "$settings_path" ] || { echo "installed_not_configured"; return; }
      grep -q '"terminal.integrated.fontFamily".*FiraCode' "$settings_path" \
        && echo "installed_configured" \
        || echo "installed_not_configured"
      ;;
    iterm2)
      # iTerm2 is macOS-only
      [ "$DOTFILES_OS" = "macos" ] || { echo "not_installed"; return; }
      local profiles_dir="${config_override:-$HOME/Library/Application Support/iTerm2/DynamicProfiles}"
      if [ -z "$config_override" ]; then
        [ -d "/Applications/iTerm.app" ] || { echo "not_installed"; return; }
      fi
      [ -d "$profiles_dir" ] || { echo "installed_not_configured"; return; }
      # Check if any profile JSON has "Normal Font" value containing FiraCode
      if ls "$profiles_dir"/*.json >/dev/null 2>&1 \
          && grep -ql '"Normal Font".*FiraCode' "$profiles_dir"/*.json 2>/dev/null; then
        echo "installed_configured"
      else
        echo "installed_not_configured"
      fi
      ;;
  esac
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
