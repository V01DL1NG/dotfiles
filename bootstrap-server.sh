#!/usr/bin/env bash
# bootstrap-server.sh — headless Linux server / WSL dotfiles setup
# Usage: curl -fsSL https://raw.githubusercontent.com/V01DL1NG/dotfiles/master/bootstrap-server.sh | bash
set -euo pipefail

# ── Colours ───────────────────────────────────────────────────────────────────
RED='\033[0;31m'; YELLOW='\033[1;33m'; GREEN='\033[0;32m'; CYAN='\033[0;36m'; NC='\033[0m'
info()    { printf "${CYAN}[bootstrap]${NC} %s\n" "$*"; }
success() { printf "${GREEN}[bootstrap]${NC} ✓ %s\n" "$*"; }
warn()    { printf "${YELLOW}[bootstrap]${NC} ⚠ %s\n" "$*" >&2; }
error()   { printf "${RED}[bootstrap]${NC} ✗ %s\n" "$*" >&2; }

DOTFILES_REPO="https://github.com/V01DL1NG/dotfiles"
DOTFILES_DIR="${HOME}/dotfiles"
LOCAL_BIN="${HOME}/.local/bin"
mkdir -p "$LOCAL_BIN"

# ── Step 1: OS check ──────────────────────────────────────────────────────────
if [ "$(uname -s)" != "Linux" ]; then
  error "This script is for Linux / WSL only."
  error "For macOS, use: curl -fsSL ${DOTFILES_REPO}/raw/master/bootstrap.sh | bash"
  exit 1
fi

# Detect WSL
IS_WSL=false
if grep -qi microsoft /proc/version 2>/dev/null; then
  IS_WSL=true
  info "WSL detected"
fi

# ── Step 2: Package manager detection ─────────────────────────────────────────
if   command -v apt-get >/dev/null 2>&1; then PKG_MGR="apt"
elif command -v dnf     >/dev/null 2>&1; then PKG_MGR="dnf"
elif command -v pacman  >/dev/null 2>&1; then PKG_MGR="pacman"
elif command -v brew    >/dev/null 2>&1; then PKG_MGR="brew"
else                                          PKG_MGR="unknown"
fi
info "Package manager: $PKG_MGR"

# ── Helpers ───────────────────────────────────────────────────────────────────

# Detect CPU arch for GitHub release downloads
arch_tag() {
  case "$(uname -m)" in
    x86_64)  echo "x86_64" ;;
    aarch64) echo "aarch64" ;;
    armv7l)  echo "armv7" ;;
    *)       echo "x86_64" ;;
  esac
}

# Fetch latest tag from GitHub (strips leading "v")
gh_latest() {
  curl -fsSL "https://api.github.com/repos/$1/releases/latest" \
    | grep '"tag_name"' | head -1 | sed 's/.*"v\?\([^"]*\)".*/\1/'
}

# Install a .deb from a URL into /tmp then dpkg it
install_deb() {
  local url="$1" tmp
  tmp="$(mktemp /tmp/bootstrap-XXXXXX.deb)"
  curl -fsSL "$url" -o "$tmp"
  sudo dpkg -i "$tmp" || true
  rm -f "$tmp"
}

# Symlink a command into ~/.local/bin if it doesn't already exist there
symlink_bin() {
  local src="$1" dest="$LOCAL_BIN/$2"
  if [ -f "$src" ] && [ ! -e "$dest" ]; then
    ln -sf "$src" "$dest"
    info "Symlinked $src → $dest"
  fi
}

MISSING_TOOLS=()

