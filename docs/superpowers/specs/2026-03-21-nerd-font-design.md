# Nerd Font Detection & Configuration — Design Spec

**Date:** 2026-03-21
**Status:** Draft

---

## Overview

Add Nerd Font detection to `doctor.sh` and a new `font-config.sh` TUI that diagnoses and optionally fixes font configuration across all supported terminals.

**Problem:** Users can have FiraCode Nerd Font installed on disk but their terminal not configured to use it, resulting in broken oh-my-posh glyphs. `doctor.sh` currently only checks file presence, not terminal configuration.

**Goals:**
- Expand `doctor.sh` to check terminal font config (not just file presence)
- New `font-config.sh` — interactive TUI to detect misconfigured terminals and report/fix
- Cover all supported terminals: iTerm2, Ghostty, Kitty, VS Code
- macOS and Linux supported (iTerm2 checks are macOS-only; all others cross-platform)

**Non-goals:**
- PowerShell 7 profile (separate spec)
- Installing the font itself (already handled by Brewfile / existing doctor.sh warn message)
- Supporting terminals beyond the four listed
- Windows support
- Non-interactive apply mode (e.g. wiring into `install-all.sh`) — VS Code fix is interactive-only for now

---

## Architecture

### Supported Terminals

| Terminal | Platform | Installed check | Font config check |
|---|---|---|---|
| iTerm2 | macOS only | `/Applications/iTerm.app` exists | DynamicProfiles JSON `"Normal Font"` value contains `FiraCode` |
| Ghostty | macOS + Linux | `/Applications/Ghostty.app` (macOS) or `ghostty` binary in PATH (Linux) | `~/.config/ghostty/config` contains `font-family = FiraCode Nerd Font` |
| Kitty | macOS + Linux | `/Applications/kitty.app` (macOS) or `kitty` binary in PATH (Linux) | `~/.config/kitty/kitty.conf` contains `font_family` line matching `FiraCode` |
| VS Code | macOS + Linux | `code` binary in PATH | `settings.json` (see paths below) has `terminal.integrated.fontFamily` containing `FiraCode` |

**VS Code `settings.json` paths:**
- macOS: `~/Library/Application Support/Code/User/settings.json`
- Linux: `~/.config/Code/User/settings.json`

**iTerm2 DynamicProfiles font check:** parse each `.json` file in `~/Library/Application Support/iTerm2/DynamicProfiles/` and check whether the `"Normal Font"` key's value contains `FiraCode`. A file without that key is treated as not configured (no false positives from other string matches).

### Font File Paths

Font file presence is checked before terminal config checks. If the font is not installed, terminal checks are skipped entirely.

| Platform | Paths checked |
|---|---|
| macOS | `~/Library/Fonts/FiraCode*.ttf`, `~/Library/Fonts/FiraCodeNerdFont*.ttf`, `/Library/Fonts/FiraCode*.ttf` |
| Linux | `~/.local/share/fonts/FiraCode*.ttf`, `~/.local/share/fonts/FiraCodeNerdFont*.ttf`, `/usr/share/fonts/truetype/firacode/FiraCode*.ttf` |

### Interaction with `choose-profile.sh`

Every profile in this repo (`velvet`, `catppuccin`, `minimal`, `p10k-velvet`) ships a `ghostty.conf` and `kitty.conf` that already include the correct Nerd Font line. `iterm-config.sh` installs a DynamicProfile that includes the correct font.

If Ghostty, Kitty, or iTerm2 font config is missing or wrong, the root cause is that `choose-profile.sh` was never run (or the config was manually edited). The fix for these terminals is to re-invoke `choose-profile.sh` or `iterm-config.sh`, not to do a targeted line insert — which would risk conflicting with profile-managed content.

VS Code font config is **not** managed by `choose-profile.sh`, so `font-config.sh` handles it directly.

### `detect_terminal_font_status` Function

```bash
detect_terminal_font_status TERMINAL [CONFIG_PATH_OVERRIDE]
```

- `TERMINAL` ∈ `{iterm2, ghostty, kitty, vscode}`
- `CONFIG_PATH_OVERRIDE` — optional path used in place of the default config file path. When provided, the terminal-binary/app-bundle installed check is **skipped** — the override implicitly means "assume installed, check this path." This allows tests to use mock config files without needing a real terminal binary.
- Echoes one of three strings: `not_installed`, `installed_not_configured`, `installed_configured`
- Side-effect free; never writes anything

