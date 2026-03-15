#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Install oh-my-posh via Homebrew if missing
if ! command -v oh-my-posh >/dev/null 2>&1; then
  if command -v brew >/dev/null 2>&1; then
    echo "Installing oh-my-posh via Homebrew..."
    brew install jandedobbeleer/oh-my-posh/oh-my-posh || brew install oh-my-posh
  else
    echo "Homebrew not found. Please install Homebrew or oh-my-posh manually: https://ohmyposh.dev/docs/installation"
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