# ── Step 3: Base apt packages ─────────────────────────────────────────────────
if [ "$PKG_MGR" = "apt" ]; then
  info "Updating apt..."
  sudo apt-get update -qq

  # Core packages available in Ubuntu 22.04+ default repos
  APT_PKGS=(
    git zsh curl wget gpg build-essential
    fzf bat fd-find tmux
    zsh-autosuggestions zsh-syntax-highlighting
  )

  info "Installing apt packages..."
  sudo apt-get install -y "${APT_PKGS[@]}" || warn "Some apt packages failed — continuing"

  # bat installs as 'batcat' on Ubuntu; symlink to ~/.local/bin/bat
  symlink_bin /usr/bin/batcat bat

  # fd-find installs as 'fdfind'; symlink to ~/.local/bin/fd
  symlink_bin /usr/bin/fdfind fd

  # ── zsh-history-substring-search (not in Ubuntu apt — install from GitHub) ──
  ZSH_HSS_DIR="${HOME}/.zsh/zsh-history-substring-search"
  if [ ! -f "$ZSH_HSS_DIR/zsh-history-substring-search.zsh" ]; then
    info "Installing zsh-history-substring-search from GitHub..."
    mkdir -p "$ZSH_HSS_DIR"
    curl -fsSL "https://raw.githubusercontent.com/zsh-users/zsh-history-substring-search/master/zsh-history-substring-search.zsh" \
      -o "$ZSH_HSS_DIR/zsh-history-substring-search.zsh" \
      || warn "zsh-history-substring-search install failed — skipping"
  else
    info "zsh-history-substring-search already installed"
  fi

  # ── eza (not in default Ubuntu repos — use official apt repo) ───────────────
  if ! command -v eza >/dev/null 2>&1; then
    info "Installing eza via official apt repo..."
    sudo mkdir -p /etc/apt/keyrings
    wget -qO- https://raw.githubusercontent.com/eza-community/eza/main/deb.asc \
      | sudo gpg --dearmor -o /etc/apt/keyrings/gierens.gpg 2>/dev/null
    echo "deb [signed-by=/etc/apt/keyrings/gierens.gpg] http://deb.gierens.de stable main" \
      | sudo tee /etc/apt/sources.list.d/gierens.list >/dev/null
    sudo chmod 644 /etc/apt/keyrings/gierens.gpg /etc/apt/sources.list.d/gierens.list
    sudo apt-get update -qq
    sudo apt-get install -y eza || warn "eza install failed — skipping"
  else
    info "eza already installed"
  fi

  # ── zoxide (not in Ubuntu 22.04 apt — use official install script) ──────────
  if ! command -v zoxide >/dev/null 2>&1; then
    info "Installing zoxide via install script..."
    curl -fsSL https://raw.githubusercontent.com/ajeetdsouza/zoxide/main/install.sh \
      | ZOXIDE_INSTALL="$LOCAL_BIN" sh || warn "zoxide install failed — skipping"
  else
    info "zoxide already installed"
  fi

  # ── delta (not in default apt repos — install .deb from GitHub releases) ────
  if ! command -v delta >/dev/null 2>&1; then
    info "Installing delta from GitHub releases..."
    DELTA_VER="$(gh_latest dandavison/delta)" || DELTA_VER=""
    if [ -n "$DELTA_VER" ]; then
      ARCH="$(uname -m)"
      case "$ARCH" in
        x86_64)  DEB_ARCH="amd64" ;;
        aarch64) DEB_ARCH="arm64" ;;
        *)       DEB_ARCH="amd64" ;;
      esac
      install_deb "https://github.com/dandavison/delta/releases/download/${DELTA_VER}/git-delta_${DELTA_VER}_${DEB_ARCH}.deb" \
        || warn "delta install failed — skipping"
    else
      warn "Could not fetch delta version — skipping"
    fi
  else
    info "delta already installed"
  fi

  # ── lazygit (not in default apt repos — install from GitHub releases) ────────
  if ! command -v lazygit >/dev/null 2>&1; then
    info "Installing lazygit from GitHub releases..."
    LG_VER="$(gh_latest jesseduffield/lazygit)" || LG_VER=""
    if [ -n "$LG_VER" ]; then
      ARCH_TAG="$(arch_tag)"
      TMP="$(mktemp -d)"
      curl -fsSL "https://github.com/jesseduffield/lazygit/releases/latest/download/lazygit_${LG_VER}_Linux_${ARCH_TAG}.tar.gz" \
        | tar -xz -C "$TMP" lazygit
      install -m 755 "$TMP/lazygit" "$LOCAL_BIN/lazygit"
      rm -rf "$TMP"
      success "lazygit installed"
    else
      warn "Could not fetch lazygit version — skipping"
    fi
  else
    info "lazygit already installed"
  fi

  # ── atuin (not in default apt repos — use official install script) ──────────
  if ! command -v atuin >/dev/null 2>&1; then
    info "Installing atuin via install script..."
    curl --proto '=https' --tlsv1.2 -LsSf https://setup.atuin.sh \
      | sh || warn "atuin install failed — skipping"
  else
    info "atuin already installed"
  fi