This function is used by both `doctor.sh` (for reporting) and `font-config.sh` (for detect + fix flow). Tests source the script with `FONT_CONFIG_SOURCE_ONLY=1` and call this function directly with a mock path.

---

## Files

| File | Action | Responsibility |
|---|---|---|
| `doctor.sh` | Modify | Expand `section_font()` — add per-terminal config checks after existing file-presence check |
| `font-config.sh` | Create | TUI — detect, select terminals to fix, apply, verify |
| `test-font-config.sh` | Create | Test suite — syntax, detection logic with mock paths, arg parsing |
| `test.sh` | Modify | Add `syntax_check font-config.sh` + `test-font-config.sh` section (no macOS guard on the section itself — see Testing) |
| `HANDBOOK.md` | Modify | Add font troubleshooting section covering `font-config.sh` and `doctor.sh` font checks |

No new Homebrew dependencies. `fzf` and `font-fira-code-nerd-font` are already in `Brewfile`.

---

## `doctor.sh` Changes

`section_font()` gains a second pass after the existing file-presence check. The font-file check is updated to cover Linux paths (see Font File Paths table above).

If the font is not installed, terminal config checks are skipped (single warn message).

If the font is installed, each installed terminal is checked:

```
Nerd Font (FiraCode)
  [pass] FiraCode Nerd Font found
  iTerm2   [pass] configured (FiraCode in DynamicProfile Normal Font)
  Ghostty  [warn] installed but not configured — run ./choose-profile.sh or ./font-config.sh
  Kitty    [skip] not installed
  VS Code  [pass] terminal.integrated.fontFamily set
```

- Terminals not installed: silently skipped
- Terminals misconfigured: `warn` with hint to run `./font-config.sh`
- iTerm2 check runs only on macOS

---

## `font-config.sh` TUI

### Pattern

Follows `ssh-config.sh` / `dock-config.sh`:
- `set -euo pipefail`
- `run_cmd()` dry-run wrapper
- `FONT_CONFIG_SOURCE_ONLY=1` source guard placed **after all function definitions**, before the dispatch block
- Color helpers: `info`, `success`, `warn`, `error`, `header`
- `platform.sh` sourced for `DOTFILES_OS` detection
- Cross-platform: macOS + Linux. iTerm2 checks are conditional on `[ "$DOTFILES_OS" = "macos" ]`.
- No macOS-exit guard at the top — the script runs on both platforms

### Arg Parsing

```
./font-config.sh            # interactive TUI
./font-config.sh --status   # detection only, no changes
./font-config.sh --dry-run  # preview fixes, no writes
```

Unknown flags exit non-zero with usage message.

### TUI Flow

**Stage 1 — Detect**

Call `detect_terminal_font_status` for each terminal. Print a status table:

```
Terminal Font Configuration
  iTerm2   configured        FiraCode found in Normal Font
  Ghostty  NOT CONFIGURED    (installed, font-family not set)
  Kitty    not installed     (skipped)
  VS Code  NOT CONFIGURED    (terminal.integrated.fontFamily absent)
```

If all installed terminals are already configured, print a success message and exit 0 without showing a menu.

**Stage 2 — Select**

fzf multi-select of misconfigured terminals (pre-selected). Space to toggle, Enter to confirm. If fzf absent, all misconfigured terminals are selected automatically.

If no terminals are selected, print "nothing to do" and exit 0.

**Stage 3 — Apply**

For each selected terminal:

| Terminal | Fix action |
|---|---|
| iTerm2 | Print instruction to run `./iterm-config.sh` — do not auto-invoke (profile-managed) |
| Ghostty | Print instruction to run `./choose-profile.sh` — do not auto-invoke (profile-managed) |
| Kitty | Print instruction to run `./choose-profile.sh` — do not auto-invoke (profile-managed) |
| VS Code | Set `terminal.integrated.fontFamily` in `settings.json` via `python3` JSON merge (see VS Code section below) |

All VS Code writes go through `run_cmd` so `--dry-run` prints the action without executing.

