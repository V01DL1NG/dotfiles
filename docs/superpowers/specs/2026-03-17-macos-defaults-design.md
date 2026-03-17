# macOS System Defaults — Design Spec

**Date:** 2026-03-17
**Status:** Approved
**Scope:** New `macos-defaults.sh` script with preset + interactive fzf selection, integrated into `install-all.sh`, `bootstrap.sh`, and `doctor.sh`

---

## Overview

A new standalone script `macos-defaults.sh` applies curated macOS system defaults via `defaults write`. It supports three invocation modes: apply a named preset non-interactively, open an fzf multi-select checklist pre-populated by preset, or custom (nothing pre-selected). Exits cleanly on non-macOS systems.

---

## Component 1 — `macos-defaults.sh`

### Invocation modes

```bash
./macos-defaults.sh                          # interactive: preset picker → fzf checklist
./macos-defaults.sh minimal                  # apply minimal preset, no interaction
./macos-defaults.sh opinionated              # apply all settings, no interaction
./macos-defaults.sh --dry-run                # interactive, print commands only, apply nothing
./macos-defaults.sh minimal --dry-run        # minimal preset, print commands only
./macos-defaults.sh opinionated --dry-run    # opinionated preset, print commands only
```

`--dry-run` is accepted as the second positional argument (after an optional preset name) or as the only argument. In `--dry-run` mode, fzf still opens (if interactive) so the user can see exactly what would apply; no `defaults write` or `killall` commands execute.

The script uses `set -euo pipefail`. All `killall` calls are guarded with `|| true` to prevent exit on already-running services.

### Interactive flow

1. Short `select` menu: `1) Minimal  2) Opinionated  3) Custom`
2. fzf multi-select checklist opens (see fzf mechanism below)
3. User confirms; settings apply via `defaults write`
4. Affected services restarted (see restart list below)
5. Summary printed; keyboard-change reminder shown only if a Keyboard setting was selected

### fzf pre-selection mechanism

Settings are stored in two ordered arrays:
- `MINIMAL_SETTINGS` — 11 entries (the minimal preset)
- `EXTRA_SETTINGS` — 21 entries (opinionated-only additions)

For the fzf call, input is always the full 32 settings. Pre-selection is achieved by listing `MINIMAL_SETTINGS` entries first in the input, then `EXTRA_SETTINGS`. The fzf invocation:

```bash
# opinionated: all pre-selected
printf '%s\n' "${MINIMAL_SETTINGS[@]}" "${EXTRA_SETTINGS[@]}" \
  | fzf --multi --bind 'start:select-all' ...

# minimal: only the first N items pre-selected (N = ${#MINIMAL_SETTINGS[@]} = 11)
# achieved by passing minimal items first and selecting only them:
printf '%s\n' "${MINIMAL_SETTINGS[@]}" "${EXTRA_SETTINGS[@]}" \
  | fzf --multi --bind "start:first+select$(printf '+down+select%.0s' $(seq 2 ${#MINIMAL_SETTINGS[@]}))" ...

# custom: nothing pre-selected (no --bind start)
printf '%s\n' "${MINIMAL_SETTINGS[@]}" "${EXTRA_SETTINGS[@]}" \
  | fzf --multi ...
```

Each fzf line format: `[Category]  Setting description` — the category prefix makes the flat list scannable without sub-menus.

### fzf fallback (fzf not installed)

If `fzf` is not available, the interactive flow degrades to a `select`-based preset-only menu:

```
1) Minimal      — keyboard feel, tap-to-click, file hygiene, save panels (11 settings)
2) Opinionated  — everything (32 settings)
3) Skip         — do nothing
```

Per-setting granularity is not available without fzf. A warning is printed: `"fzf not found — install it for per-setting selection (tools-config.sh installs it automatically)"`. Preset selection still works fully.

---

## Component 2 — Settings catalog with defaults commands

