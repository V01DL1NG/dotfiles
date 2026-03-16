# Cross-Platform Linux Support — Design Spec

**Date:** 2026-03-16
**Status:** Approved
**Scope:** macOS dotfiles repo extended to support Linux desktop and Linux headless servers

---

## Overview

The dotfiles system currently targets macOS exclusively (Homebrew, `pbcopy`, `base64 -D`, iTerm2). This spec adds first-class Linux support via a shared detection library, updated install scripts, and a dedicated headless server bootstrap path.

Two Linux tiers are defined deliberately:

| Tier | Target | Entry point | Tools |
|---|---|---|---|
| **Linux desktop** | Ubuntu/Fedora/Arch with a display server | `bootstrap.sh` (updated) | Full profile, native PM |
| **Linux server** | Headless SSH, no GUI | `bootstrap-server.sh` (new) | Minimal profile + server role |

---

## Component 1 — `platform.sh` (shared detection library)

A new file sourced at the top of every install script with `. "$SCRIPT_DIR/platform.sh"`.

### Exported variables

| Variable | macOS | Linux desktop | Linux server | Unknown PM |
|---|---|---|---|---|
| `$DOTFILES_OS` | `macos` | `linux-desktop` | `linux-server` | `linux-server` |
| `$PKG_MGR` | `brew` | `apt` / `dnf` / `pacman` | same | `unknown` |
| `$PKG_INSTALL` | `brew install` | `sudo apt-get install -y` / `sudo dnf install -y` / `sudo pacman -S --noconfirm` | same | `false` |
| `$SED_INPLACE` | `sed -i ''` | `sed -i` | `sed -i` | `sed -i` |
| `$BASE64_DECODE` | `base64 -D` | `base64 -d` | `base64 -d` | `base64 -d` |
| `$DOTFILES_CLIPBOARD` | `pbcopy` | `xclip -sel clip` (fallback: `xsel --clipboard`) | _(empty — server)_ | _(empty)_ |

### Detection logic

```
OS detection:
  uname -s == Darwin  →  macos
  uname -s == Linux   →  check for display server
    $DISPLAY or $WAYLAND_DISPLAY set  →  linux-desktop
    otherwise                         →  linux-server

Package manager detection (Linux only, in order):
  command -v brew    →  brew
  command -v apt-get →  apt
  command -v dnf     →  dnf
  command -v pacman  →  pacman
  otherwise          →  unknown  (PKG_INSTALL="false")
```

`$PKG_INSTALL="false"` means calling it as a command fails loudly rather than silently doing nothing.

### `pkg()` helper — package name resolution

`platform.sh` exports a `pkg()` function that maps logical names to the correct package name for the current PM. If a package is unavailable for a given PM, `pkg()` returns an empty string. Call sites must guard against empty output:

```bash
# Pattern for optional packages:
_p="$(pkg lazygit)"
[ -n "$_p" ] && $PKG_INSTALL "$_p"

# Pattern for required packages (always have a name):
$PKG_INSTALL "$(pkg neovim)"
```

| Logical name | brew | apt | dnf | pacman | Notes |
|---|---|---|---|---|---|
| `delta` | `git-delta` | _(empty — see note)_ | `git-delta` | `git-delta` | apt: not in default repos on Ubuntu ≤22.04; install from GitHub releases or skip |
| `bat` | `bat` | `bat` | `bat` | `bat` | |
| `eza` | `eza` | `eza` | `eza` | `eza` | |
| `fd` | `fd` | `fd-find` | `fd-find` | `fd` | |
| `neovim` | `neovim` | `neovim` | `neovim` | `neovim` | |
| `lazygit` | `lazygit` | _(empty — PPA required)_ | `lazygit` | `lazygit` | apt: skipped; user can add the PPA manually |
| `fzf` | `fzf` | `fzf` | `fzf` | `fzf` | |
| `zoxide` | `zoxide` | `zoxide` | `zoxide` | `zoxide` | |
| `atuin` | `atuin` | _(empty)_ | _(empty)_ | `atuin` | apt/dnf: install via `curl | sh` from atuin's own installer, or skip |

`delta` on apt: `git-config.sh` treats it as optional — falls back to plain `git diff` if `pkg delta` returns empty. A warning is printed.

---

## Component 2 — Updated install scripts

Each script gains two changes:
1. `. "$SCRIPT_DIR/platform.sh"` at the top
2. `brew install` replaced with `$PKG_INSTALL "$(pkg <name>)"` (with optional-package guard where needed)

### Scripts requiring changes

| Script | Change |
|---|---|
| `tools-config.sh` | `$PKG_INSTALL` + `pkg()` for fzf, bat, eza, fd, zoxide; optional guard for atuin, lazygit |
| `git-config.sh` | `$PKG_INSTALL git`; optional guard for delta |
| `tmux-config.sh` | `$PKG_INSTALL tmux`; guard `nowplaying-cli` install as macOS-only (skip on Linux) |
| `nvim-config.sh` | `$PKG_INSTALL neovim` |
| `eza-config.sh` | `$PKG_INSTALL "$(pkg eza)"`; fd name fix via `pkg fd` |
| `setup.sh` | Guard: skip oh-my-posh install on `linux-server`; allow on `linux-desktop` |
| `iterm-config.sh` | Exit early (success, not error) when `$DOTFILES_OS != macos` |
| `install-all.sh` | Skip `iterm-config.sh` on Linux; skip `setup.sh` on `linux-server` |
| `choose-profile.sh` | Replace `brew install oh-my-posh` / `brew install powerlevel10k` with `$PKG_INSTALL`-aware calls; these are prerequisites for `bootstrap-server.sh` step 5 |
| `profile.sh` | Replace `base64 -D` with `$BASE64_DECODE`; replace `brew install` in `_ensure_tool()` with `$PKG_INSTALL` |
| `zshrc-config.sh` | Source `platform.sh`; no brew calls but needs platform-aware clipboard |
| `ssh-config.sh` | No changes needed — platform-neutral |

