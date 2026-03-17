# macOS System Defaults Implementation Plan

> **For agentic workers:** REQUIRED: Use superpowers:subagent-driven-development (if subagents available) or superpowers:executing-plans to implement this plan. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Create `macos-defaults.sh`, a standalone script that applies curated macOS system defaults with preset support and interactive fzf selection, integrated into `install-all.sh`, `bootstrap.sh`, and `doctor.sh`.

**Architecture:** A single self-contained bash script holds all 32 settings in two ordered arrays (`MINIMAL_SETTINGS` / `EXTRA_SETTINGS`). A `case` statement in `apply_one_setting()` maps each fzf label string to its `defaults write` commands. Category-presence flags drive selective service restarts. A `run_cmd()` wrapper enables `--dry-run` mode without duplicating logic.

**Tech Stack:** bash, macOS `defaults` CLI, fzf (>= 0.30, optional), `killall`, `sw_vers`

**Spec:** `docs/superpowers/specs/2026-03-17-macos-defaults-design.md`

---

## Chunk 1: `macos-defaults.sh`

### Task 1: Scaffold, settings arrays, and dry-run wrapper

**Files:**
- Create: `macos-defaults.sh`

The file has four sections in order: (1) header/setup, (2) settings arrays, (3) helper functions, (4) main flow. This task covers sections 1 and 2.

- [ ] **Step 1: Write the failing syntax test**

Add a temporary check to verify the file doesn't exist yet:

```bash
# Just confirm we're starting fresh
[ ! -f macos-defaults.sh ] && echo "OK: file doesn't exist yet"
```

- [ ] **Step 2: Create `macos-defaults.sh` with scaffold and arrays**

```bash
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
# Use run_cmd() for every defaults write, mkdir, and killall call.
run_cmd() {
  if [ "$DRY_RUN" = "true" ]; then
    echo "  $*"
  else
    "$@"
  fi
}
```

- [ ] **Step 3: Verify syntax**

```bash
bash -n macos-defaults.sh
```

Expected: no output, exit 0.

- [ ] **Step 4: Commit**

```bash
git add macos-defaults.sh
git commit -m "feat: macos-defaults.sh scaffold, arrays, and dry-run wrapper"
```

---

### Task 2: `apply_one_setting()` — the defaults write dispatch

**Files:**
- Modify: `macos-defaults.sh` (append after the arrays section)

This function takes one label string (the fzf line), runs the correct `defaults write` commands via `run_cmd()`, sets category flags, and handles macOS version caveats.

- [ ] **Step 1: Write a test for apply_one_setting output in dry-run mode**

Create `test-macos-defaults.sh`:

```bash
#!/usr/bin/env bash
# test-macos-defaults.sh — unit tests for macos-defaults.sh
# Only runs on macOS; exits 0 on Linux with a skip message.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PASS=0; FAIL=0

pass()    { echo "  ✓ $1"; PASS=$((PASS + 1)); }
fail()    { echo "  ✗ $1"; FAIL=$((FAIL + 1)); }
section() { echo ""; echo "── $1"; }

if [ "$(uname -s)" != "Darwin" ]; then
  echo "Skipping macos-defaults tests (macOS only)"
  exit 0
fi

# ── Helper: run script in dry-run mode and capture output ─────────────────────
dry_run_output() {
  bash "$SCRIPT_DIR/macos-defaults.sh" "$@" 2>&1 || true
}

# ── Dry-run output: minimal preset ────────────────────────────────────────────
section "Dry-run: minimal preset"

out="$(dry_run_output minimal --dry-run)"

# Should contain expected defaults write commands
if echo "$out" | grep -q "defaults write NSGlobalDomain KeyRepeat"; then
  pass "minimal --dry-run: KeyRepeat command present"
else
  fail "minimal --dry-run: KeyRepeat command missing"
fi

if echo "$out" | grep -q "defaults write NSGlobalDomain InitialKeyRepeat"; then
  pass "minimal --dry-run: InitialKeyRepeat command present"
else
  fail "minimal --dry-run: InitialKeyRepeat command missing"
fi

if echo "$out" | grep -q "defaults write com.apple.screencapture location"; then
  pass "minimal --dry-run: screenshot location command present"
else
  fail "minimal --dry-run: screenshot location command missing"
fi

# Should NOT contain opinionated-only commands
if echo "$out" | grep -q "defaults write com.apple.dock autohide"; then
  fail "minimal --dry-run: should not contain Dock autohide"
else
  pass "minimal --dry-run: Dock autohide correctly absent"
fi

# ── Dry-run output: opinionated preset ────────────────────────────────────────
section "Dry-run: opinionated preset"

out="$(dry_run_output opinionated --dry-run)"

if echo "$out" | grep -q "defaults write com.apple.dock autohide"; then
  pass "opinionated --dry-run: Dock autohide present"
else
  fail "opinionated --dry-run: Dock autohide missing"
fi

if echo "$out" | grep -q "defaults write com.apple.TextEdit RichText"; then
  pass "opinionated --dry-run: TextEdit plain text present"
else
  fail "opinionated --dry-run: TextEdit plain text missing"
fi

# ── Dry-run does not modify system settings ────────────────────────────────────
section "Dry-run: no actual writes"

# Read KeyRepeat before
before="$(defaults read NSGlobalDomain KeyRepeat 2>/dev/null || echo 'unset')"
dry_run_output minimal --dry-run >/dev/null 2>&1 || true
after="$(defaults read NSGlobalDomain KeyRepeat 2>/dev/null || echo 'unset')"

if [ "$before" = "$after" ]; then
  pass "dry-run: KeyRepeat unchanged (before=$before after=$after)"
else
  fail "dry-run: KeyRepeat changed! (before=$before after=$after)"
fi

# ── Argument parsing ──────────────────────────────────────────────────────────
section "Argument parsing"

# Invalid preset should exit non-zero
if bash "$SCRIPT_DIR/macos-defaults.sh" bogus 2>/dev/null; then
  fail "bogus preset: should exit non-zero"
else
  pass "bogus preset: exits with error"
fi

# ── Summary ───────────────────────────────────────────────────────────────────
echo ""
echo "────────────────────────────────"
printf "  passed: %d  failed: %d\n" "$PASS" "$FAIL"
echo "────────────────────────────────"
echo ""

[ "$FAIL" -eq 0 ]
```

