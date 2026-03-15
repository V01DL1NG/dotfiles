#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
NVIM_DIR="$HOME/.config/nvim"
NVIM_INIT="$NVIM_DIR/init.lua"
BACKUP="$NVIM_INIT.backup.$(date +%Y%m%d%H%M%S)"

# Install neovim via Homebrew if missing
if ! command -v nvim >/dev/null 2>&1; then
  if command -v brew >/dev/null 2>&1; then
    echo "Installing neovim via Homebrew..."
    brew install neovim
  else
    echo "Error: Homebrew not found. Please install neovim manually." >&2
    exit 1
  fi
else
  echo "neovim already installed: $(nvim --version | head -1)"
fi

# Install LSP servers if missing
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

for pkg in pyright typescript typescript-language-server; do
  if ! command -v "$pkg" >/dev/null 2>&1; then
    if command -v npm >/dev/null 2>&1; then
      echo "Installing $pkg via npm..."
      npm install -g "$pkg"
    else
      echo "Warning: $pkg not found. Install Node.js and npm for LSP support." >&2
    fi
  else
    echo "$pkg already installed"
  fi
done

# Create nvim config directory
mkdir -p "$NVIM_DIR"

# Back up existing config if it's a regular file (not already a symlink)
if [ -f "$NVIM_INIT" ] && [ ! -L "$NVIM_INIT" ]; then
  echo "Backing up $NVIM_INIT to $BACKUP"
  cp "$NVIM_INIT" "$BACKUP"
fi

# Symlink config into place
echo "Linking init.lua → $NVIM_INIT"
ln -sf "$SCRIPT_DIR/init.lua" "$NVIM_INIT"

echo ""
echo "Done. To apply:"
echo "  - Open neovim: nvim"
echo "  - Plugins will auto-install on first launch via lazy.nvim"
