#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=platform.sh
. "$SCRIPT_DIR/platform.sh"

if [ "$DOTFILES_OS" = "linux-server" ]; then
  echo "Skipping oh-my-posh setup (not supported on headless servers — use minimal profile)"
  exit 0
fi

# Install oh-my-posh via Homebrew if missing
if ! command -v oh-my-posh >/dev/null 2>&1; then
  if command -v brew >/dev/null 2>&1; then
    echo "Installing oh-my-posh via Homebrew..."
    brew install jandedobbeleer/oh-my-posh/oh-my-posh
  elif command -v apt-get >/dev/null 2>&1 || command -v dnf >/dev/null 2>&1; then
    echo "Installing oh-my-posh via official script..."
    curl -s https://ohmyposh.dev/install.sh | bash -s -- -d ~/.local/bin
  else
    echo "Warning: oh-my-posh not installed — install manually"
  fi
else
  echo "oh-my-posh already installed: $(oh-my-posh --version)"
fi

# Symlink velvet theme from repo
OMP_DIR="$HOME/oh-my-posh"
mkdir -p "$OMP_DIR"
echo "Linking velvet.omp.json → $OMP_DIR/velvet.omp.json"
ln -sf "$SCRIPT_DIR/velvet.omp.json" "$OMP_DIR/velvet.omp.json"

echo ""
echo "Done. Run zshrc-config.sh to install the zsh config."