All writes are to the current user's domain. No `sudo` required. All settings are confirmed user-domain writes safe on macOS 12+.

### Keyboard (requires logout to take full effect — reminder shown if any Keyboard setting selected)

| Setting | Minimal | defaults write command(s) |
|---|:---:|---|
| Fast key repeat | ✓ | `defaults write NSGlobalDomain KeyRepeat -int 2` |
| Short key repeat delay | ✓ | `defaults write NSGlobalDomain InitialKeyRepeat -int 15` |
| Disable autocorrect | ✓ | `defaults write NSGlobalDomain NSAutomaticSpellingCorrectionEnabled -bool false` |
| Disable smart quotes | | `defaults write NSGlobalDomain NSAutomaticQuoteSubstitutionEnabled -bool false` |
| Disable smart dashes | | `defaults write NSGlobalDomain NSAutomaticDashSubstitutionEnabled -bool false` |
| Disable auto-capitalize | | `defaults write NSGlobalDomain NSAutomaticCapitalizationEnabled -bool false` |

### Trackpad (restart: none — takes effect immediately after `killall cfprefsd`)

| Setting | Minimal | defaults write command(s) |
|---|:---:|---|
| Tap to click | ✓ | `defaults write com.apple.driver.AppleBluetoothMultitouch.trackpad Clicking -bool true`<br>`defaults write com.apple.AppleMultitouchTrackpad Clicking -bool true`<br>`defaults -currentHost write NSGlobalDomain com.apple.mouse.tapBehavior -int 1`<br>`defaults write NSGlobalDomain com.apple.mouse.tapBehavior -int 1` |
| Three-finger drag | | `defaults write com.apple.driver.AppleBluetoothMultitouch.trackpad TrackpadThreeFingerDrag -bool true`<br>`defaults write com.apple.AppleMultitouchTrackpad TrackpadThreeFingerDrag -bool true` |

### Finder (restart: `killall Finder || true`)

| Setting | Minimal | defaults write command(s) |
|---|:---:|---|
| Show all file extensions | ✓ | `defaults write NSGlobalDomain AppleShowAllExtensions -bool true` |
| No .DS_Store on network/USB | ✓ | `defaults write com.apple.desktopservices DSDontWriteNetworkStores -bool true`<br>`defaults write com.apple.desktopservices DSDontWriteUSBStores -bool true` |
| Show hidden files | | `defaults write com.apple.finder AppleShowAllFiles -bool true` |
| Show full path in title bar | | `defaults write com.apple.finder _FXShowPosixPathInTitle -bool true` |
| Show status bar | | `defaults write com.apple.finder ShowStatusBar -bool true` |
| Default to list view | | `defaults write com.apple.finder FXPreferredViewStyle -string "Nlsv"` |
| Keep folders on top | | `defaults write com.apple.finder _FXSortFoldersFirst -bool true` |

### Dock (restart: `killall Dock || true`)

| Setting | Minimal | defaults write command(s) |
|---|:---:|---|
| Auto-hide | | `defaults write com.apple.dock autohide -bool true` |
| Remove auto-hide delay | | `defaults write com.apple.dock autohide-delay -float 0` |
| Icon size 48px | | `defaults write com.apple.dock tilesize -int 48` |
| Scale minimize effect | | `defaults write com.apple.dock mineffect -string "scale"` |
| Don't show recent apps | | `defaults write com.apple.dock show-recents -bool false` |

### Screenshots (no restart needed; `~/Desktop/Screenshots` dir created if missing)

| Setting | Minimal | defaults write command(s) |
|---|:---:|---|
| Save to ~/Desktop/Screenshots | ✓ | `mkdir -p "$HOME/Desktop/Screenshots"`<br>`defaults write com.apple.screencapture location -string "$HOME/Desktop/Screenshots"` |
| Save as PNG | | `defaults write com.apple.screencapture type -string "png"` |
| Disable screenshot shadow | | `defaults write com.apple.screencapture disable-shadow -bool true` |

