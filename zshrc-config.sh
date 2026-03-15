#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ZSHRC="$HOME/.zshrc"
BACKUP="$ZSHRC.backup.$(date +%Y%m%d%H%M%S)"

# Install oh-my-posh via Homebrew if missing
if ! command -v oh-my-posh >/dev/null 2>&1; then
  if command -v brew >/dev/null 2>&1; then
    echo "Installing oh-my-posh via Homebrew..."
    brew install oh-my-posh
  else
    echo "Error: Homebrew not found. Please install oh-my-posh manually." >&2
    exit 1
  fi
else
  echo "oh-my-posh already installed"
fi

# Install eza via Homebrew if missing
if ! command -v eza >/dev/null 2>&1; then
  if command -v brew >/dev/null 2>&1; then
    echo "Installing eza via Homebrew..."
    brew install eza
  else
    echo "Warning: eza not found. File listing aliases will not work." >&2
  fi
else
  echo "eza already installed"
fi

# Back up existing config if it's a regular file (not already a symlink)
if [ -f "$ZSHRC" ] && [ ! -L "$ZSHRC" ]; then
  echo "Backing up $ZSHRC to $BACKUP"
  cp "$ZSHRC" "$BACKUP"
fi

# Symlink config into place
echo "Linking zshrc → $ZSHRC"
ln -sf "$SCRIPT_DIR/zshrc" "$ZSHRC"

echo ""
echo "Done. To apply:"
echo "  - Run: source ~/.zshrc"
echo "  - Or open a new terminal"
