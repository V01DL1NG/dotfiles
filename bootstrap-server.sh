#!/usr/bin/env bash
# bootstrap-server.sh — headless Linux server dotfiles setup
# Usage: curl -fsSL https://raw.githubusercontent.com/V01DL1NG/dotfiles/master/bootstrap-server.sh | bash
set -euo pipefail

# ── Colours ───────────────────────────────────────────────────────────────────
RED='\033[0;31m'; YELLOW='\033[1;33m'; GREEN='\033[0;32m'; CYAN='\033[0;36m'; NC='\033[0m'
info()    { printf "${CYAN}[bootstrap-server]${NC} %s\n" "$*"; }
success() { printf "${GREEN}[bootstrap-server]${NC} ✓ %s\n" "$*"; }
warn()    { printf "${YELLOW}[bootstrap-server]${NC} ⚠ %s\n" "$*" >&2; }
error()   { printf "${RED}[bootstrap-server]${NC} ✗ %s\n" "$*" >&2; }

DOTFILES_REPO="https://github.com/V01DL1NG/dotfiles"
DOTFILES_DIR="${HOME}/dotfiles"

# ── Step 1: OS check ──────────────────────────────────────────────────────────
if [ "$(uname -s)" != "Linux" ]; then
  error "This script is for Linux servers only."
  error "For macOS, use: curl -fsSL ${DOTFILES_REPO}/raw/master/bootstrap.sh | bash"
  exit 1
fi
info "Linux detected — starting server bootstrap"

# ── Step 2: Inline package manager detection ──────────────────────────────────
if   command -v brew    >/dev/null 2>&1; then PKG_MGR="brew";    PKG_INSTALL="brew install"
elif command -v apt-get >/dev/null 2>&1; then PKG_MGR="apt";     PKG_INSTALL="sudo apt-get install -y"
elif command -v dnf     >/dev/null 2>&1; then PKG_MGR="dnf";     PKG_INSTALL="sudo dnf install -y"
elif command -v pacman  >/dev/null 2>&1; then PKG_MGR="pacman";  PKG_INSTALL="sudo pacman -S --noconfirm"
else                                          PKG_MGR="unknown"; PKG_INSTALL="false"
fi
info "Package manager: $PKG_MGR"

# ── Inline package name table (platform.sh not available yet) ─────────────────
# Returns the PM-specific package name for a logical name, or "" if unavailable.
pkg_inline() {
  local name="$1"
  case "$PKG_MGR" in
    brew)
      case "$name" in
        delta) echo "git-delta" ;;
        *)     echo "$name" ;;
      esac ;;
    apt)
      case "$name" in
        fd)      echo "fd-find" ;;
        delta)   echo "" ;;
        lazygit) echo "" ;;
        atuin)   echo "" ;;
        *)       echo "$name" ;;
      esac ;;
    dnf)
      case "$name" in
        fd)    echo "fd-find" ;;
        delta) echo "git-delta" ;;
        atuin) echo "" ;;
        *)     echo "$name" ;;
      esac ;;
    pacman)
      case "$name" in
        delta) echo "git-delta" ;;
        *)     echo "$name" ;;
      esac ;;
    *) echo "" ;;
  esac
}

MISSING_TOOLS=()

# ── Step 3: Install base tools ────────────────────────────────────────────────
if [ "$PKG_MGR" != "unknown" ]; then
  info "Installing required tools..."

  # Required tools
  for tool in git zsh curl fzf bat eza zoxide; do
    _p="$(pkg_inline "$tool")"
    if [ -n "$_p" ]; then
      info "Installing $_p..."
      $PKG_INSTALL "$_p" || warn "Failed to install $_p — continuing"
    fi
  done

  # Optional tools (best-effort)
  for tool in atuin delta lazygit; do
    _p="$(pkg_inline "$tool")"
    if [ -n "$_p" ]; then
      info "Installing $_p (optional)..."
      $PKG_INSTALL "$_p" || warn "Failed to install $_p (optional) — skipping"
    else
      warn "Skipping $tool (not available via $PKG_MGR)"
    fi
  done
else
  warn "Unknown package manager — skipping tool installation"
  MISSING_TOOLS=(git zsh curl fzf bat eza zoxide)
fi

# ── Step 4: Clone repo ────────────────────────────────────────────────────────
if ! command -v git >/dev/null 2>&1; then
  error "git is required but not installed. Install it first and re-run."
  exit 1
fi

if [ -d "$DOTFILES_DIR" ]; then
  info "Dotfiles already cloned at $DOTFILES_DIR — pulling latest"
  git -C "$DOTFILES_DIR" pull
else
  info "Cloning dotfiles to $DOTFILES_DIR..."
  git clone "$DOTFILES_REPO" "$DOTFILES_DIR"
fi

# ── Step 5: Install minimal profile ──────────────────────────────────────────
info "Installing minimal profile..."
bash "$DOTFILES_DIR/choose-profile.sh" minimal

# ── Step 6: Apply server role ─────────────────────────────────────────────────
info "Applying server role..."
bash "$DOTFILES_DIR/role.sh" apply server

# ── Step 7: Set zsh as default shell ─────────────────────────────────────────
if command -v zsh >/dev/null 2>&1; then
  ZSH_PATH="$(command -v zsh)"
  if [ "$SHELL" = "$ZSH_PATH" ]; then
    info "zsh is already the login shell"
  else
    info "Setting zsh as default shell..."
    chsh -s "$ZSH_PATH" || warn "chsh failed — set your shell manually: chsh -s $ZSH_PATH"
  fi
else
  warn "zsh not installed — skipping chsh. Install zsh manually."
fi

# ── Step 8: Summary ───────────────────────────────────────────────────────────
echo ""
success "Bootstrap complete!"
echo ""

if [ ${#MISSING_TOOLS[@]} -gt 0 ]; then
  warn "Unknown package manager — please install these tools manually:"
  for t in "${MISSING_TOOLS[@]}"; do
    echo "    - $t"
  done
  echo ""
fi

info "Next steps:"
echo "    1. Start a new SSH session (or run: exec zsh)"
echo "    2. Source your new config:  source ~/.zshrc"
echo ""
