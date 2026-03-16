#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=platform.sh
. "$SCRIPT_DIR/platform.sh"

NVIM_DIR="$HOME/.config/nvim"
NVIM_INIT="$NVIM_DIR/init.lua"
BACKUP="$NVIM_INIT.backup.$(date +%Y%m%d%H%M%S)"

# Install neovim if missing
if ! command -v nvim >/dev/null 2>&1; then
  echo "Installing neovim..."
  $PKG_INSTALL "$(pkg neovim)"
else
  echo "neovim already installed: $(nvim --version | head -1)"
fi

# Install LSP servers via brew (macOS) or skip with a note on Linux
# lua-language-server is brew-only; on Linux install manually or via Mason
if ! command -v lua-language-server >/dev/null 2>&1; then
  _p="$(pkg lua-ls)"; if [ -n "$_p" ]; then
    echo "Installing lua-language-server..."
    $PKG_INSTALL "$_p"
  else
    echo "Warning: lua-language-server not available via $PKG_MGR — install manually or use Mason inside nvim." >&2
  fi
else
  echo "lua-language-server already installed"
fi

# npm-based LSP servers (cross-platform via Node.js)
for npm_pkg in pyright typescript typescript-language-server; do
  if ! command -v "$npm_pkg" >/dev/null 2>&1; then
    if command -v npm >/dev/null 2>&1; then
      echo "Installing $npm_pkg via npm..."
      npm install -g "$npm_pkg"
    else
      echo "Warning: $npm_pkg not found. Install Node.js and npm for LSP support." >&2
    fi
  else
    echo "$npm_pkg already installed"
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
