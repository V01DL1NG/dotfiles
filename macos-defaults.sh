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

# ── Category flags (set by apply_one_setting) ─────────────────────────────────
HAS_KEYBOARD=false
HAS_FINDER=false
HAS_DOCK=false
HAS_SYSTEM_OR_SAFARI=false
HAS_SAFARI=false

# ── apply_one_setting <label> ─────────────────────────────────────────────────
# Maps a fzf label string to its defaults write commands.
# Sets HAS_* flags for selective service restart.
apply_one_setting() {
  local setting="$1"

  case "$setting" in

    # ── Keyboard ──────────────────────────────────────────────────────────────
    "[Keyboard]     Fast key repeat")
      HAS_KEYBOARD=true
      run_cmd defaults write NSGlobalDomain KeyRepeat -int 2
      ;;
    "[Keyboard]     Short key repeat delay")
      HAS_KEYBOARD=true
      run_cmd defaults write NSGlobalDomain InitialKeyRepeat -int 15
      ;;
    "[Keyboard]     Disable autocorrect")
      HAS_KEYBOARD=true
      run_cmd defaults write NSGlobalDomain NSAutomaticSpellingCorrectionEnabled -bool false
      ;;
    "[Keyboard]     Disable smart quotes")
      HAS_KEYBOARD=true
      run_cmd defaults write NSGlobalDomain NSAutomaticQuoteSubstitutionEnabled -bool false
      ;;
    "[Keyboard]     Disable smart dashes")
      HAS_KEYBOARD=true
      run_cmd defaults write NSGlobalDomain NSAutomaticDashSubstitutionEnabled -bool false
      ;;
    "[Keyboard]     Disable auto-capitalize")
      HAS_KEYBOARD=true
      run_cmd defaults write NSGlobalDomain NSAutomaticCapitalizationEnabled -bool false
      ;;

    # ── Trackpad ──────────────────────────────────────────────────────────────
    "[Trackpad]     Tap to click")
      run_cmd defaults write com.apple.driver.AppleBluetoothMultitouch.trackpad Clicking -bool true
      run_cmd defaults write com.apple.AppleMultitouchTrackpad Clicking -bool true
      run_cmd defaults -currentHost write NSGlobalDomain com.apple.mouse.tapBehavior -int 1
      run_cmd defaults write NSGlobalDomain com.apple.mouse.tapBehavior -int 1
      ;;
    "[Trackpad]     Three-finger drag")
      run_cmd defaults write com.apple.driver.AppleBluetoothMultitouch.trackpad TrackpadThreeFingerDrag -bool true
      run_cmd defaults write com.apple.AppleMultitouchTrackpad TrackpadThreeFingerDrag -bool true
      ;;

    # ── Finder ────────────────────────────────────────────────────────────────
    "[Finder]       Show all file extensions")
      HAS_FINDER=true
      run_cmd defaults write NSGlobalDomain AppleShowAllExtensions -bool true
      ;;
    "[Finder]       No .DS_Store on network/USB")
      HAS_FINDER=true
      run_cmd defaults write com.apple.desktopservices DSDontWriteNetworkStores -bool true
      run_cmd defaults write com.apple.desktopservices DSDontWriteUSBStores -bool true
      ;;
    "[Finder]       Show hidden files")
      HAS_FINDER=true
      run_cmd defaults write com.apple.finder AppleShowAllFiles -bool true
      ;;
    "[Finder]       Show full path in title bar")
      HAS_FINDER=true
      run_cmd defaults write com.apple.finder _FXShowPosixPathInTitle -bool true
      ;;
    "[Finder]       Show status bar")
      HAS_FINDER=true
      run_cmd defaults write com.apple.finder ShowStatusBar -bool true
      ;;
    "[Finder]       Default to list view")
      HAS_FINDER=true
      run_cmd defaults write com.apple.finder FXPreferredViewStyle -string "Nlsv"
      ;;
    "[Finder]       Keep folders on top")
      HAS_FINDER=true
      run_cmd defaults write com.apple.finder _FXSortFoldersFirst -bool true
      ;;

    # ── Dock ──────────────────────────────────────────────────────────────────
    "[Dock]         Auto-hide")
      HAS_DOCK=true
      run_cmd defaults write com.apple.dock autohide -bool true
      ;;
    "[Dock]         Remove auto-hide delay")
      HAS_DOCK=true
      run_cmd defaults write com.apple.dock autohide-delay -float 0
      ;;
    "[Dock]         Icon size 48px")
      HAS_DOCK=true
      run_cmd defaults write com.apple.dock tilesize -int 48
      ;;
    "[Dock]         Scale minimize effect")
      HAS_DOCK=true
      run_cmd defaults write com.apple.dock mineffect -string "scale"
      ;;
    "[Dock]         Don't show recent apps")
      HAS_DOCK=true
      run_cmd defaults write com.apple.dock show-recents -bool false
      ;;

    # ── Screenshots ───────────────────────────────────────────────────────────
    "[Screenshots]  Save to ~/Desktop/Screenshots")
      run_cmd mkdir -p "$HOME/Desktop/Screenshots"
      run_cmd defaults write com.apple.screencapture location -string "$HOME/Desktop/Screenshots"
      ;;
    "[Screenshots]  Save as PNG")
      run_cmd defaults write com.apple.screencapture type -string "png"
      ;;
    "[Screenshots]  Disable screenshot shadow")
      run_cmd defaults write com.apple.screencapture disable-shadow -bool true
      ;;

    # ── System ────────────────────────────────────────────────────────────────
    "[System]       Expand save panel")
      HAS_SYSTEM_OR_SAFARI=true
      run_cmd defaults write NSGlobalDomain NSNavPanelExpandedStateForSaveMode -bool true
      run_cmd defaults write NSGlobalDomain NSNavPanelExpandedStateForSaveMode2 -bool true
      ;;
    "[System]       Expand print panel")
      HAS_SYSTEM_OR_SAFARI=true
      run_cmd defaults write NSGlobalDomain PMPrintingExpandedStateForPrint -bool true
      run_cmd defaults write NSGlobalDomain PMPrintingExpandedStateForPrint2 -bool true
      ;;
    "[System]       Disable crash reporter")
      HAS_SYSTEM_OR_SAFARI=true
      run_cmd defaults write com.apple.CrashReporter DialogType -string "none"
      ;;
    "[System]       Show battery percentage")
      HAS_SYSTEM_OR_SAFARI=true
      run_cmd defaults write com.apple.controlcenter BatteryShowPercentage -bool true
      ;;
    "[System]       24-hour clock")
      HAS_SYSTEM_OR_SAFARI=true
      local _major
      _major="$(_macos_major)"
      if [ "$_major" -ge 13 ]; then
        warn "Note: 24-hour clock setting skipped — configure in System Settings → General → Language & Region on macOS 13+."
      else
        run_cmd defaults write com.apple.menuextra.clock Show24Hour -bool true
      fi
      ;;
    "[System]       Fast window resize")
      HAS_SYSTEM_OR_SAFARI=true
      run_cmd defaults write NSGlobalDomain NSWindowResizeTime -float 0.001
      ;;

    # ── Safari ────────────────────────────────────────────────────────────────
    "[Safari]       Enable developer menu")
      HAS_SYSTEM_OR_SAFARI=true
      HAS_SAFARI=true
      run_cmd defaults write com.apple.Safari IncludeDevelopMenu -bool true
      run_cmd defaults write com.apple.Safari WebKitDeveloperExtrasEnabledPreferenceKey -bool true
      run_cmd defaults write com.apple.Safari com.apple.Safari.ContentPageGroupIdentifier.WebKit2DeveloperExtrasEnabled -bool true
      local _major
      _major="$(_macos_major)"
      if [ "$_major" -ge 13 ]; then
        warn "Note: Safari defaults write is ignored on macOS 13+ — enable developer tools in Safari Settings → Advanced."
      fi
      ;;
    "[Safari]       Show full URL")
      HAS_SYSTEM_OR_SAFARI=true
      HAS_SAFARI=true
      run_cmd defaults write com.apple.Safari ShowFullURLInSmartSearchField -bool true
      local _major
      _major="$(_macos_major)"
      if [ "$_major" -ge 13 ]; then
        warn "Note: Safari defaults write is ignored on macOS 13+ — configure in Safari Settings → General."
      fi
      ;;

    # ── TextEdit ──────────────────────────────────────────────────────────────
    "[TextEdit]     Default to plain text")
      run_cmd defaults write com.apple.TextEdit RichText -int 0
      ;;

    *)
      warn "Unknown setting (skipping): $setting"
      ;;
  esac
}

