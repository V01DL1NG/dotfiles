#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

echo "=================================="
echo "  Shell Config - Full Setup"
echo "=================================="
echo ""
echo "Tip: to choose a shell profile (velvet / p10k-velvet) run:"
echo "  ./choose-profile.sh"
echo ""

scripts=(
  "setup.sh:Oh-My-Posh prompt"
  "eza-config.sh:Eza file listing"
  "tools-config.sh:Terminal tools (fzf, bat, lazygit, btop, zsh plugins)"
  "git-config.sh:Git config + delta"
  "tmux-config.sh:Tmux + now-playing"
  "nvim-config.sh:Neovim + LSP servers"
  "zshrc-config.sh:Zsh config"
  "iterm-config.sh:iTerm2 velvet theme"
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

echo ""
echo "=================================="
echo "  Setup complete!"
echo "=================================="
echo ""
echo "Next steps:"
echo "  1. Run: source ~/.zshrc"
echo "  2. Open neovim — plugins auto-install on first launch"
echo "  3. In tmux, press Ctrl+a r to reload config"
echo "  4. In iTerm2, set 'Velvet' as default profile"
echo "  5. Generate SSH key: ssh-keygen -t ed25519"