# ── Step 3 (dnf / pacman / brew fallback) ─────────────────────────────────────
elif [ "$PKG_MGR" = "dnf" ]; then
  info "Installing packages via dnf..."
  sudo dnf install -y git zsh curl fzf bat fd-find tmux git-delta lazygit \
    || warn "Some dnf packages failed — continuing"
  # zoxide
  if ! command -v zoxide >/dev/null 2>&1; then
    curl -fsSL https://raw.githubusercontent.com/ajeetdsouza/zoxide/main/install.sh \
      | ZOXIDE_INSTALL="$LOCAL_BIN" sh || warn "zoxide install failed"
  fi
  # atuin
  if ! command -v atuin >/dev/null 2>&1; then
    curl --proto '=https' --tlsv1.2 -LsSf https://setup.atuin.sh | sh || warn "atuin install failed"
  fi

elif [ "$PKG_MGR" = "pacman" ]; then
  info "Installing packages via pacman..."
  sudo pacman -S --noconfirm git zsh curl fzf bat fd lazygit git-delta zoxide atuin tmux \
    || warn "Some pacman packages failed — continuing"

elif [ "$PKG_MGR" = "brew" ]; then
  info "Installing packages via brew..."
  brew install git zsh fzf bat fd git-delta lazygit zoxide atuin tmux \
    || warn "Some brew packages failed — continuing"

else
  warn "Unknown package manager — skipping tool installation"
  MISSING_TOOLS=(git zsh curl fzf bat fd delta lazygit zoxide atuin)
fi

# Ensure ~/.local/bin is on PATH for the rest of this script
export PATH="$LOCAL_BIN:$PATH"

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

# ── Step 7: Ensure ~/.local/bin is in PATH configs ───────────────────────────
LOCAL_BIN_EXPORT='export PATH="$HOME/.local/bin:$PATH"'

# Add to ~/.zshrc (zsh sessions)
ZSHRC="$HOME/.zshrc"
if [ -f "$ZSHRC" ] && ! grep -q '\.local/bin' "$ZSHRC"; then
  echo "$LOCAL_BIN_EXPORT" >> "$ZSHRC"
  info "Added ~/.local/bin to PATH in .zshrc"
fi

# Add to ~/.bashrc too — default shell is bash on WSL/Ubuntu until chsh takes effect
BASHRC="$HOME/.bashrc"
if [ -f "$BASHRC" ] && ! grep -q '\.local/bin' "$BASHRC"; then
  echo "$LOCAL_BIN_EXPORT" >> "$BASHRC"
  info "Added ~/.local/bin to PATH in .bashrc"
fi

# ── Step 8: Set zsh as default shell ─────────────────────────────────────────
if command -v zsh >/dev/null 2>&1; then
  ZSH_PATH="$(command -v zsh)"
  if [ "$SHELL" = "$ZSH_PATH" ]; then
    info "zsh is already the login shell"
  else
    if [ "$IS_WSL" = "true" ]; then
      info "WSL: setting zsh as default shell (may need password)..."
    fi
    chsh -s "$ZSH_PATH" || warn "chsh failed — set your shell manually: chsh -s $ZSH_PATH"
  fi
else
  warn "zsh not installed — skipping chsh"
fi

# ── Step 9: Summary ───────────────────────────────────────────────────────────
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

info "Installed tool check:"
for tool in git zsh fzf bat fd eza zoxide delta lazygit atuin tmux; do
  if command -v "$tool" >/dev/null 2>&1; then
    printf "    ${GREEN}✓${NC} %s\n" "$tool"
  else
    printf "    ${YELLOW}✗${NC} %s (not found in PATH)\n" "$tool"
  fi
done

echo ""
info "Next steps:"
if [ "$IS_WSL" = "true" ]; then
  echo "    Your default shell is still bash until you open a new WSL window."
  echo "    To start zsh now:   zsh"
  echo "    To make it stick:   chsh -s \$(which zsh)  then reopen WSL"
else
  echo "    1. Open a new shell or run: exec zsh"
fi
echo ""
warn "Do NOT run 'source ~/.zshrc' from bash — open zsh first."
echo ""
