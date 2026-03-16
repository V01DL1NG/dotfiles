# Cross-Platform Linux Support — Implementation Plan

> **For agentic workers:** REQUIRED: Use superpowers:subagent-driven-development (if subagents available) or superpowers:executing-plans to implement this plan. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add Linux desktop and Linux server support to the macOS dotfiles system via a shared `platform.sh` detection library, updated install scripts, and a new `bootstrap-server.sh` entry point.

**Architecture:** A single `platform.sh` library exports `$DOTFILES_OS`, `$PKG_MGR`, `$PKG_INSTALL`, portability variables, and a `pkg()` name-mapping helper. All install scripts source it and replace hardcoded `brew install` calls. A new `bootstrap-server.sh` handles headless Linux with an inline package table (repo not yet available at install time).

**Tech Stack:** Bash, native Linux package managers (apt/dnf/pacman), Homebrew (macOS)

**Spec:** `docs/superpowers/specs/2026-03-16-cross-platform-linux-design.md`

---

## Chunk 1: `platform.sh` — core detection library

### Files
- Create: `platform.sh`
- Create: `test-platform.sh`

---

### Task 1: Write `test-platform.sh` with failing tests

- [ ] **Step 1: Create `test-platform.sh`**

```bash
#!/usr/bin/env bash
# test-platform.sh — unit tests for platform.sh detection library
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PASS=0; FAIL=0

pass()    { echo "  ✓ $1"; PASS=$((PASS + 1)); }
fail()    { echo "  ✗ $1"; FAIL=$((FAIL + 1)); }
section() { echo ""; echo "── $1"; }

# Source platform.sh with forced overrides, capture key vars as KEY=value pairs
source_platform() {
  local force_os="${1:-}" force_pm="${2:-}"
  (
    export _DOTFILES_FORCE_OS="$force_os"
    export _DOTFILES_FORCE_PKG_MGR="$force_pm"
    # shellcheck source=platform.sh
    . "$SCRIPT_DIR/platform.sh"
    printf 'OS=%s PKG_MGR=%s\n' "$DOTFILES_OS" "$PKG_MGR"
    printf 'PKG_INSTALL=%s\n' "$PKG_INSTALL"
    printf 'SED=%s\n' "$SED_INPLACE"
    printf 'B64=%s\n' "$BASE64_DECODE"
  )
}

check() {
  local label="$1" actual="$2" expected="$3"
  if [ "$actual" = "$expected" ]; then
    pass "$label"
  else
    fail "$label: expected '$expected', got '$actual'"
  fi
}

# Source platform.sh in a subshell and call pkg() with a given PM
pkg_result() {
  local force_pm="$1" name="$2"
  (
    export _DOTFILES_FORCE_OS="linux-server"
    export _DOTFILES_FORCE_PKG_MGR="$force_pm"
    . "$SCRIPT_DIR/platform.sh"
    pkg "$name"
  )
}

# ── OS detection ──────────────────────────────────────────────────────────────
section "OS + PKG_MGR mapping"

out="$(source_platform macos brew)"
check "macos → DOTFILES_OS"  "$(echo "$out" | grep '^OS=' | cut -d= -f2 | awk '{print $1}')" "macos"
check "macos → PKG_MGR"      "$(echo "$out" | grep '^OS=' | grep -o 'PKG_MGR=[^ ]*' | cut -d= -f2)" "brew"
check "macos → PKG_INSTALL"  "$(echo "$out" | grep '^PKG_INSTALL=' | cut -d= -f2-)" "brew install"
check "macos → SED_INPLACE"  "$(echo "$out" | grep '^SED=' | cut -d= -f2-)" "sed -i ''"
check "macos → BASE64_DECODE" "$(echo "$out" | grep '^B64=' | cut -d= -f2-)" "base64 -D"

out="$(source_platform linux-server apt)"
check "linux → SED_INPLACE"   "$(echo "$out" | grep '^SED=' | cut -d= -f2-)" "sed -i"
check "linux → BASE64_DECODE" "$(echo "$out" | grep '^B64=' | cut -d= -f2-)" "base64 -d"

out="$(source_platform linux-desktop apt)"
check "linux-desktop → DOTFILES_OS" "$(echo "$out" | grep '^OS=' | cut -d= -f2 | awk '{print $1}')" "linux-desktop"
check "linux-desktop/apt → PKG_INSTALL" \
  "$(echo "$out" | grep '^PKG_INSTALL=' | cut -d= -f2-)" "sudo apt-get install -y"

out="$(source_platform linux-server dnf)"
check "linux-server → DOTFILES_OS" "$(echo "$out" | grep '^OS=' | cut -d= -f2 | awk '{print $1}')" "linux-server"
check "linux-server/dnf → PKG_INSTALL" \
  "$(echo "$out" | grep '^PKG_INSTALL=' | cut -d= -f2-)" "sudo dnf install -y"

out="$(source_platform linux-server pacman)"
check "linux-server/pacman → PKG_INSTALL" \
  "$(echo "$out" | grep '^PKG_INSTALL=' | cut -d= -f2-)" "sudo pacman -S --noconfirm"

out="$(source_platform linux-server unknown)"
check "unknown PM → PKG_INSTALL=false" \
  "$(echo "$out" | grep '^PKG_INSTALL=' | cut -d= -f2-)" "false"

# ── pkg() helper ──────────────────────────────────────────────────────────────
section "pkg() — fd name mapping"
check "brew fd"    "$(pkg_result brew   fd)" "fd"
check "apt fd"     "$(pkg_result apt    fd)" "fd-find"
check "dnf fd"     "$(pkg_result dnf    fd)" "fd-find"
check "pacman fd"  "$(pkg_result pacman fd)" "fd"

section "pkg() — delta (optional on apt)"
check "brew delta"   "$(pkg_result brew   delta)" "git-delta"
check "apt delta"    "$(pkg_result apt    delta)" ""
check "dnf delta"    "$(pkg_result dnf    delta)" "git-delta"
check "pacman delta" "$(pkg_result pacman delta)" "git-delta"

section "pkg() — lazygit (optional on apt)"
check "brew lazygit"   "$(pkg_result brew   lazygit)" "lazygit"
check "apt lazygit"    "$(pkg_result apt    lazygit)" ""
check "dnf lazygit"    "$(pkg_result dnf    lazygit)" "lazygit"
check "pacman lazygit" "$(pkg_result pacman lazygit)" "lazygit"

section "pkg() — atuin (optional on apt/dnf)"
check "brew atuin"   "$(pkg_result brew   atuin)" "atuin"
check "apt atuin"    "$(pkg_result apt    atuin)" ""
check "dnf atuin"    "$(pkg_result dnf    atuin)" ""
check "pacman atuin" "$(pkg_result pacman atuin)" "atuin"

section "pkg() — neovim (available everywhere)"
check "brew neovim"   "$(pkg_result brew   neovim)" "neovim"
check "apt neovim"    "$(pkg_result apt    neovim)" "neovim"
check "dnf neovim"    "$(pkg_result dnf    neovim)" "neovim"
check "pacman neovim" "$(pkg_result pacman neovim)" "neovim"

# ── Summary ───────────────────────────────────────────────────────────────────
echo ""
echo "────────────────────────────────"
printf "  passed: %d  failed: %d\n" "$PASS" "$FAIL"
echo "────────────────────────────────"
echo ""
[ "$FAIL" -eq 0 ]
```