# ── restart_services ──────────────────────────────────────────────────────────
# Restarts only the services affected by selected settings.
# All killall calls are guarded with || true.
#
# NOTE: restart_services() uses raw killall (not run_cmd) intentionally.
# The spec does not require printing killall commands in --dry-run mode —
# only defaults write commands are printed. The early-return guard below
# ensures no killall executes in dry-run. run_cmd() is only for
# defaults write / mkdir calls (the settings-application side).
restart_services() {
  [ "$DRY_RUN" = "true" ] && return

  header "Restarting affected services"

  # Always flush preference daemon
  killall cfprefsd 2>/dev/null || true
  success "flushed cfprefsd"

  if [ "$HAS_FINDER" = "true" ]; then
    killall Finder 2>/dev/null || true
    success "restarted Finder"
  fi

  if [ "$HAS_DOCK" = "true" ]; then
    killall Dock 2>/dev/null || true
    success "restarted Dock"
  fi

  if [ "$HAS_SYSTEM_OR_SAFARI" = "true" ]; then
    # Note: On macOS 13+, Show24Hour is skipped; if it was the only System
    # setting selected, these restarts are technically unnecessary but harmless.
    killall SystemUIServer 2>/dev/null || true
    killall ControlCenter 2>/dev/null || true
    success "restarted SystemUIServer + ControlCenter"
  fi

  if [ "$HAS_SAFARI" = "true" ]; then
    killall Safari 2>/dev/null || true
    success "restarted Safari"
  fi

  if [ "$HAS_KEYBOARD" = "true" ]; then
    echo ""
    warn "Note: keyboard settings take effect after you log out and back in."
  fi
}

