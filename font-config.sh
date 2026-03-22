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

# ── _font_file_present ────────────────────────────────────────────────────────
_font_file_present() {
  if [ "$DOTFILES_OS" = "macos" ]; then
    ls ~/Library/Fonts/FiraCode*.ttf \
       ~/Library/Fonts/FiraCodeNerdFont*.ttf \
       /Library/Fonts/FiraCode*.ttf \
       2>/dev/null | grep -q . && return 0
  else
    ls ~/.local/share/fonts/FiraCode*.ttf \
       ~/.local/share/fonts/FiraCodeNerdFont*.ttf \
       /usr/share/fonts/truetype/firacode/FiraCode*.ttf \
       2>/dev/null | grep -q . && return 0
  fi
  return 1
}

# ── _print_terminal_status ────────────────────────────────────────────────────
_print_terminal_status() {
  local terminal="$1" status="$2"
  local label
  case "$terminal" in
    iterm2)  label="iTerm2" ;;
    ghostty) label="Ghostty" ;;
    kitty)   label="Kitty" ;;
    vscode)  label="VS Code" ;;
  esac
  case "$status" in
    not_installed)        return ;;  # silently skip
    installed_configured) success "$label: configured" ;;
    installed_not_configured)
      warn "$label: installed but NOT configured — run ./font-config.sh to fix"
      ;;
  esac
}

# ── cmd_status ────────────────────────────────────────────────────────────────
cmd_status() {
  header "Nerd Font (FiraCode)"

  if ! _font_file_present; then
    warn "FiraCode Nerd Font not found — install with: brew install --cask font-fira-code-nerd-font"
    return 0
  fi
  success "FiraCode Nerd Font found"

  local status
  for terminal in ghostty kitty vscode; do
    status="$(detect_terminal_font_status "$terminal")"
    _print_terminal_status "$terminal" "$status"
  done

  if [ "$DOTFILES_OS" = "macos" ]; then
    status="$(detect_terminal_font_status iterm2)"
    _print_terminal_status "iterm2" "$status"
  fi
}

# ── _fix_vscode_font ──────────────────────────────────────────────────────────
_fix_vscode_font() {
  local settings_path
  if [ "$DOTFILES_OS" = "macos" ]; then
    settings_path="$HOME/Library/Application Support/Code/User/settings.json"
  else
    settings_path="$HOME/.config/Code/User/settings.json"
  fi

  run_cmd mkdir -p "$(dirname "$settings_path")"

  if [ "$DRY_RUN" = "true" ]; then
    info "[dry-run] Would set terminal.integrated.fontFamily = FiraCode Nerd Font in:"
    info "          $settings_path"
    return 0
  fi

  local result
  result=$(python3 -c "
import json, sys
path = sys.argv[1]
try:
    with open(path) as f:
        data = json.load(f)
except FileNotFoundError:
    data = {}
except json.JSONDecodeError:
    print('JSONC_OR_INVALID')
    sys.exit(0)
data['terminal.integrated.fontFamily'] = 'FiraCode Nerd Font'
with open(path, 'w') as f:
    json.dump(data, f, indent=4)
print('OK')
" "$settings_path")

  if [ "$result" = "JSONC_OR_INVALID" ]; then
    warn "VS Code settings.json contains comments or is invalid JSON — cannot auto-edit."
    warn "Add this line manually:"
    info '    "terminal.integrated.fontFamily": "FiraCode Nerd Font"'
  elif [ "$result" = "OK" ]; then
    success "VS Code: terminal.integrated.fontFamily set to FiraCode Nerd Font"
  else
    error "VS Code: unexpected output: $result"
  fi
}

# ── _apply_fix ────────────────────────────────────────────────────────────────
_apply_fix() {
  local terminal="$1"
  case "$terminal" in
    iterm2)
      info "iTerm2: font is set by the DynamicProfile. Re-run:"
      info "    ./iterm-config.sh"
      ;;
    ghostty)
      info "Ghostty: font is set by your dotfiles profile. Re-run:"
      info "    ./choose-profile.sh"
      ;;
    kitty)
      info "Kitty: font is set by your dotfiles profile. Re-run:"
      info "    ./choose-profile.sh"
      ;;
    vscode)
      _fix_vscode_font
      ;;
  esac
}