- [ ] **Step 2: Run tests — verify they fail**

```bash
chmod +x test-platform.sh && bash test-platform.sh
```

Expected: error — `platform.sh: No such file or directory`

---

### Task 2: Implement `platform.sh`

- [ ] **Step 3: Create `platform.sh`**

```bash
#!/usr/bin/env bash
# ============================================================================
# platform.sh — shared platform detection library
#
# Source this at the top of every install script:
#   SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
#   . "$SCRIPT_DIR/platform.sh"
#
# Exports: DOTFILES_OS, PKG_MGR, PKG_INSTALL, SED_INPLACE, BASE64_DECODE,
#          DOTFILES_CLIPBOARD, and the pkg() function.
#
# Test overrides (for use in test-platform.sh):
#   _DOTFILES_FORCE_OS      — force DOTFILES_OS to a specific value
#   _DOTFILES_FORCE_PKG_MGR — force PKG_MGR to a specific value
# ============================================================================

# ── OS detection ──────────────────────────────────────────────────────────────
if [ -n "${_DOTFILES_FORCE_OS:-}" ]; then
  DOTFILES_OS="$_DOTFILES_FORCE_OS"
else
  case "$(uname -s)" in
    Darwin) DOTFILES_OS="macos" ;;
    Linux)
      if [ -n "${DISPLAY:-}" ] || [ -n "${WAYLAND_DISPLAY:-}" ]; then
        DOTFILES_OS="linux-desktop"
      else
        DOTFILES_OS="linux-server"
      fi
      ;;
    *) DOTFILES_OS="unknown" ;;
  esac
fi

# ── Package manager detection ─────────────────────────────────────────────────
if [ -n "${_DOTFILES_FORCE_PKG_MGR:-}" ]; then
  PKG_MGR="$_DOTFILES_FORCE_PKG_MGR"
elif [ "$DOTFILES_OS" = "macos" ]; then
  PKG_MGR="brew"
else
  if   command -v brew    >/dev/null 2>&1; then PKG_MGR="brew"
  elif command -v apt-get >/dev/null 2>&1; then PKG_MGR="apt"
  elif command -v dnf     >/dev/null 2>&1; then PKG_MGR="dnf"
  elif command -v pacman  >/dev/null 2>&1; then PKG_MGR="pacman"
  else                                          PKG_MGR="unknown"
  fi
fi

# ── Install command ───────────────────────────────────────────────────────────
case "$PKG_MGR" in
  brew)   PKG_INSTALL="brew install" ;;
  apt)    PKG_INSTALL="sudo apt-get install -y" ;;
  dnf)    PKG_INSTALL="sudo dnf install -y" ;;
  pacman) PKG_INSTALL="sudo pacman -S --noconfirm" ;;
  *)      PKG_INSTALL="false" ;;
esac

# ── Portability ───────────────────────────────────────────────────────────────
# Branch on $DOTFILES_OS (not uname) so force-override works in tests
case "$DOTFILES_OS" in
  macos)  SED_INPLACE="sed -i ''"; BASE64_DECODE="base64 -D" ;;
  *)      SED_INPLACE="sed -i";    BASE64_DECODE="base64 -d" ;;
esac

# Clipboard — pbcopy on macOS, xclip/xsel on Linux desktop, empty on server
DOTFILES_CLIPBOARD=""
if [ "$DOTFILES_OS" = "macos" ]; then
  DOTFILES_CLIPBOARD="pbcopy"
elif [ "$DOTFILES_OS" = "linux-desktop" ]; then
  if   command -v xclip >/dev/null 2>&1; then DOTFILES_CLIPBOARD="xclip -sel clip"
  elif command -v xsel  >/dev/null 2>&1; then DOTFILES_CLIPBOARD="xsel --clipboard"
  fi
fi

export DOTFILES_OS PKG_MGR PKG_INSTALL SED_INPLACE BASE64_DECODE DOTFILES_CLIPBOARD

# ── pkg() — resolve logical package name to PM-specific package name ──────────
# Returns empty string if the package is unavailable for the current PM.
# Callers must guard optional packages: _p="$(pkg foo)"; [ -n "$_p" ] && $PKG_INSTALL "$_p"
pkg() {
  local name="$1"
  case "$PKG_MGR" in
    brew)
      case "$name" in
        delta)    echo "git-delta" ;;
        fd)       echo "fd" ;;
        lua-ls)   echo "lua-language-server" ;;
        bat|eza|fzf|lazygit|neovim|zoxide|atuin|tmux|git) echo "$name" ;;
        *)        echo "$name" ;;
      esac ;;
    apt)
      case "$name" in
        fd)       echo "fd-find" ;;
        delta)    echo "" ;;   # not in default repos on Ubuntu ≤22.04
        lazygit)  echo "" ;;   # PPA required
        atuin)    echo "" ;;   # use curl installer
        lua-ls)   echo "" ;;   # not in default repos
        bat|eza|fzf|neovim|zoxide|tmux|git) echo "$name" ;;
        *)        echo "$name" ;;
      esac ;;
    dnf)
      case "$name" in
        fd)       echo "fd-find" ;;
        delta)    echo "git-delta" ;;
        atuin)    echo "" ;;   # use curl installer
        lua-ls)   echo "" ;;
        bat|eza|fzf|lazygit|neovim|zoxide|tmux|git) echo "$name" ;;
        *)        echo "$name" ;;
      esac ;;
    pacman)
      case "$name" in
        delta)    echo "git-delta" ;;
        lua-ls)   echo "" ;;
        bat|eza|fd|fzf|lazygit|neovim|zoxide|atuin|tmux|git) echo "$name" ;;
        *)        echo "$name" ;;
      esac ;;
    *)
      echo "" ;;
  esac
}
```

- [ ] **Step 4: Run tests — verify they pass**

```bash
bash test-platform.sh
```

Expected: all pass, `failed: 0`

- [ ] **Step 5: Syntax-check `platform.sh`**

```bash
bash -n platform.sh && echo "OK"
```

Expected: `OK`

- [ ] **Step 6: Commit**

```bash
git add platform.sh test-platform.sh
git commit -m "feat: add platform.sh detection library and tests"
```

---

## Chunk 2: `profile.sh` + `choose-profile.sh` + `iterm-config.sh` + `setup.sh`

### Files
- Modify: `profile.sh` (lines ~150-205 — `_b64d()` and `_ensure_tool()` in the container heredoc)
- Modify: `choose-profile.sh` (lines ~71-79 and ~109-119 — brew install guards)
- Modify: `iterm-config.sh` (line 8-11 — macOS guard)
- Modify: `setup.sh` (lines 7-14 — oh-my-posh install guard)

