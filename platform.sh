#!/usr/bin/env bash
# ============================================================================
# platform.sh — shared platform detection library
#
# Source this at the top of every install script:
#   SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
#   . "$SCRIPT_DIR/platform.sh"
#
# Exports: DOTFILES_OS, PKG_MGR, PKG_INSTALL, BASE64_DECODE,
#          DOTFILES_CLIPBOARD, and the pkg() and sed_inplace() functions.
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
  macos) BASE64_DECODE="base64 -D" ;;
  *)     BASE64_DECODE="base64 -d" ;;
esac

# sed_inplace — portable in-place sed; use instead of $SED_INPLACE
# Usage: sed_inplace 's/old/new/' file
sed_inplace() {
  if [ "$DOTFILES_OS" = "macos" ]; then
    sed -i '' "$@"
  else
    sed -i "$@"
  fi
}

# Clipboard — pbcopy on macOS, xclip/xsel on Linux desktop, empty on server
DOTFILES_CLIPBOARD=""
if [ "$DOTFILES_OS" = "macos" ]; then
  DOTFILES_CLIPBOARD="pbcopy"
elif [ "$DOTFILES_OS" = "linux-desktop" ]; then
  if   command -v xclip >/dev/null 2>&1; then DOTFILES_CLIPBOARD="xclip -sel clip"
  elif command -v xsel  >/dev/null 2>&1; then DOTFILES_CLIPBOARD="xsel --clipboard"
  fi
fi

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

export DOTFILES_OS PKG_MGR PKG_INSTALL BASE64_DECODE DOTFILES_CLIPBOARD
export -f sed_inplace pkg