- [ ] **Step 2: Run test — confirm it fails** (apply_one_setting not yet implemented)

```bash
bash test-macos-defaults.sh 2>&1 | head -30
```

Expected: test output shows failures for dry-run output checks.

- [ ] **Step 3: Implement `apply_one_setting()` in `macos-defaults.sh`**

Append after the `run_cmd()` function:

```bash
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
        warn "Note: Safari defaults write is ignored on macOS 13+ — enable developer tools in Safari Settings → Advanced."
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
```

- [ ] **Step 4: Run tests — confirm dry-run output tests now pass**

```bash
bash test-macos-defaults.sh
```

Expected: all dry-run output tests pass. Argument parsing test for "bogus preset" may still fail until main() is wired.

- [ ] **Step 5: Verify syntax**

```bash
bash -n macos-defaults.sh
```

Expected: exit 0, no output.

- [ ] **Step 6: Commit**

```bash
git add macos-defaults.sh test-macos-defaults.sh
git commit -m "feat: apply_one_setting() with all 32 defaults write commands and dry-run support"
```

---

### Task 3: Service restart and fzf interaction

**Files:**
- Modify: `macos-defaults.sh` (append restart + fzf functions)

- [ ] **Step 1: Implement `restart_services()` in `macos-defaults.sh`**

Append after `apply_one_setting()`:

```bash
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
```

- [ ] **Step 2: Implement fzf interaction functions in `macos-defaults.sh`**

Append after `apply_list()`:

```bash
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

  local selected
  case "$mode" in
    opinionated) selected="$(_fzf_pick "start:select-all")" ;;
    minimal)     selected="$(_fzf_pick "$(_fzf_minimal_bind)")" ;;
    custom)      selected="$(_fzf_pick "")" ;;
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
```

- [ ] **Step 3: Verify syntax**

```bash
bash -n macos-defaults.sh
```

Expected: exit 0, no output.

- [ ] **Step 4: Commit**

```bash
git add macos-defaults.sh
git commit -m "feat: restart_services(), apply_list(), and fzf interaction functions"
```

---

### Task 4: `main()` — argument dispatch and summary

**Files:**
- Modify: `macos-defaults.sh` (append main function and entry point)

- [ ] **Step 1: Implement `main()` in `macos-defaults.sh`**

Append at the end of the file:

```bash
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
```

- [ ] **Step 2: Run the full test suite**

```bash
bash test-macos-defaults.sh
```

Expected: all tests pass including the "bogus preset exits with error" test.

- [ ] **Step 3: Smoke test dry-run manually**

```bash
bash macos-defaults.sh minimal --dry-run
```

Expected: prints `defaults write` commands to stdout, no actual macOS settings changed.

```bash
bash macos-defaults.sh opinionated --dry-run 2>&1 | wc -l
```

Expected: significantly more lines than `minimal --dry-run` (opinionated has 32 settings with multiple writes each).

- [ ] **Step 4: Verify syntax**

```bash
bash -n macos-defaults.sh
```

- [ ] **Step 5: Make executable and commit**

```bash
chmod +x macos-defaults.sh
git add macos-defaults.sh
git commit -m "feat: main() dispatch — preset + interactive + dry-run modes complete"
```

---

## Chunk 2: Integrations and tests