---

### Task 3: Update `profile.sh` — source `platform.sh`, portable `$BASE64_DECODE`, `$PKG_INSTALL` in containers

- [ ] **Step 1: Write test — verify syntax before edits**

```bash
bash -n profile.sh && echo "OK"
```

Expected: `OK` (baseline passes)

- [ ] **Step 2: Add `platform.sh` source to `profile.sh`**

After the `SCRIPT_DIR` definition near the top of `profile.sh`, add:
```bash
# shellcheck source=platform.sh
. "$SCRIPT_DIR/platform.sh"
```

- [ ] **Step 3: Replace `base64 < "$1"` in `b64_file()` — already cross-platform (no change needed)**

The `b64_file()` helper uses `base64 < "$1" | tr -d '\n'` — this is the same on macOS and Linux (the `-D`/`-d` difference is only for decoding). No change needed here.

- [ ] **Step 4: Replace `base64 -D` usage in the container's `_b64d()` function inside the `____INSTALL_LOGIC` heredoc**

The heredoc already contains its own `_b64d()` that handles both macOS and Linux via `uname -s` — this is correct and intentional (the container is self-contained and cannot source `platform.sh`). No change needed here either.

- [ ] **Step 5: Update `_ensure_tool()` inside the `____INSTALL_LOGIC` heredoc in `profile.sh`**

Find this block inside the heredoc (around line 176):
```bash
    powerlevel10k)
      if ! { [ -f /opt/homebrew/share/powerlevel10k/powerlevel10k.zsh-theme ] || \
             [ -f /usr/share/powerlevel10k/powerlevel10k.zsh-theme ]; }; then
        _warn "powerlevel10k not installed"
        if command -v brew >/dev/null 2>&1; then
          _info "Installing powerlevel10k via Homebrew..."
          brew install powerlevel10k
        else
          _error "Install powerlevel10k first: brew install powerlevel10k"
          return 1
        fi
      fi
      ;;
    oh-my-posh)
      if ! command -v oh-my-posh >/dev/null 2>&1; then
        _warn "oh-my-posh not installed"
        if command -v brew >/dev/null 2>&1; then
          _info "Installing oh-my-posh via Homebrew..."
          brew install jandedobbeleer/oh-my-posh/oh-my-posh
        else
          _error "Install oh-my-posh first: brew install jandedobbeleer/oh-my-posh/oh-my-posh"
          return 1
        fi
      fi
      ;;
```

Replace with:
```bash
    powerlevel10k)
      if ! { [ -f /opt/homebrew/share/powerlevel10k/powerlevel10k.zsh-theme ] || \
             [ -f /usr/share/powerlevel10k/powerlevel10k.zsh-theme ]; }; then
        _warn "powerlevel10k not installed"
        if command -v brew >/dev/null 2>&1; then
          _info "Installing powerlevel10k via Homebrew..."
          brew install powerlevel10k
        elif command -v apt-get >/dev/null 2>&1; then
          _error "powerlevel10k is not in apt repos — install manually or use the minimal profile"
          return 1
        else
          _error "Install powerlevel10k first: brew install powerlevel10k"
          return 1
        fi
      fi
      ;;
    oh-my-posh)
      if ! command -v oh-my-posh >/dev/null 2>&1; then
        _warn "oh-my-posh not installed"
        if command -v brew >/dev/null 2>&1; then
          _info "Installing oh-my-posh via Homebrew..."
          brew install jandedobbeleer/oh-my-posh/oh-my-posh
        elif command -v apt-get >/dev/null 2>&1 || command -v dnf >/dev/null 2>&1; then
          _info "Installing oh-my-posh via official script..."
          curl -s https://ohmyposh.dev/install.sh | bash -s
        else
          _error "Install oh-my-posh first: https://ohmyposh.dev/docs/installation"
          return 1
        fi
      fi
      ;;
```

- [ ] **Step 3: Verify syntax**

```bash
bash -n profile.sh && echo "OK"
```

Expected: `OK`

- [ ] **Step 4: Commit**

```bash
git add profile.sh
git commit -m "fix: profile.sh containers support Linux tool installation"
```

---

### Task 4: Update `choose-profile.sh` — replace hardcoded `brew install`

- [ ] **Step 1: Verify baseline syntax**

```bash
bash -n choose-profile.sh && echo "OK"
```

- [ ] **Step 2: Add platform.sh source at the top of `choose-profile.sh`**

After line 13 (`set -euo pipefail`), add:
```bash
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
. "$SCRIPT_DIR/platform.sh"
```

(Note: `SCRIPT_DIR` is already set on line 15 — move the source line after it, not before.)

Actually, find the existing `SCRIPT_DIR` line and add the source after it:

Find:
```bash
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROFILES_DIR="$SCRIPT_DIR/profiles"
```

Replace with:
```bash
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROFILES_DIR="$SCRIPT_DIR/profiles"
# shellcheck source=platform.sh
. "$SCRIPT_DIR/platform.sh"
```

- [ ] **Step 3: Update oh-my-posh install block in `install_velvet()`**

Find (around line 71):
```bash
  if ! command -v oh-my-posh >/dev/null 2>&1; then
    warn "oh-my-posh not found"
    if command -v brew >/dev/null 2>&1; then
      info "Installing oh-my-posh via Homebrew..."
      brew install jandedobbeleer/oh-my-posh/oh-my-posh
    else
      error "Homebrew not found — install oh-my-posh manually: https://ohmyposh.dev/docs/installation/macos"
      exit 1
    fi
  fi
```

Replace with:
```bash
  if ! command -v oh-my-posh >/dev/null 2>&1; then
    warn "oh-my-posh not found"
    case "$PKG_MGR" in
      brew)
        info "Installing oh-my-posh via Homebrew..."
        brew install jandedobbeleer/oh-my-posh/oh-my-posh
        ;;
      apt|dnf)
        info "Installing oh-my-posh via official script..."
        curl -s https://ohmyposh.dev/install.sh | bash -s
        ;;
      *)
        error "Cannot install oh-my-posh automatically — install manually: https://ohmyposh.dev/docs/installation"
        exit 1
        ;;
    esac
  fi
```

- [ ] **Step 4: Update powerlevel10k install block in `install_p10k_velvet()` and `install_catppuccin()`**

Both functions contain identical blocks. Find:
```bash
  if ! [ -f /opt/homebrew/share/powerlevel10k/powerlevel10k.zsh-theme ] && \
     ! [ -f /usr/share/powerlevel10k/powerlevel10k.zsh-theme ]; then
    warn "powerlevel10k not found"
    if command -v brew >/dev/null 2>&1; then
      info "Installing powerlevel10k via Homebrew..."
      brew install powerlevel10k
    else
      error "Homebrew not found — install powerlevel10k manually: brew install powerlevel10k"
      exit 1
    fi
  fi
```

