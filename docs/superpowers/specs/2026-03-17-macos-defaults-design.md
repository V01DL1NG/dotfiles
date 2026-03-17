# macOS System Defaults — Design Spec

**Date:** 2026-03-17
**Status:** Approved
**Scope:** New `macos-defaults.sh` script with preset + interactive fzf selection, integrated into `install-all.sh`, `bootstrap.sh`, and `doctor.sh`

---

## Overview

A new standalone script `macos-defaults.sh` applies curated macOS system defaults via `defaults write`. It supports three invocation modes: apply a named preset non-interactively, or open an fzf multi-select checklist pre-populated by a chosen preset. Exits cleanly (success) on non-macOS systems.

---

## Component 1 — `macos-defaults.sh`

### Invocation modes

```bash
./macos-defaults.sh                # interactive: preset picker → fzf checklist
./macos-defaults.sh minimal        # apply minimal preset, no interaction
./macos-defaults.sh opinionated    # apply all settings, no interaction
./macos-defaults.sh --dry-run      # print what would change, apply nothing
```

### Interactive flow

1. Short `select` menu: `1) Minimal  2) Opinionated  3) Custom`
2. fzf multi-select opens with all settings as lines, pre-checked based on preset:
   - `minimal` → ~11 settings pre-selected
   - `opinionated` → all ~32 settings pre-selected
   - `custom` → nothing pre-selected
3. User confirms selection; settings apply via `defaults write`
4. `killall` restarts affected services: `Finder`, `Dock`, `SystemUIServer`
5. Summary printed; reminder to open a new terminal/log out for keyboard settings

### fzf line format

Each line: `[Category]  Setting description`

Example:
```
[Keyboard]    Fast key repeat (rate 2)
[Keyboard]    Short key repeat delay (delay 15)
[Finder]      Show all file extensions
[Dock]        Auto-hide Dock
```

Category prefix makes the flat list scannable without sub-menus.

---

## Component 2 — Settings catalog

| Category | Setting | Minimal | Opinionated |
|---|---|:---:|:---:|
| Keyboard | Fast key repeat (rate 2) | ✓ | ✓ |
| Keyboard | Short key repeat delay (delay 15) | ✓ | ✓ |
| Keyboard | Disable autocorrect | ✓ | ✓ |
| Keyboard | Disable smart quotes | | ✓ |
| Keyboard | Disable smart dashes | | ✓ |
| Keyboard | Disable auto-capitalize | | ✓ |
| Trackpad | Tap to click | ✓ | ✓ |
| Trackpad | Three-finger drag | | ✓ |
| Finder | Show all file extensions | ✓ | ✓ |
| Finder | Show hidden files | | ✓ |
| Finder | Show full path in title bar | | ✓ |
| Finder | Show status bar | | ✓ |
| Finder | No .DS_Store on network/USB volumes | ✓ | ✓ |
| Finder | Default to list view | | ✓ |
| Finder | Keep folders on top when sorting | | ✓ |
| Dock | Auto-hide Dock | | ✓ |
| Dock | Remove auto-hide delay | | ✓ |
| Dock | Icon size 48px | | ✓ |
| Dock | Scale minimize effect | | ✓ |
| Dock | Don't show recent apps | | ✓ |
| Screenshots | Save to ~/Desktop/Screenshots | ✓ | ✓ |
| Screenshots | Disable screenshot shadow | | ✓ |
| Screenshots | Save as PNG | | ✓ |
| System | Expand save panel by default | ✓ | ✓ |
| System | Expand print panel by default | ✓ | ✓ |
| System | Disable crash reporter dialogs | | ✓ |
| System | Show battery percentage | | ✓ |
| System | 24-hour clock | | ✓ |
| System | Fast window resize (no animation delay) | | ✓ |
| Safari | Enable developer menu | | ✓ |
| Safari | Show full URL in address bar | | ✓ |
| TextEdit | Default to plain text | | ✓ |

**Minimal:** 11 settings — keyboard feel, tap-to-click, file hygiene, save panels. Safe on any Mac.
**Opinionated:** all 32 settings — everything above plus Dock, Finder, system polish.

---

## Component 3 — Integration

### `install-all.sh`

New step after existing tool installs, gated on `$DOTFILES_OS`:

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
- Warn if `~/Desktop/Screenshots` directory does not exist (suggests defaults were never applied)
- Warn if `KeyRepeat` is still at the macOS default value (15), suggesting defaults were never applied

---

## Error handling

| Condition | Behaviour |
|---|---|
| Non-macOS OS | Exit 0 with info message "Skipping macOS defaults (macOS only)" |
| `fzf` not installed | Fall back to `select`-based menu, warn user to install fzf for better UX |
| `--dry-run` | Print each `defaults write` command that would run; apply nothing |
| No settings selected | Exit 0 with message "No settings selected — nothing applied" |
| `killall Finder` fails | Warn, do not exit — Finder may already be restarting |

---

## File changes summary

| File | Type | Notes |
|---|---|---|
| `macos-defaults.sh` | **New** | Standalone defaults script |
| `install-all.sh` | Modified | Add macOS-gated call to `macos-defaults.sh` |
| `bootstrap.sh` | Modified | Add `macos-defaults.sh minimal` after profile install |
| `doctor.sh` | Modified | Add Screenshots folder + KeyRepeat checks |
