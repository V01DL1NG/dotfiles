#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=platform.sh
. "$SCRIPT_DIR/platform.sh"

echo "=================================="
echo "  Shell Config - Full Setup"
echo "=================================="
echo ""
echo "Platform: $DOTFILES_OS (package manager: $PKG_MGR)"
echo ""
echo "Tip: to choose a shell profile (velvet / p10k-velvet) run:"
echo "  ./choose-profile.sh"
echo ""

scripts=(
  "eza-config.sh:Eza file listing"
  "tools-config.sh:Terminal tools (fzf, bat, lazygit, btop, zsh plugins)"
  "git-config.sh:Git config + delta"
  "tmux-config.sh:Tmux + now-playing"
  "nvim-config.sh:Neovim + LSP servers"
  "zshrc-config.sh:Zsh config"
  "ssh-config.sh:SSH config"
)

for entry in "${scripts[@]}"; do
  script="${entry%%:*}"
  desc="${entry#*:}"

  echo ""
  echo "-- [$desc] --"

  if [ -f "$SCRIPT_DIR/$script" ]; then
    bash "$SCRIPT_DIR/$script"
  else
    echo "Warning: $script not found, skipping."
  fi
done

# setup.sh — skip on linux-server (no GUI prompt on headless)
echo ""
if [ "$DOTFILES_OS" = "linux-server" ]; then
  echo "-- [Oh-My-Posh prompt] --"
  echo "Skipping setup.sh (headless server — use minimal profile)"
else
  echo "-- [Oh-My-Posh prompt] --"
  if [ -f "$SCRIPT_DIR/setup.sh" ]; then
    bash "$SCRIPT_DIR/setup.sh"
  else
    echo "Warning: setup.sh not found, skipping."
  fi
fi

# iterm-config.sh — macOS only (iTerm2 does not exist on Linux)
echo ""
if [ "$DOTFILES_OS" != "macos" ]; then
  echo "-- [iTerm2 velvet theme] --"
  echo "Skipping iterm-config.sh (macOS only)"
else
  echo "-- [iTerm2 velvet theme] --"
  if [ -f "$SCRIPT_DIR/iterm-config.sh" ]; then
    bash "$SCRIPT_DIR/iterm-config.sh"
  else
    echo "Warning: iterm-config.sh not found, skipping."
  fi
fi

# macos-defaults.sh — macOS only, interactive by design
# (bootstrap.sh passes 'minimal' for automated runs)
echo ""
if [ "$DOTFILES_OS" = "macos" ]; then
  echo "-- [macOS System Defaults] --"
  if [ -f "$SCRIPT_DIR/macos-defaults.sh" ]; then
    bash "$SCRIPT_DIR/macos-defaults.sh"
  else
    echo "Warning: macos-defaults.sh not found, skipping."
  fi
fi

echo ""
echo "=================================="
echo "  Setup complete!"
echo "=================================="
echo ""
echo "Next steps:"
echo "  1. Run: source ~/.zshrc"
echo "  2. Open neovim — plugins auto-install on first launch"
echo "  3. In tmux, press Ctrl+a r to reload config"
if [ "$DOTFILES_OS" = "macos" ]; then
  echo "  4. In iTerm2, set 'Velvet' as default profile"
fi
echo "  5. Generate SSH key: ssh-keygen -t ed25519"