For iTerm2/Ghostty/Kitty, `--dry-run` prints the instruction that would be shown.

**Stage 4 — Verify**

Re-run detection and print updated status table. If any terminal is still misconfigured, print residual warn with manual instructions.

### `--status` Mode

Runs Stage 1 only. Exits 0 regardless of state (diagnostic only).

### `--dry-run` Mode

Runs the full interactive TUI but writes nothing. When run non-interactively (no TTY), skips the fzf menu and previews actions for all misconfigured terminals.

---

## VS Code `settings.json` Handling

VS Code settings files are officially JSON but may contain `//` comments or trailing commas (JSONC). Python's `json` module rejects these.

**Strategy:**
1. Attempt to parse with `python3 json.load()`
2. If parsing fails (JSONC or other syntax error): `warn` and skip the VS Code fix — print the exact line the user should add manually. No data is modified.
3. If file absent: create a minimal file with just the font key
4. If file present and valid JSON: merge the font key, preserve all other keys

```bash
python3 -c "
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
" "$VSCODE_SETTINGS_PATH"
```

The script checks the output (`JSONC_OR_INVALID` vs `OK`) and warns accordingly. No `jq` dependency — `python3` only.

---

## Testing (`test-font-config.sh`)

`test-font-config.sh` has **no top-level OS guard** — Ghostty, Kitty, and VS Code tests use mock paths and are platform-independent. iTerm2-specific tests have an inline macOS guard (`[ "$(uname -s)" = "Darwin" ] || ...`).

`test.sh` includes `test-font-config.sh` without a macOS guard (unlike `test-ssh-config.sh` which is macOS-only).

### Tests

**Syntax check**
- `bash -n font-config.sh`

**`detect_terminal_font_status` with mock paths** (source `FONT_CONFIG_SOURCE_ONLY=1`):
- Ghostty: `CONFIG_PATH_OVERRIDE` points to absent file → `installed_not_configured` (override skips binary check, so absent config = not yet configured)
- Ghostty: `CONFIG_PATH_OVERRIDE` points to file without font line → `installed_not_configured`
- Ghostty: `CONFIG_PATH_OVERRIDE` points to file with `font-family = FiraCode Nerd Font` → `installed_configured`
- Kitty: `CONFIG_PATH_OVERRIDE` points to file with `font_family FiraCode Nerd Font` → `installed_configured`
- VS Code: `CONFIG_PATH_OVERRIDE` points to absent file → `installed_not_configured`
- VS Code: `CONFIG_PATH_OVERRIDE` points to `settings.json` without font key → `installed_not_configured`
- VS Code: `CONFIG_PATH_OVERRIDE` points to `settings.json` with `terminal.integrated.fontFamily` = FiraCode → `installed_configured`
- iTerm2 (inline macOS guard): `CONFIG_PATH_OVERRIDE` points to a mock DynamicProfiles directory — test creates a temp `.json` file with `"Normal Font": "FiraCodeNFM-Reg 13"` and asserts `installed_configured`

**Arg parsing**
- `--status` exits 0 (non-interactive stdin)
- `--dry-run` exits 0 (non-interactive stdin)
- `--badflag` exits non-zero

### Wire into `test.sh`

- `syntax_check font-config.sh` added after `syntax_check ssh-config.sh`
- `test-font-config.sh` section added after SSH Config section, **without** a macOS guard on the section itself

---

## Edge Cases

| Scenario | Behaviour |
|---|---|
| Font file not installed | Skip all terminal config checks; warn to install font first |
| Ghostty/Kitty binary installed but no config file | `installed_not_configured` (config file absent = not yet configured by `choose-profile.sh`) |
| iTerm2 DynamicProfiles dir absent | `installed_not_configured` (`/Applications/iTerm.app` exists but profile not installed) |
| VS Code `settings.json` has JSONC/comments | Warn and skip auto-fix; print the line to add manually |
| VS Code `settings.json` absent | Create minimal file with font key only |
| All installed terminals configured | Print success, exit 0 — no fzf menu shown |
| No terminals selected in fzf | Print "nothing to do", exit 0 |
| Running non-interactively without `--dry-run` | Print skip message, exit 0 |
| `--dry-run` non-interactive | Show what would be fixed for all misconfigured terminals, exit 0 |