### zshrc clipboard portability

The `copy` function in all profile `zshrc` files changes to:

```zsh
# Portable clipboard copy
if [[ -n "$DOTFILES_CLIPBOARD" ]]; then
  copy() { $DOTFILES_CLIPBOARD }
fi
```

`$DOTFILES_CLIPBOARD` is set by `platform.sh` (exported into the shell environment) to `pbcopy` on macOS, `xclip -sel clip` or `xsel --clipboard` on Linux desktop (whichever is installed), and empty on server. The function is only defined when a clipboard tool is available.

---

## Component 3 — `bootstrap-server.sh`

A dedicated curl-installable entry point for headless Linux servers.

```bash
curl -fsSL https://raw.githubusercontent.com/V01DL1NG/dotfiles/master/bootstrap-server.sh | bash
```

### Flow

```
1. OS check
   - uname != Linux  →  hard exit: "This script is for Linux servers. For macOS use bootstrap.sh"

2. Inline platform detection (no repo yet — PM detection only)
   - Detects $PKG_MGR

3. Install base tools (if PKG_MGR != unknown)
   Required: git zsh curl fzf bat eza zoxide
   Optional (best-effort): atuin delta lazygit
   - Package names are resolved via an inline mapping table embedded in bootstrap-server.sh
     (platform.sh is not available yet — repo not cloned until step 4)
   - Optional packages with no entry in the inline map for the current PM are skipped silently
   - If PKG_MGR = unknown: skip installs entirely, record list of missing tools

4. Clone repo
   git clone https://github.com/V01DL1NG/dotfiles ~/dotfiles
   (prerequisite: git must be available — hard exit if missing)

5. Install minimal profile
   ~/dotfiles/choose-profile.sh minimal   (non-interactive)
   (choose-profile.sh is now platform-aware per Component 2)

6. Apply server role
   ~/dotfiles/role.sh apply server

7. Set zsh as default shell
   chsh -s $(which zsh)
   - Skip silently if zsh is already the login shell
   - Skip with warning if zsh is not installed (unknown PM path)

8. Print summary
   - If PKG_MGR = unknown: warn with list of 7 tools to install manually
   - Next steps: reconnect SSH to activate new shell, source ~/.zshrc
```

### Error handling

| Condition | Behaviour |
|---|---|
| Non-Linux OS | Hard exit with message pointing to `bootstrap.sh` |
| Unknown package manager | Skip tool installs, continue with clone + profile + role, print warning |
| `git` missing on unknown PM | Hard exit: git is required to clone the repo |
| `zsh` missing on unknown PM | Continue without `chsh`; print manual install instructions |

---

## Component 4 — `doctor.sh` Linux section

`doctor.sh` sources `platform.sh` and branches on `$DOTFILES_OS`:

- **Skip on Linux server:** FiraCode font check, iTerm2 profile check, oh-my-posh check
- **Skip on Linux (any):** Homebrew check
- **Add on Linux desktop:** check for `xclip` or `xsel` (clipboard); warn if neither present
- **Add on Linux (any):** check that `zsh` is the login shell; check `$PKG_MGR` is not `unknown`
- **Server-specific:** flag if `$DISPLAY` is unexpectedly set (possible misconfiguration)

---

## Out of scope

- Windows / WSL support
- Homebrew on Linux (Linuxbrew) — not supported; native PM only
- GUI application theming on Linux (no GNOME/KDE integration)
- Automatic font installation on Linux (user responsibility)
- `delta` on Ubuntu ≤22.04 apt — marked optional; user installs from GitHub releases if desired

---

## File changes summary

| File | Type | Notes |
|---|---|---|
| `platform.sh` | **New** | Core detection library + `pkg()` helper |
| `bootstrap-server.sh` | **New** | Headless Linux entry point |
| `tools-config.sh` | Modified | `$PKG_INSTALL` + `pkg()` + optional guards |
| `git-config.sh` | Modified | `$PKG_INSTALL`; delta optional on apt |
| `tmux-config.sh` | Modified | `$PKG_INSTALL tmux`; guard `nowplaying-cli` as macOS-only |
| `nvim-config.sh` | Modified | `$PKG_INSTALL neovim` |
| `eza-config.sh` | Modified | `$PKG_INSTALL "$(pkg eza)"`; fd name fix |
| `setup.sh` | Modified | macOS/desktop guard for oh-my-posh |
| `iterm-config.sh` | Modified | Early exit (success) on non-macOS |
| `install-all.sh` | Modified | Skip macOS-only scripts on Linux |
| `choose-profile.sh` | Modified | Replace hardcoded `brew install` with `$PKG_INSTALL` |
| `profile.sh` | Modified | `$BASE64_DECODE`; `$PKG_INSTALL` in `_ensure_tool()` |
| `zshrc-config.sh` | Modified | Source `platform.sh` |
| `doctor.sh` | Modified | Linux-aware checks |
| `profiles/*/zshrc` | Modified | Portable `copy` function via `$DOTFILES_CLIPBOARD` |
| `README.md` | Modified | Linux install instructions |
| `ssh-config.sh` | No change | Platform-neutral — no modifications needed |