Replace (in both functions) with:
```bash
  if ! [ -f /opt/homebrew/share/powerlevel10k/powerlevel10k.zsh-theme ] && \
     ! [ -f /usr/share/powerlevel10k/powerlevel10k.zsh-theme ]; then
    warn "powerlevel10k not found"
    case "$PKG_MGR" in
      brew)
        info "Installing powerlevel10k via Homebrew..."
        brew install powerlevel10k
        ;;
      *)
        error "powerlevel10k requires Homebrew on Linux — consider the minimal profile for servers"
        error "Install Homebrew: https://brew.sh, then: brew install powerlevel10k"
        exit 1
        ;;
    esac
  fi
```

- [ ] **Step 5: Verify syntax**

```bash
bash -n choose-profile.sh && echo "OK"
```

Expected: `OK`

- [ ] **Step 6: Commit**

```bash
git add choose-profile.sh
git commit -m "fix: choose-profile.sh uses platform.sh for tool installation"
```

---

### Task 5: Update `iterm-config.sh` — macOS-only guard

- [ ] **Step 1: Add early exit for non-macOS**

In `iterm-config.sh`, after `set -euo pipefail`, add:

```bash
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
. "$SCRIPT_DIR/platform.sh"

if [ "$DOTFILES_OS" != "macos" ]; then
  echo "iTerm2 is macOS-only — skipping on $DOTFILES_OS"
  exit 0
fi
```

- [ ] **Step 2: Verify syntax**

```bash
bash -n iterm-config.sh && echo "OK"
```

- [ ] **Step 3: Commit**

```bash
git add iterm-config.sh
git commit -m "fix: iterm-config.sh skips gracefully on non-macOS"
```

---

### Task 6: Update `setup.sh` — oh-my-posh guard for Linux server

- [ ] **Step 1: Add platform.sh source and guard**

In `setup.sh`, after the existing `SCRIPT_DIR` line, add:
```bash
. "$SCRIPT_DIR/platform.sh"

if [ "$DOTFILES_OS" = "linux-server" ]; then
  echo "Skipping oh-my-posh on Linux server — use the minimal profile"
  exit 0
fi
```

Then replace the brew-only install block:
```bash
if ! command -v oh-my-posh >/dev/null 2>&1; then
  if command -v brew >/dev/null 2>&1; then
    echo "Installing oh-my-posh via Homebrew..."
    brew install jandedobbeleer/oh-my-posh/oh-my-posh || brew install oh-my-posh
  else
    echo "Homebrew not found. Please install Homebrew or oh-my-posh manually: https://ohmyposh.dev/docs/installation"
  fi
```

With:
```bash
if ! command -v oh-my-posh >/dev/null 2>&1; then
  case "$PKG_MGR" in
    brew)
      echo "Installing oh-my-posh via Homebrew..."
      brew install jandedobbeleer/oh-my-posh/oh-my-posh || brew install oh-my-posh
      ;;
    apt|dnf)
      echo "Installing oh-my-posh via official script..."
      curl -s https://ohmyposh.dev/install.sh | bash -s
      ;;
    *)
      echo "Cannot auto-install oh-my-posh — see: https://ohmyposh.dev/docs/installation"
      ;;
  esac
```

- [ ] **Step 2: Verify syntax**

```bash
bash -n setup.sh && echo "OK"
```

- [ ] **Step 3: Commit**

```bash
git add setup.sh
git commit -m "fix: setup.sh supports Linux desktop oh-my-posh install"
```

---

## Chunk 3: Install scripts — `tools-config.sh`, `git-config.sh`, `tmux-config.sh`, `nvim-config.sh`, `eza-config.sh`

### Files
- Modify: `tools-config.sh`
- Modify: `git-config.sh`
- Modify: `tmux-config.sh`
- Modify: `nvim-config.sh`
- Modify: `eza-config.sh`

---

### Task 7: Update `tools-config.sh`

- [ ] **Step 1: Rewrite `tools-config.sh`**

Replace the entire file content with:

```bash
#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
. "$SCRIPT_DIR/platform.sh"

if [ "$PKG_MGR" = "unknown" ]; then
  echo "Warning: unknown package manager — cannot auto-install tools" >&2
  echo "Install manually: fzf bat eza fd zoxide atuin direnv lazygit btop" >&2
  exit 0
fi

# ── Required tools ────────────────────────────────────────────────────────────
required_tools=(fzf bat eza fd zoxide direnv)

for logical in "${required_tools[@]}"; do
  pname="$(pkg "$logical")"
  [ -z "$pname" ] && { echo "Warning: $logical not available for $PKG_MGR, skipping"; continue; }
  if command -v "$logical" >/dev/null 2>&1 || \
     { [ "$PKG_MGR" = "brew" ] && brew list "$pname" &>/dev/null; }; then
    echo "$logical already installed"
  else
    echo "Installing $logical..."
    $PKG_INSTALL "$pname"
  fi
done

# ── Optional tools (skip silently if pkg() returns empty) ─────────────────────
optional_tools=(lazygit btop atuin)

for logical in "${optional_tools[@]}"; do
  pname="$(pkg "$logical")"
  [ -z "$pname" ] && { echo "Note: $logical not available for $PKG_MGR — skipping"; continue; }
  if command -v "$logical" >/dev/null 2>&1 || \
     { [ "$PKG_MGR" = "brew" ] && brew list "$pname" &>/dev/null; }; then
    echo "$logical already installed"
  else
    echo "Installing $logical..."
    $PKG_INSTALL "$pname"
  fi
done

# ── Zsh plugins (Homebrew only — Linux users get these via package manager) ───
if [ "$PKG_MGR" = "brew" ]; then
  zsh_plugins=(
    zsh-autosuggestions
    zsh-syntax-highlighting
    zsh-history-substring-search
  )
  for plugin in "${zsh_plugins[@]}"; do
    if brew list "$plugin" &>/dev/null; then
      echo "$plugin already installed"
    else
      echo "Installing $plugin..."
      brew install "$plugin"
    fi
  done
else
  # On Linux, install zsh plugins via the package manager if available
  for plugin in zsh-autosuggestions zsh-syntax-highlighting; do
    pname="$(pkg "$plugin")" || pname="$plugin"
    if [ -n "$pname" ]; then
      $PKG_INSTALL "$pname" 2>/dev/null || \
        echo "Note: $plugin — install manually or via your distro's repos"
    fi
  done
fi

echo ""
echo "Done. Tools installed:"
echo "  fzf       — fuzzy finder (Ctrl-T files, Alt-C dirs)"
echo "  bat       — syntax-highlighted cat"
echo "  eza       — modern ls with icons"
echo "  fd        — fast find, powers fzf"
echo "  zoxide    — smart cd (z <partial>)"
echo "  direnv    — auto-loads .envrc per directory"
[ "$(pkg lazygit)" != "" ] && echo "  lazygit   — terminal git UI (alias: lg)"
[ "$(pkg atuin)"   != "" ] && echo "  atuin     — history database (Ctrl-R)"
echo ""
echo "Run: source ~/.zshrc  (or open a new terminal)"
```

