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
| `$CLIPBOARD_CMD` | `pbcopy` | `xclip -sel clip` (fallback: `xsel --clipboard`) | _(none — server)_ | _(none)_ |

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

`$PKG_INSTALL="false"` means calling it as a command will fail loudly rather than silently doing nothing.

---

## Component 2 — Updated install scripts

Each script gains two changes:
1. `. "$SCRIPT_DIR/platform.sh"` at the top
2. `brew install` replaced with `$PKG_INSTALL <package>`

### Package name differences

Some packages have different names across package managers. A lookup is handled inside `platform.sh` via a `pkg()` helper function:

```bash
pkg <logical-name>
# e.g. pkg delta  →  "git-delta" on apt, "delta" elsewhere
```

| Logical name | brew | apt | dnf | pacman |
|---|---|---|---|---|
| `delta` | `git-delta` | `git-delta` | `git-delta` | `git-delta` |
| `bat` | `bat` | `bat` | `bat` | `bat` |
| `eza` | `eza` | `eza` | `eza` | `eza` |
| `fd` | `fd` | `fd-find` | `fd-find` | `fd` |
| `neovim` | `neovim` | `neovim` | `neovim` | `neovim` |
| `lazygit` | `lazygit` | _(PPA required — skip on unknown)_ | `lazygit` | `lazygit` |

Scripts that require changes:

| Script | Change |
|---|---|
| `tools-config.sh` | `$PKG_INSTALL $(pkg fzf) $(pkg bat) $(pkg eza)` etc. |
| `git-config.sh` | `$PKG_INSTALL git $(pkg delta)` |
| `tmux-config.sh` | `$PKG_INSTALL tmux` |
| `nvim-config.sh` | `$PKG_INSTALL neovim` |
| `setup.sh` | Guard: skip oh-my-posh install when `$DOTFILES_OS = linux-server` |
| `iterm-config.sh` | Guard: exit early when `$DOTFILES_OS != macos` |
| `install-all.sh` | Skip `iterm-config.sh` and `setup.sh` when `$DOTFILES_OS = linux-server` |

### zshrc clipboard portability

The `copy` function in all profile `zshrc` files changes from:
```zsh
copy() { pbcopy }
```
to a platform-aware version that sources `$CLIPBOARD_CMD` at shell startup. On Linux desktop, `xclip` or `xsel` is used if present; on server the function is omitted.

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

2. Source platform.sh (inline copy — no repo yet)
   - Detects $PKG_MGR

3. Install base tools (if PKG_MGR != unknown)
   Required: git zsh curl fzf bat eza zoxide
   Optional (best-effort): atuin delta lazygit
   - If PKG_MGR = unknown: skip installs entirely, record list of missing tools

4. Clone repo
   git clone https://github.com/V01DL1NG/dotfiles ~/dotfiles

5. Install minimal profile
   ~/dotfiles/choose-profile.sh minimal   (non-interactive)

6. Apply server role
   ~/dotfiles/role.sh apply server

7. Set zsh as default shell
   chsh -s $(which zsh)   (prompts if not already default)

8. Print summary
   - If PKG_MGR = unknown: warn with list of 7 tools to install manually
   - Next steps: reconnect SSH, source ~/.zshrc
```

### Error handling

| Condition | Behaviour |
|---|---|
| Non-Linux OS | Hard exit with clear message pointing to `bootstrap.sh` |
| Unknown package manager | Skip tool installs, continue with clone + profile + role, print warning |
| `git` missing on unknown PM | Hard exit: git is required to clone the repo |
| `zsh` missing on unknown PM | Continue without `chsh`; print manual install instructions |

---

## Component 4 — `doctor.sh` Linux section

`doctor.sh` already runs platform-neutral checks. It gains a new Linux-aware section:

- **Skip on Linux:** FiraCode font check, iTerm2 profile check, oh-my-posh check (unless desktop)
- **Add on Linux:** check for `xclip`/`xsel` (desktop), check that `zsh` is the login shell, check `$PKG_MGR` is known
- **Server-specific:** flag if `$DISPLAY` is unexpectedly set (possible misconfiguration)

---

## Out of scope

- Windows / WSL support
- Homebrew on Linux (Linuxbrew) — not supported; native PM only
- GUI application theming on Linux (no plans for GNOME/KDE theme integration)
- Automatic font installation on Linux (user responsibility)

---

## File changes summary

| File | Type | Notes |
|---|---|---|
| `platform.sh` | **New** | Core detection library |
| `bootstrap-server.sh` | **New** | Headless Linux entry point |
| `tools-config.sh` | Modified | `$PKG_INSTALL` + `pkg()` helper |
| `git-config.sh` | Modified | `$PKG_INSTALL` + delta name fix |
| `tmux-config.sh` | Modified | `$PKG_INSTALL` |
| `nvim-config.sh` | Modified | `$PKG_INSTALL` |
| `setup.sh` | Modified | macOS/desktop guard |
| `iterm-config.sh` | Modified | macOS-only guard |
| `install-all.sh` | Modified | Skip macOS-only scripts on Linux |
| `doctor.sh` | Modified | Linux-aware checks |
| `profiles/*/zshrc` | Modified | Portable `copy` function |
| `README.md` | Modified | Linux install instructions |