# ── main ──────────────────────────────────────────────────────────────────────
main() {
  # Non-interactive guard
  if [ ! -t 0 ] && [ "$DRY_RUN" = "false" ]; then
    info "font-config.sh: skipped (non-interactive)"
    exit 0
  fi

  # Stage 1 — Detect
  header "Terminal Font Configuration"

  if ! _font_file_present; then
    warn "FiraCode Nerd Font not found — install first: brew install --cask font-fira-code-nerd-font"
    exit 0
  fi
  success "FiraCode Nerd Font found"

  local terminals=()
  [ "$DOTFILES_OS" = "macos" ] && terminals+=(iterm2)
  terminals+=(ghostty kitty vscode)

  local misconfigured=()
  local status
  for terminal in "${terminals[@]}"; do
    status="$(detect_terminal_font_status "$terminal")"
    _print_terminal_status "$terminal" "$status"
    [ "$status" = "installed_not_configured" ] && misconfigured+=("$terminal")
  done

  if [ "${#misconfigured[@]}" -eq 0 ]; then
    echo ""
    success "All installed terminals are configured with FiraCode Nerd Font."
    exit 0
  fi

  # Non-interactive dry-run: show all fixes and exit
  if [ ! -t 0 ] && [ "$DRY_RUN" = "true" ]; then
    echo ""
    info "(dry-run mode — no files will be written)"
    for terminal in "${misconfigured[@]}"; do
      _apply_fix "$terminal"
    done
    exit 0
  fi

  # Stage 2 — Select
  echo ""
  local selected=()
  if command -v fzf >/dev/null 2>&1; then
    local fzf_input
    fzf_input="$(printf '%s\n' "${misconfigured[@]}")"
    mapfile -t selected < <(
      echo "$fzf_input" | fzf --multi \
        --prompt="Select terminals to fix (Space=toggle, Enter=confirm): " \
        --header="Terminals NOT configured with FiraCode Nerd Font" \
        --bind=space:toggle
    ) || true
  else
    selected=("${misconfigured[@]}")
    info "fzf not found — selecting all misconfigured terminals automatically"
  fi

  if [ "${#selected[@]}" -eq 0 ]; then
    info "Nothing to do."
    exit 0
  fi

  # Stage 3 — Apply
  echo ""
  header "Applying Fixes"
  for terminal in "${selected[@]}"; do
    _apply_fix "$terminal"
  done

  # Stage 4 — Verify
  echo ""
  header "Verification"
  local still_broken=false
  for terminal in "${selected[@]}"; do
    status="$(detect_terminal_font_status "$terminal")"
    case "$status" in
      installed_configured)
        success "$terminal: now configured"
        ;;
      installed_not_configured)
        warn "$terminal: still not configured — follow the instructions above"
        still_broken=true
        ;;
    esac
  done

  if [ "$still_broken" = "true" ]; then
    echo ""
    warn "Some terminals still need manual steps. Re-run ./font-config.sh --status to check."
  else
    echo ""
    success "All selected terminals are now configured."
  fi
}

# ── Source-only guard (place after ALL function definitions) ──────────────────
[ "${FONT_CONFIG_SOURCE_ONLY:-}" = "1" ] && return 0

# ── Dispatch ──────────────────────────────────────────────────────────────────
case "${1:-}" in
  --status)   cmd_status; exit 0 ;;
  --dry-run)  DRY_RUN=true; main ;;
  "")         main ;;
  *)          echo "Usage: font-config.sh [--status|--dry-run]" >&2; exit 1 ;;
esac