- [ ] **Step 2: Verify syntax**

```bash
bash -n tools-config.sh && echo "OK"
```

- [ ] **Step 3: Commit**

```bash
git add tools-config.sh
git commit -m "fix: tools-config.sh uses platform.sh for cross-platform installs"
```

---

### Task 8: Update `git-config.sh`

- [ ] **Step 1: Add platform.sh and replace delta install block**

After `set -euo pipefail` add:
```bash
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
. "$SCRIPT_DIR/platform.sh"
```

Replace the delta install block:
```bash
if ! command -v delta >/dev/null 2>&1; then
  if command -v brew >/dev/null 2>&1; then
    echo "Installing git-delta via Homebrew..."
    brew install git-delta
  else
    echo "Warning: delta not found. Diffs will use default pager." >&2
  fi
else
  echo "delta already installed"
fi
```

With:
```bash
if ! command -v delta >/dev/null 2>&1; then
  _delta_pkg="$(pkg delta)"
  if [ -n "$_delta_pkg" ]; then
    echo "Installing delta..."
    $PKG_INSTALL "$_delta_pkg"
  else
    echo "Warning: delta not available for $PKG_MGR — diffs will use default pager." >&2
    echo "         Install manually from: https://github.com/dandavison/delta/releases" >&2
  fi
else
  echo "delta already installed"
fi
```

- [ ] **Step 2: Verify syntax**

```bash
bash -n git-config.sh && echo "OK"
```

- [ ] **Step 3: Commit**

```bash
git add git-config.sh
git commit -m "fix: git-config.sh uses platform.sh, delta optional on apt"
```

---

### Task 9: Update `tmux-config.sh`

- [ ] **Step 1: Add platform.sh and update install blocks**

After the existing `SCRIPT_DIR` definition add:
```bash
. "$SCRIPT_DIR/platform.sh"
```

Replace the tmux install block:
```bash
if ! command -v tmux >/dev/null 2>&1; then
  if command -v brew >/dev/null 2>&1; then
    echo "Installing tmux via Homebrew..."
    brew install tmux
  else
    echo "Error: Homebrew not found. Please install tmux manually." >&2
    exit 1
  fi
else
  echo "tmux already installed: $(tmux -V)"
fi
```

With:
```bash
if ! command -v tmux >/dev/null 2>&1; then
  if [ "$PKG_MGR" = "unknown" ]; then
    echo "Error: tmux not found and no package manager detected. Install tmux manually." >&2
    exit 1
  fi
  echo "Installing tmux..."
  $PKG_INSTALL "$(pkg tmux)"
else
  echo "tmux already installed: $(tmux -V)"
fi
```

Replace the nowplaying-cli block:
```bash
if ! command -v nowplaying-cli >/dev/null 2>&1; then
  if command -v brew >/dev/null 2>&1; then
    echo "Installing nowplaying-cli via Homebrew..."
    brew install nowplaying-cli
  else
    echo "Warning: nowplaying-cli not found. Status bar will not show now playing." >&2
  fi
else
  echo "nowplaying-cli already installed"
fi
```

With:
```bash
# nowplaying-cli is macOS-only
if [ "$DOTFILES_OS" = "macos" ]; then
  if ! command -v nowplaying-cli >/dev/null 2>&1; then
    echo "Installing nowplaying-cli via Homebrew..."
    brew install nowplaying-cli
  else
    echo "nowplaying-cli already installed"
  fi
else
  echo "Note: nowplaying-cli is macOS-only — now-playing status bar segment will be inactive"
fi
```

- [ ] **Step 2: Verify syntax**

```bash
bash -n tmux-config.sh && echo "OK"
```

- [ ] **Step 3: Commit**

```bash
git add tmux-config.sh
git commit -m "fix: tmux-config.sh guards nowplaying-cli as macOS-only"
```

---

### Task 10: Update `nvim-config.sh`

- [ ] **Step 1: Add platform.sh and replace brew-only install blocks**

After `set -euo pipefail` add:
```bash
. "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/platform.sh"
```

Replace the neovim install block:
```bash
if ! command -v nvim >/dev/null 2>&1; then
  if command -v brew >/dev/null 2>&1; then
    echo "Installing neovim via Homebrew..."
    brew install neovim
  else
    echo "Error: Homebrew not found. Please install neovim manually." >&2
    exit 1
  fi
```

With:
```bash
if ! command -v nvim >/dev/null 2>&1; then
  if [ "$PKG_MGR" = "unknown" ]; then
    echo "Error: neovim not found and no package manager detected." >&2
    exit 1
  fi
  echo "Installing neovim..."
  $PKG_INSTALL "$(pkg neovim)"
```

Replace the `lua-language-server` install block:
```bash
for pkg in lua-language-server; do
  if ! command -v "$pkg" >/dev/null 2>&1; then
    if command -v brew >/dev/null 2>&1; then
      echo "Installing $pkg via Homebrew..."
      brew install "$pkg"
    else
      echo "Warning: $pkg not found. Install manually for LSP support." >&2
    fi
  else
    echo "$pkg already installed"
  fi
done
```

With:
```bash
for _lsp in lua-ls; do
  _lsp_pkg="$(pkg "$_lsp")"
  if [ -z "$_lsp_pkg" ]; then
    echo "Note: lua-language-server not available for $PKG_MGR — Mason will handle LSP installs inside nvim"
    continue
  fi
  if ! command -v lua-language-server >/dev/null 2>&1; then
    echo "Installing lua-language-server..."
    $PKG_INSTALL "$_lsp_pkg"
  else
    echo "lua-language-server already installed"
  fi
done
```

- [ ] **Step 2: Verify syntax**

```bash
bash -n nvim-config.sh && echo "OK"
```

- [ ] **Step 3: Commit**

```bash
git add nvim-config.sh
git commit -m "fix: nvim-config.sh uses platform.sh for cross-platform install"
```

---

### Task 11: Update `eza-config.sh`

`eza-config.sh` currently only appends aliases to `~/.zshrc` without installing eza. Add platform.sh source for consistency and update comments; the aliases it appends are already portable.

- [ ] **Step 1: Add platform.sh source and eza install**