# ── apply_list ────────────────────────────────────────────────────────────────
# Applies an array of setting label strings.
# Usage: apply_list "${ARRAY[@]}"
apply_list() {
  local setting
  for setting in "$@"; do
    apply_one_setting "$setting"
  done
}

# ── fzf interaction ───────────────────────────────────────────────────────────
# Requires fzf >= 0.30 for start: event and + action chaining.

# _fzf_pick <bind_string>
# Opens fzf with the full 32 settings. MINIMAL_SETTINGS listed first so
# position-based pre-selection binds work. Returns selected lines on stdout.
_fzf_pick() {
  local bind_arg="$1"
  local fzf_args=(
    --multi
    --prompt "Settings > "
    --header "Space/Tab to toggle · Enter to apply · Esc to abort"
    --height "80%"
    --reverse
  )
  if [ -n "$bind_arg" ]; then
    fzf_args+=(--bind "$bind_arg")
  fi
  printf '%s\n' "${MINIMAL_SETTINGS[@]}" "${EXTRA_SETTINGS[@]}" \
    | fzf "${fzf_args[@]}" || true
}

# _fzf_minimal_bind
# Produces the bind string that pre-selects exactly the first N items (N=9).
# Mechanism: "first+select" selects item 1, then "+down+select" repeats N-1
# times (via seq 2 N) to select items 2 through N. The %.0s printf trick
# discards the seq argument and emits the literal string N-1 times.
_fzf_minimal_bind() {
  local n="${#MINIMAL_SETTINGS[@]}"
  # Build: start:first+select+down+select+...  (N-1 additional +down+select)
  # seq 2 N generates N-1 values; %.0s discards each, emitting "+down+select" N-1 times
  local bind="start:first+select"
  bind+="$(printf '+down+select%.0s' $(seq 2 "$n"))"
  echo "$bind"
}

# pick_interactive
# Shows preset picker, then opens fzf (or fallback select).
# Sets SELECTED_SETTINGS array with the user's choices.
SELECTED_SETTINGS=()

pick_interactive() {
  echo ""
  echo -e "${BOLD}${PURPLE}╔══════════════════════════════════════════════════╗${RESET}"
  echo -e "${BOLD}${PURPLE}║          macOS System Defaults                   ║${RESET}"
  echo -e "${BOLD}${PURPLE}╚══════════════════════════════════════════════════╝${RESET}"
  echo ""

  # ── Preset picker ────────────────────────────────────────────────────────
  local preset_choice
  PS3="  Choose a starting point: "
  select preset_choice in \
    "Minimal — keyboard feel, tap-to-click, file hygiene, save panels (9 settings)" \
    "Opinionated — everything (32 settings)" \
    "Custom — nothing pre-selected"; do
    case "$REPLY" in
      1) _pick_with_fzf "minimal"; break ;;
      2) _pick_with_fzf "opinionated"; break ;;
      3) _pick_with_fzf "custom"; break ;;
      *) echo "  Enter 1, 2, or 3." ;;
    esac
  done
}