### Task 5: Add `macos-defaults.sh` to `install-all.sh` and `bootstrap.sh`

**Files:**
- Modify: `install-all.sh` (add macOS-gated call before the "Setup complete!" banner)
- Modify: `bootstrap.sh` (add `macos-defaults.sh minimal` in `run_setup()`)

- [ ] **Step 1: Write a failing test for install-all.sh integration**

Check that the script reference exists in install-all.sh:

```bash
grep -q 'macos-defaults.sh' install-all.sh && echo "PASS" || echo "FAIL: not present yet"
```

Expected: `FAIL: not present yet`

- [ ] **Step 2: Modify `install-all.sh`**

In `install-all.sh`, find the block that starts the "Setup complete!" echo at the end. Add the macOS defaults step immediately before it.

**Note on bootstrap.sh double-call:** `bootstrap.sh` calls `macos-defaults.sh minimal` explicitly, then calls `install-all.sh`, which will call `macos-defaults.sh` interactively. The `minimal` pass applies settings non-interactively during the automated bootstrap; the interactive pass in `install-all.sh` then lets the user refine. This is intentional per the spec. The script is idempotent — running it twice is safe.

```bash
# macos-defaults.sh — macOS only, interactive by design
# (bootstrap.sh passes 'minimal' for automated runs)
echo ""
if [ "$DOTFILES_OS" = "macos" ]; then
  echo "-- [macOS System Defaults] --"
  if [ -f "$SCRIPT_DIR/macos-defaults.sh" ]; then
    bash "$SCRIPT_DIR/macos-defaults.sh"
  else
    echo "Warning: macos-defaults.sh not found, skipping."
  fi
fi
```

Insert this block just before the `echo ""` that starts `echo "Setup complete!"`.

Exact location in `install-all.sh` (currently line 70-74):

```bash
echo ""
echo "=================================="
echo "  Setup complete!"
echo "=================================="
```

Becomes:

```bash
# macos-defaults.sh — macOS only, interactive by design
# (bootstrap.sh passes 'minimal' for automated runs)
echo ""
if [ "$DOTFILES_OS" = "macos" ]; then
  echo "-- [macOS System Defaults] --"
  if [ -f "$SCRIPT_DIR/macos-defaults.sh" ]; then
    bash "$SCRIPT_DIR/macos-defaults.sh"
  else
    echo "Warning: macos-defaults.sh not found, skipping."
  fi
fi

echo ""
echo "=================================="
echo "  Setup complete!"
echo "=================================="
```

- [ ] **Step 3: Verify install-all.sh syntax**

```bash
bash -n install-all.sh
```

Expected: exit 0.

- [ ] **Step 4: Verify test passes**

```bash
grep -q 'macos-defaults.sh' install-all.sh && echo "PASS" || echo "FAIL"
```

Expected: `PASS`

- [ ] **Step 5: Modify `bootstrap.sh`**

In `bootstrap.sh`, the `run_setup()` function (around line 135) currently is:

```bash
run_setup() {
  header "Choosing shell profile"
  bash "$REPO_DIR/choose-profile.sh"

  header "Running full install"
  bash "$REPO_DIR/install-all.sh"
}
```

Add the `macos-defaults.sh minimal` call after `choose-profile.sh` and before `install-all.sh`:

```bash
run_setup() {
  header "Choosing shell profile"
  bash "$REPO_DIR/choose-profile.sh"

  header "Applying macOS system defaults (minimal preset)"
  bash "$REPO_DIR/macos-defaults.sh" minimal

  header "Running full install"
  bash "$REPO_DIR/install-all.sh"
}
```

- [ ] **Step 6: Verify bootstrap.sh syntax**

```bash
bash -n bootstrap.sh
```

Expected: exit 0.

- [ ] **Step 7: Commit**

```bash
git add install-all.sh bootstrap.sh
git commit -m "feat: integrate macos-defaults.sh into install-all.sh and bootstrap.sh"
```

---

### Task 6: Add doctor.sh checks for macOS defaults

**Files:**
- Modify: `doctor.sh` (add `section_macos_defaults()` and call it from `main()`)

- [ ] **Step 1: Write a failing test**

```bash
grep -q 'section_macos_defaults' doctor.sh && echo "PASS" || echo "FAIL: not present yet"
```

Expected: `FAIL: not present yet`

- [ ] **Step 2: Add `section_macos_defaults()` to `doctor.sh`**

In `doctor.sh`, add the new section function after `section_iterm2()` (around line 306) and before `section_roles()`:

```bash
# ── Section: macOS defaults ───────────────────────────────────────────────────
section_macos_defaults() {
  # macOS-only checks — skip on Linux
  [ "$DOTFILES_OS" != "macos" ] && return

  header "macOS System Defaults"

  # Check 1: Screenshots directory
  if [ -d "$HOME/Desktop/Screenshots" ]; then
    pass "~/Desktop/Screenshots directory exists"
  else
    warn_count "~/Desktop/Screenshots not found — run: ./macos-defaults.sh"
  fi

  # Check 2: KeyRepeat — macOS default is 6; anything >= 6 means defaults not applied
  local key_repeat
  key_repeat="$(defaults read NSGlobalDomain KeyRepeat 2>/dev/null || echo 99)"
  if [ "$key_repeat" -lt 6 ] 2>/dev/null; then
    pass "KeyRepeat = $key_repeat (fast repeat configured)"
  else
    warn_count "KeyRepeat = $key_repeat (macOS default or higher) — run: ./macos-defaults.sh"
  fi
}
```

- [ ] **Step 3: Call `section_macos_defaults()` from `main()` in `doctor.sh`**

In `doctor.sh`, find the `main()` function (around line 389):

```bash
main() {
  section_brew
  section_prompt
  section_tools
  section_plugins
  section_configs
  section_git
  section_font
  section_iterm2
  section_roles
  section_linux_shell
  section_linux_clipboard
  section_linux_server
  print_summary
  ...
}
```

Add `section_macos_defaults` after `section_iterm2`:

```bash
main() {
  section_brew
  section_prompt
  section_tools
  section_plugins
  section_configs
  section_git
  section_font
  section_iterm2
  section_macos_defaults
  section_roles
  section_linux_shell
  section_linux_clipboard
  section_linux_server
  print_summary

  if [ "$FAIL" -gt 0 ]; then
    exit 1
  fi
}
```

- [ ] **Step 4: Verify syntax**

```bash
bash -n doctor.sh
```

Expected: exit 0.

- [ ] **Step 5: Verify test passes**

```bash
grep -q 'section_macos_defaults' doctor.sh && echo "PASS" || echo "FAIL"
```

Expected: `PASS`

- [ ] **Step 6: Commit**

```bash
git add doctor.sh
git commit -m "feat: doctor.sh section_macos_defaults — Screenshots dir and KeyRepeat checks"
```

---

### Task 7: Add `macos-defaults.sh` to `test.sh` syntax checks and run full suite

**Files:**
- Modify: `test.sh` (add syntax_check for macos-defaults.sh and test-macos-defaults.sh integration)

- [ ] **Step 1: Locate the syntax_check block in test.sh**

The existing block (around line 168) looks like:

```bash
syntax_check platform.sh
syntax_check tools-config.sh
...
syntax_check bootstrap-server.sh
```

- [ ] **Step 2: Add syntax check for `macos-defaults.sh`**

After the `syntax_check bootstrap-server.sh` line, add:

```bash
syntax_check macos-defaults.sh
```

- [ ] **Step 3: Add integration test for `test-macos-defaults.sh`**

After the `test-platform.sh` integration block:

```bash
# ════════════════════════════════════════════════
section "macOS Defaults — test-macos-defaults.sh"
# ════════════════════════════════════════════════

if [ "$(uname -s)" != "Darwin" ]; then
  warn "test-macos-defaults.sh skipped (macOS only)"
elif bash "$SCRIPT_DIR/test-macos-defaults.sh" >/dev/null 2>&1; then
  pass "test-macos-defaults.sh passed"
else
  fail "test-macos-defaults.sh — one or more checks failed (run ./test-macos-defaults.sh for details)"
fi
```

- [ ] **Step 4: Run `test.sh` and verify all checks pass**

```bash
bash test.sh
```

Expected: syntax check for `macos-defaults.sh` passes, `test-macos-defaults.sh` passes on macOS.

- [ ] **Step 5: Run `test-macos-defaults.sh` standalone for detail**

```bash
bash test-macos-defaults.sh
```

Expected: all tests pass with 0 failures.

- [ ] **Step 6: Commit**

```bash
git add test.sh test-macos-defaults.sh
git commit -m "test: add macos-defaults.sh syntax check and test-macos-defaults.sh to test suite"
```

---

## Post-implementation checklist

- [ ] `bash -n macos-defaults.sh` — syntax clean
- [ ] `bash test-macos-defaults.sh` — all pass
- [ ] `bash test.sh` — all pass (including new syntax_check and test-macos-defaults integration)
- [ ] `bash macos-defaults.sh minimal --dry-run` — prints expected commands, exits 0
- [ ] `bash macos-defaults.sh opinionated --dry-run` — prints more commands, exits 0
- [ ] `bash macos-defaults.sh bogus 2>&1` — prints error, exits non-zero
- [ ] `bash doctor.sh` — shows "macOS System Defaults" section with expected checks
- [ ] `grep -q 'macos-defaults.sh' install-all.sh` — integration present
- [ ] `grep -q 'macos-defaults.sh' bootstrap.sh` — integration present
