#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=platform.sh
. "$SCRIPT_DIR/platform.sh"

TMUX_CONF="$HOME/.tmux.conf"
BACKUP="$TMUX_CONF.backup.$(date +%Y%m%d%H%M%S)"

# Install tmux if missing
if ! command -v tmux >/dev/null 2>&1; then
  echo "Installing tmux..."
  $PKG_INSTALL "$(pkg tmux)"
else
  echo "tmux already installed: $(tmux -V)"
fi

# Install nowplaying-cli (macOS only — no Linux equivalent)
if [ "$DOTFILES_OS" = "macos" ]; then
  if ! command -v nowplaying-cli >/dev/null 2>&1; then
    echo "Installing nowplaying-cli via Homebrew..."
    brew install nowplaying-cli
  else
    echo "nowplaying-cli already installed"
  fi
fi

# Back up existing config if it's a regular file (not already a symlink)
if [ -f "$TMUX_CONF" ] && [ ! -L "$TMUX_CONF" ]; then
  echo "Backing up $TMUX_CONF to $BACKUP"
  cp "$TMUX_CONF" "$BACKUP"
fi

# Symlink configs into place
echo "Linking tmux.conf → $TMUX_CONF"
ln -sf "$SCRIPT_DIR/tmux.conf" "$TMUX_CONF"

if [ "$DOTFILES_OS" = "macos" ]; then
  mkdir -p "$HOME/.tmux"
  echo "Linking now-playing.sh → $HOME/.tmux/now-playing.sh"
  ln -sf "$SCRIPT_DIR/now-playing.sh" "$HOME/.tmux/now-playing.sh"
  chmod +x "$SCRIPT_DIR/now-playing.sh"
fi

echo ""
echo "Done. To apply:"
echo "  - In a running tmux session: press Ctrl+a then r"
echo "  - Or start a fresh tmux session: tmux"