# _pick_with_fzf <mode>
# Opens fzf (or fallback) and populates SELECTED_SETTINGS.
_pick_with_fzf() {
  local mode="$1"

  if ! command -v fzf >/dev/null 2>&1; then
    _fallback_no_fzf "$mode"
    return
  fi

  local selected=""
  case "$mode" in
    opinionated) selected="$(_fzf_pick "start:select-all")" ;;
    minimal)     selected="$(_fzf_pick "$(_fzf_minimal_bind)")" ;;
    custom)      selected="$(_fzf_pick "")" ;;
    *)           warn "Unknown fzf mode: $mode"; return ;;
  esac

  # Convert newline-separated output to array
  while IFS= read -r line; do
    [ -n "$line" ] && SELECTED_SETTINGS+=("$line")
  done <<< "$selected"
}

# _fallback_no_fzf <mode>
# Preset-only fallback when fzf is not installed.
_fallback_no_fzf() {
  local mode="$1"
  warn "fzf not found — install it for per-setting selection (tools-config.sh installs it automatically)"
  echo ""

  case "$mode" in
    minimal)
      SELECTED_SETTINGS=("${MINIMAL_SETTINGS[@]}")
      info "Applying minimal preset (9 settings)"
      ;;
    opinionated)
      SELECTED_SETTINGS=("${MINIMAL_SETTINGS[@]}" "${EXTRA_SETTINGS[@]}")
      info "Applying opinionated preset (32 settings)"
      ;;
    custom)
      # Without fzf, custom mode degrades to a preset-only select menu
      echo ""
      local fallback_choice
      PS3="  Choose a preset: "
      select fallback_choice in \
        "Minimal — keyboard feel, tap-to-click, file hygiene, save panels (9 settings)" \
        "Opinionated — everything (32 settings)" \
        "Skip — do nothing"; do
        case "$REPLY" in
          1) SELECTED_SETTINGS=("${MINIMAL_SETTINGS[@]}"); break ;;
          2) SELECTED_SETTINGS=("${MINIMAL_SETTINGS[@]}" "${EXTRA_SETTINGS[@]}"); break ;;
          3) SELECTED_SETTINGS=(); break ;;
          *) echo "  Enter 1, 2, or 3." ;;
        esac
      done
      ;;
  esac
}

# ── main ─────────────────────────────────────────────────────────────────────
main() {
  if [ -n "$PRESET" ]; then
    # ── Non-interactive preset mode ─────────────────────────────────────────
    header "Applying preset: $PRESET"

    if [ "$DRY_RUN" = "true" ]; then
      info "(dry-run — commands printed, nothing applied)"
      echo ""
    fi

    case "$PRESET" in
      minimal)     apply_list "${MINIMAL_SETTINGS[@]}" ;;
      opinionated) apply_list "${MINIMAL_SETTINGS[@]}" "${EXTRA_SETTINGS[@]}" ;;
    esac

  else
    # ── Interactive mode ────────────────────────────────────────────────────
    if [ "$DRY_RUN" = "true" ]; then
      info "(dry-run — commands printed, nothing applied)"
    fi

    pick_interactive

    if [ "${#SELECTED_SETTINGS[@]}" -eq 0 ]; then
      info "No settings selected — nothing applied"
      exit 0
    fi

    header "Applying ${#SELECTED_SETTINGS[@]} setting(s)"

    if [ "$DRY_RUN" = "true" ]; then
      echo ""
    fi

    apply_list "${SELECTED_SETTINGS[@]}"
  fi

  # ── Restart services ──────────────────────────────────────────────────────
  restart_services

  # ── Done ──────────────────────────────────────────────────────────────────
  echo ""
  success "Done."
  if [ "$DRY_RUN" = "true" ]; then
    info "(dry-run complete — no changes were made)"
  fi
}

main