After the shebang line, add `set -euo pipefail` (it's missing) and platform.sh:

```bash
#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
. "$SCRIPT_DIR/platform.sh"

# Install eza if missing
if ! command -v eza >/dev/null 2>&1; then
  if [ "$PKG_MGR" = "unknown" ]; then
    echo "Warning: eza not found — install manually: https://github.com/eza-community/eza" >&2
  else
    echo "Installing eza..."
    $PKG_INSTALL "$(pkg eza)"
  fi
fi
```

Add this block before the `ZSHRC="$HOME/.zshrc"` line (keep rest of file unchanged).

- [ ] **Step 2: Verify syntax**

```bash
bash -n eza-config.sh && echo "OK"
```

- [ ] **Step 3: Commit**

```bash
git add eza-config.sh
git commit -m "fix: eza-config.sh installs eza via platform.sh"
```

---

## Chunk 4: `install-all.sh` + `zshrc-config.sh` + `profiles/*/zshrc`

### Files
- Modify: `install-all.sh`
- Modify: `zshrc-config.sh`
- Modify: `profiles/velvet/zshrc`
- Modify: `profiles/p10k-velvet/zshrc`
- Modify: `profiles/catppuccin/zshrc`
- Modify: `profiles/minimal/zshrc`

---

### Task 12: Update `install-all.sh` — skip macOS-only steps on Linux

- [ ] **Step 1: Add platform.sh and conditional skip logic**

After `set -euo pipefail` add:
```bash
. "$SCRIPT_DIR/platform.sh"
```

Replace the hardcoded `scripts=()` array:
```bash
scripts=(
  "setup.sh:Oh-My-Posh prompt"
  "eza-config.sh:Eza file listing"
  "tools-config.sh:Terminal tools (fzf, bat, lazygit, btop, zsh plugins)"
  "git-config.sh:Git config + delta"
  "tmux-config.sh:Tmux + now-playing"
  "nvim-config.sh:Neovim + LSP servers"
  "zshrc-config.sh:Zsh config"
  "iterm-config.sh:iTerm2 velvet theme"
  "ssh-config.sh:SSH config"
)
```

With:
```bash
# Cross-platform scripts — run on all platforms
scripts=(
  "tools-config.sh:Terminal tools (fzf, bat, eza, fd, zoxide)"
  "eza-config.sh:Eza aliases"
  "git-config.sh:Git config + delta"
  "tmux-config.sh:Tmux"
  "nvim-config.sh:Neovim + LSP servers"
  "zshrc-config.sh:Zsh config"
  "ssh-config.sh:SSH config"
)

# Desktop prompt engine (not on headless server)
if [ "$DOTFILES_OS" != "linux-server" ]; then
  scripts+=( "setup.sh:Oh-My-Posh prompt" )
fi

# macOS-only scripts
if [ "$DOTFILES_OS" = "macos" ]; then
  scripts+=( "iterm-config.sh:iTerm2 velvet theme" )
fi
```

Also update the next-steps footer to be platform-aware:
```bash
echo "Next steps:"
echo "  1. Run: source ~/.zshrc"
echo "  2. Open neovim — plugins auto-install on first launch"
echo "  3. In tmux, press Ctrl+a r to reload config"
if [ "$DOTFILES_OS" = "macos" ]; then
  echo "  4. In iTerm2, set 'Velvet' as default profile"
fi
echo "  5. Generate SSH key: ssh-keygen -t ed25519"
```

- [ ] **Step 2: Verify syntax**

```bash
bash -n install-all.sh && echo "OK"
```

- [ ] **Step 3: Commit**

```bash
git add install-all.sh
git commit -m "fix: install-all.sh skips macOS-only scripts on Linux"
```

---

### Task 13: Update `zshrc-config.sh`

- [ ] **Step 1: Add platform.sh source**

After `set -euo pipefail` (if present) or after the shebang, add:
```bash
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
. "$SCRIPT_DIR/platform.sh"
```

- [ ] **Step 2: Verify syntax**

```bash
bash -n zshrc-config.sh && echo "OK"
```

- [ ] **Step 3: Commit**

```bash
git add zshrc-config.sh
git commit -m "fix: zshrc-config.sh sources platform.sh"
```

---

### Task 14: Update `profiles/*/zshrc` — portable `copy` function

Each profile's `zshrc` has a `copy()` function that uses `pbcopy`. Replace it with the portable version in all four profiles.

- [ ] **Step 1: Find the current `copy` function in each profile**

```bash
grep -n "copy\(\)" profiles/velvet/zshrc profiles/p10k-velvet/zshrc profiles/catppuccin/zshrc profiles/minimal/zshrc
```

- [ ] **Step 2: Replace `copy()` in all four `zshrc` files**

Find and replace (in each file) the old function:
```zsh
copy() { pbcopy }
```

With the portable version:
```zsh
# Portable clipboard copy — works on macOS (pbcopy) and Linux (xclip/xsel)
if [[ -n "${DOTFILES_CLIPBOARD:-}" ]]; then
  copy() { ${=DOTFILES_CLIPBOARD} }
fi
```

Note: `${=DOTFILES_CLIPBOARD}` is zsh word-splitting syntax — it splits the variable on spaces so `xclip -sel clip` is treated as a command + args, not a single string.

- [ ] **Step 3: Verify the files have no syntax errors**

```bash
for f in profiles/*/zshrc; do
  zsh -n "$f" 2>&1 && echo "OK: $f" || echo "FAIL: $f"
done
```

Expected: `OK` for all four files

- [ ] **Step 4: Commit**

```bash
git add profiles/velvet/zshrc profiles/p10k-velvet/zshrc profiles/catppuccin/zshrc profiles/minimal/zshrc
git commit -m "fix: portable copy() function in all profile zshrc files"
```

---

## Chunk 5: `bootstrap-server.sh` + `doctor.sh` + `README.md`

### Files
- Create: `bootstrap-server.sh`
- Modify: `doctor.sh`
- Modify: `README.md`

---

### Task 15: Create `bootstrap-server.sh`

> **Note:** `role.sh` already exists in the repo (built in a prior session). Step 6 of the bootstrap flow (`role.sh apply server`) is safe to call as-is — no additional task needed.

- [ ] **Step 1: Create `bootstrap-server.sh`**

```bash
#!/usr/bin/env bash
# ============================================================================
# bootstrap-server.sh — headless Linux server setup
#
# Usage:
#   curl -fsSL https://raw.githubusercontent.com/V01DL1NG/dotfiles/master/bootstrap-server.sh | bash
#   or:  bash bootstrap-server.sh
# ============================================================================
set -euo pipefail

BOLD='\033[1m'; GREEN='\033[0;32m'; YELLOW='\033[0;33m'; RED='\033[0;31m'
LAVENDER='\033[38;2;239;220;249m'; RESET='\033[0m'

info()    { echo -e "  ${LAVENDER}${1}${RESET}"; }
success() { echo -e "  ${GREEN}✓${RESET}  ${1}"; }
warn()    { echo -e "  ${YELLOW}!${RESET}  ${1}"; }
error()   { echo -e "  ${RED}✗${RESET}  ${1}" >&2; }
header()  { echo -e "\n${BOLD}${1}${RESET}"; }

# ── Step 1: OS check ──────────────────────────────────────────────────────────
if [ "$(uname -s)" != "Linux" ]; then
  error "This script is for Linux servers only."
  error "For macOS, use bootstrap.sh instead:"
  error "  curl -fsSL https://raw.githubusercontent.com/V01DL1NG/dotfiles/master/bootstrap.sh | bash"
  exit 1
fi

header "Dotfiles — Linux Server Bootstrap"
echo ""
info "Detected: Linux"

# ── Step 2: Inline PM detection (repo not yet available) ─────────────────────
if   command -v brew    >/dev/null 2>&1; then PKG_MGR="brew";    PKG_INSTALL="brew install"
elif command -v apt-get >/dev/null 2>&1; then PKG_MGR="apt";     PKG_INSTALL="sudo apt-get install -y"
elif command -v dnf     >/dev/null 2>&1; then PKG_MGR="dnf";     PKG_INSTALL="sudo dnf install -y"
elif command -v pacman  >/dev/null 2>&1; then PKG_MGR="pacman";  PKG_INSTALL="sudo pacman -S --noconfirm"
else                                          PKG_MGR="unknown"; PKG_INSTALL="false"
fi

info "Package manager: $PKG_MGR"

# Inline package name table (mirrors platform.sh pkg() for server bootstrap)
# Returns package name for $PKG_MGR, or empty string if unavailable
_pkg() {
  local name="$1"
  case "$PKG_MGR" in
    brew)
      case "$name" in
        fd) echo "fd" ;; delta) echo "git-delta" ;; atuin) echo "atuin" ;;
        lazygit) echo "lazygit" ;; *) echo "$name" ;;
      esac ;;
    apt)
      case "$name" in
        fd) echo "fd-find" ;; delta) echo "" ;; atuin) echo "" ;; lazygit) echo "" ;;
        *) echo "$name" ;;
      esac ;;
    dnf)
      case "$name" in
        fd) echo "fd-find" ;; delta) echo "git-delta" ;; atuin) echo "" ;;
        lazygit) echo "lazygit" ;; *) echo "$name" ;;
      esac ;;
    pacman)
      case "$name" in
        fd) echo "fd" ;; delta) echo "git-delta" ;; atuin) echo "atuin" ;;
        lazygit) echo "lazygit" ;; *) echo "$name" ;;
      esac ;;
    *) echo "" ;;
  esac
}

# ── Step 3: Install base tools ────────────────────────────────────────────────
MISSING_TOOLS=()

if [ "$PKG_MGR" = "unknown" ]; then
  warn "No supported package manager found — skipping tool installation"
  MISSING_TOOLS=(git zsh curl fzf bat eza zoxide)
else
  header "Installing base tools"

  # Update package index first
  case "$PKG_MGR" in
    apt)    sudo apt-get update -qq ;;
    dnf)    sudo dnf check-update -q || true ;;
    pacman) sudo pacman -Sy --noconfirm >/dev/null 2>&1 ;;
  esac

  # Required tools
  for logical in git zsh curl fzf bat eza zoxide; do
    pname="$(_pkg "$logical")"
    if [ -z "$pname" ]; then
      warn "$logical — not available for $PKG_MGR"
      MISSING_TOOLS+=("$logical")
      continue
    fi
    if command -v "$logical" >/dev/null 2>&1; then
      success "$logical already installed"
    else
      info "Installing $logical..."
      $PKG_INSTALL "$pname"
      success "$logical installed"
    fi
  done

  # Optional tools (skip silently if unavailable for this PM)
  for logical in atuin delta lazygit; do
    pname="$(_pkg "$logical")"
    [ -z "$pname" ] && continue
    if command -v "$logical" >/dev/null 2>&1; then
      success "$logical already installed"
    else
      info "Installing $logical (optional)..."
      $PKG_INSTALL "$pname" 2>/dev/null && success "$logical installed" || \
        warn "$logical — install failed, skipping"
    fi
  done
fi

# ── Step 4: Clone repo ────────────────────────────────────────────────────────
if ! command -v git >/dev/null 2>&1; then
  error "git is required but not found"
  error "Install git manually then re-run this script"
  exit 1
fi

header "Cloning dotfiles repo"

DOTFILES_DIR="$HOME/dotfiles"
if [ -d "$DOTFILES_DIR/.git" ]; then
  info "Repo already cloned at $DOTFILES_DIR — pulling latest"
  git -C "$DOTFILES_DIR" pull --rebase
  success "repo updated"
else
  git clone https://github.com/V01DL1NG/dotfiles "$DOTFILES_DIR"
  success "repo cloned → $DOTFILES_DIR"
fi

# ── Step 5: Install minimal profile ──────────────────────────────────────────
header "Installing minimal profile"
bash "$DOTFILES_DIR/choose-profile.sh" minimal
success "minimal profile installed"

# ── Step 6: Apply server role ─────────────────────────────────────────────────
header "Applying server role"
bash "$DOTFILES_DIR/role.sh" apply server
success "server role applied"

# ── Step 7: Set zsh as default shell ─────────────────────────────────────────
if ! command -v zsh >/dev/null 2>&1; then
  warn "zsh not found — skipping shell change"
  warn "Install zsh manually, then run: chsh -s \$(which zsh)"
else
  ZSH_PATH="$(command -v zsh)"
  if [ "$SHELL" = "$ZSH_PATH" ]; then
    success "zsh is already the default shell"
  else
    info "Setting zsh as default shell (you may be prompted for your password)..."
    if ! grep -qF "$ZSH_PATH" /etc/shells 2>/dev/null; then
      echo "$ZSH_PATH" | sudo tee -a /etc/shells >/dev/null
    fi
    chsh -s "$ZSH_PATH"
    success "default shell set to zsh"
  fi
fi

# ── Step 8: Summary ────────────────────────────────────────────────────────────
echo ""
echo -e "${BOLD}${GREEN}Setup complete!${RESET}"
echo ""

if [ ${#MISSING_TOOLS[@]} -gt 0 ]; then
  warn "The following tools could not be installed automatically:"
  for t in "${MISSING_TOOLS[@]}"; do
    warn "  - $t"
  done
  echo ""
  warn "Install them manually, then run:"
  warn "  source ~/.zshrc"
  echo ""
fi

echo "  Next steps:"
echo "    1. Reconnect SSH (to start a fresh zsh session)"
echo "    2. Or run: source ~/.zshrc"
echo "    3. Run: ~/dotfiles/doctor.sh  (health check)"
echo ""
```

- [ ] **Step 2: Make executable and syntax-check**

```bash
chmod +x bootstrap-server.sh
bash -n bootstrap-server.sh && echo "OK"
```

- [ ] **Step 3: Test non-Linux rejection (macOS)**

```bash
# This should print an error and exit 1 — test with a fake uname
(
  uname() { echo "Darwin"; }
  export -f uname
  bash bootstrap-server.sh
)
```

Expected: error message mentioning `bootstrap.sh`, exits non-zero

- [ ] **Step 4: Commit**

```bash
git add bootstrap-server.sh
git commit -m "feat: add bootstrap-server.sh for headless Linux setup"
```

---

### Task 16: Update `doctor.sh` — Linux-aware checks

- [ ] **Step 1: Add platform.sh source to `doctor.sh`**

Read the current `doctor.sh` first. Find the `SCRIPT_DIR` line and add after it:
```bash
. "$SCRIPT_DIR/platform.sh"
```

- [ ] **Step 2: Wrap macOS-only sections in guards**

Find the Homebrew check section and wrap it:
```bash
if [ "$DOTFILES_OS" = "macos" ]; then
  # --- existing Homebrew check ---
fi
```

Find the iTerm2 check section and wrap it:
```bash
if [ "$DOTFILES_OS" = "macos" ]; then
  # --- existing iTerm2 check ---
fi
```

Find the oh-my-posh / FiraCode font checks and wrap:
```bash
if [ "$DOTFILES_OS" != "linux-server" ]; then
  # --- oh-my-posh check ---
fi
if [ "$DOTFILES_OS" = "macos" ]; then
  # --- FiraCode font check ---
fi
```

- [ ] **Step 3: Add Linux-specific checks**

After the existing tools section, add a new `if [ "$DOTFILES_OS" != "macos" ]` block:

```bash
if [ "$DOTFILES_OS" != "macos" ]; then
  section "Linux"

  # Known package manager
  if [ "$PKG_MGR" = "unknown" ]; then
    fail "No supported package manager found (apt/dnf/pacman/brew)"
  else
    pass "Package manager: $PKG_MGR"
  fi

  # zsh as login shell
  if [ "$SHELL" = "$(command -v zsh 2>/dev/null)" ]; then
    pass "zsh is the login shell"
  else
    warn "zsh is not the login shell — run: chsh -s \$(which zsh)"
  fi

  # Clipboard tool (desktop only)
  if [ "$DOTFILES_OS" = "linux-desktop" ]; then
    if command -v xclip >/dev/null 2>&1 || command -v xsel >/dev/null 2>&1; then
      pass "clipboard tool available (xclip/xsel)"
    else
      warn "no clipboard tool found — install xclip or xsel for copy() function"
    fi
  fi

  # Sanity: $DISPLAY set on a server is suspicious
  if [ "$DOTFILES_OS" = "linux-server" ] && [ -n "${DISPLAY:-}" ]; then
    warn "\$DISPLAY is set on a server — is this actually a desktop?"
  fi
fi
```

- [ ] **Step 4: Verify syntax**

```bash
bash -n doctor.sh && echo "OK"
```

- [ ] **Step 5: Run doctor.sh to confirm it still works on macOS**

```bash
bash doctor.sh
```

Expected: all existing macOS checks still pass; no errors from the new Linux section

- [ ] **Step 6: Commit**

```bash
git add doctor.sh
git commit -m "fix: doctor.sh is Linux-aware, skips macOS-only checks on Linux"
```

---

### Task 17: Update `README.md` — Linux install instructions

- [ ] **Step 1: Add Linux section to README**

After the "Quick Start" section, add a new section:

```markdown
## Linux

**Headless server (one command):**
```bash
curl -fsSL https://raw.githubusercontent.com/V01DL1NG/dotfiles/master/bootstrap-server.sh | bash
```

Installs: `git zsh fzf bat eza zoxide` via your native package manager (apt/dnf/pacman), clones the repo, installs the `minimal` profile, and applies the `server` role.

**Linux desktop (Ubuntu/Fedora/Arch):**
```bash
# Clone and pick a profile
git clone https://github.com/V01DL1NG/dotfiles ~/dotfiles && cd ~/dotfiles
./choose-profile.sh      # picks a profile and installs terminal configs
./install-all.sh         # installs tools via native package manager
```

All profiles work on Linux desktop. iTerm2-specific features are skipped automatically; Ghostty and Kitty configs are installed if those terminals are detected.

**Unknown package manager:** The scripts skip tool installation and report which tools to install manually, then proceed with profile and role setup.
```

- [ ] **Step 2: Update the "File Structure" section** to include `bootstrap-server.sh` and `platform.sh`:

Add alongside `bootstrap.sh`:
```
├── bootstrap-server.sh             # curl-installable Linux server setup
├── platform.sh                     # shared OS/PM detection library
```

- [ ] **Step 3: Commit**

```bash
git add README.md
git commit -m "docs: add Linux install instructions to README"
```

---

### Task 18: Run full test suite

- [ ] **Step 1: Run platform tests**

```bash
bash test-platform.sh
```

Expected: all pass

- [ ] **Step 2: Run syntax check on all modified scripts**

```bash
for f in platform.sh bootstrap-server.sh choose-profile.sh profile.sh \
          setup.sh iterm-config.sh tools-config.sh git-config.sh \
          tmux-config.sh nvim-config.sh eza-config.sh install-all.sh \
          zshrc-config.sh doctor.sh; do
  bash -n "$f" && echo "OK: $f" || echo "FAIL: $f"
done
```

Expected: `OK` for all

- [ ] **Step 3: Run existing test suite (macOS)**

```bash
bash test.sh
```

Expected: same results as before (no regressions on macOS)

- [ ] **Step 4: Linux path smoke test (using force-override variables)**

Use `_DOTFILES_FORCE_OS` and `_DOTFILES_FORCE_PKG_MGR` to exercise the Linux code paths on macOS — verifying correct variable values and that optional-package guards don't error:

```bash
# Verify linux-server/apt path through platform.sh
(
  export _DOTFILES_FORCE_OS=linux-server _DOTFILES_FORCE_PKG_MGR=apt
  . ./platform.sh
  echo "DOTFILES_OS=$DOTFILES_OS"         # expect: linux-server
  echo "PKG_INSTALL=$PKG_INSTALL"         # expect: sudo apt-get install -y
  echo "pkg(fd)=$(pkg fd)"                # expect: fd-find
  echo "pkg(delta)=$(pkg delta)"          # expect: (empty)
  echo "pkg(lazygit)=$(pkg lazygit)"      # expect: (empty)
  echo "DOTFILES_CLIPBOARD=$DOTFILES_CLIPBOARD"  # expect: (empty)
  echo "OK"
)

# Verify linux-desktop/pacman path
(
  export _DOTFILES_FORCE_OS=linux-desktop _DOTFILES_FORCE_PKG_MGR=pacman
  . ./platform.sh
  echo "DOTFILES_OS=$DOTFILES_OS"         # expect: linux-desktop
  echo "PKG_INSTALL=$PKG_INSTALL"         # expect: sudo pacman -S --noconfirm
  echo "pkg(delta)=$(pkg delta)"          # expect: git-delta
  echo "OK"
)

# Verify unknown PM hard-stops gracefully ($PKG_INSTALL=false)
(
  export _DOTFILES_FORCE_OS=linux-server _DOTFILES_FORCE_PKG_MGR=unknown
  . ./platform.sh
  echo "PKG_INSTALL=$PKG_INSTALL"         # expect: false
  echo "OK"
)
```

Expected: all three blocks print `OK` with the correct values above

- [ ] **Step 5: Final commit**

```bash
git add -p   # review any remaining unstaged changes
git commit -m "chore: cross-platform Linux support complete" || echo "nothing to commit"
```