### System (restart: `killall SystemUIServer || true`, `killall ControlCenter || true`)

| Setting | Minimal | defaults write command(s) |
|---|:---:|---|
| Expand save panel | ✓ | `defaults write NSGlobalDomain NSNavPanelExpandedStateForSaveMode -bool true`<br>`defaults write NSGlobalDomain NSNavPanelExpandedStateForSaveMode2 -bool true` |
| Expand print panel | ✓ | `defaults write NSGlobalDomain PMPrintingExpandedStateForPrint -bool true`<br>`defaults write NSGlobalDomain PMPrintingExpandedStateForPrint2 -bool true` |
| Disable crash reporter | | `defaults write com.apple.CrashReporter DialogType -string "none"` |
| Show battery percentage | | `defaults write com.apple.controlcenter BatteryShowPercentage -bool true` |
| 24-hour clock | | `defaults write com.apple.menuextra.clock Show24Hour -bool true` |
| Fast window resize | | `defaults write NSGlobalDomain NSWindowResizeTime -float 0.001` |

### Safari (restart: `killall Safari || true`)

| Setting | Minimal | defaults write command(s) |
|---|:---:|---|
| Enable developer menu | | `defaults write com.apple.Safari IncludeDevelopMenu -bool true`<br>`defaults write com.apple.Safari WebKitDeveloperExtrasEnabledPreferenceKey -bool true`<br>`defaults write com.apple.Safari com.apple.Safari.ContentPageGroupIdentifier.WebKit2DeveloperExtrasEnabled -bool true` |
| Show full URL | | `defaults write com.apple.Safari ShowFullURLInSmartSearchField -bool true` |

### TextEdit (no restart needed)

| Setting | Minimal | defaults write command(s) |
|---|:---:|---|
| Default to plain text | | `defaults write com.apple.TextEdit RichText -int 0` |

---

## Component 3 — Service restart list

After applying selected settings, restart only the services relevant to what was applied:

```bash
# Always run (preference daemon flush)
killall cfprefsd || true

# If any Finder setting selected
killall Finder || true

# If any Dock setting selected
killall Dock || true

# If any System (battery/clock) or Safari setting selected
killall SystemUIServer || true
killall ControlCenter || true

# If any Safari setting selected
killall Safari || true

# If any Keyboard setting was selected — show reminder, do NOT killall
# (keyboard repeat settings require logout/new session to take full effect)
echo "  Note: keyboard settings take effect after you log out and back in."
```

---

## Component 4 — Integration

### `install-all.sh`

New step, macOS-only gated:

```bash
if [ "$DOTFILES_OS" = "macos" ]; then
  bash "$SCRIPT_DIR/macos-defaults.sh"   # interactive by default
fi
```

### `bootstrap.sh`

Passes `minimal` to skip interactive picker during first-run automation:

```bash
bash "$DOTFILES_DIR/macos-defaults.sh" minimal
```

### `doctor.sh`

Two new checks in the macOS section:
- Warn if `~/Desktop/Screenshots` does not exist (suggests defaults were never applied)
- Warn if `KeyRepeat` is still at macOS default (`defaults read NSGlobalDomain KeyRepeat` equals `6` or higher), prompting user to run `./macos-defaults.sh`

---

## Error handling

| Condition | Behaviour |
|---|---|
| Non-macOS OS | `exit 0` with `info "Skipping macOS defaults (macOS only)"` |
| `fzf` not installed | Fall back to `select` preset menu (see fzf fallback above) |
| `--dry-run` | fzf still opens interactively; no `defaults write` or `killall` runs; each command printed to stdout |
| No settings selected | `exit 0` with `info "No settings selected — nothing applied"` |
| `killall` fails | Guarded with `|| true` — warn if service was open, continue |
| `defaults write` silent failure | Not detectable without `sudo` introspection; script proceeds; doctor.sh detects KeyRepeat as a proxy |
