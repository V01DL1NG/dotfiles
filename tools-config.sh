#!/usr/bin/env bash
set -euo pipefail

# Install terminal productivity tools via Homebrew

if ! command -v brew >/dev/null 2>&1; then
  echo "Error: Homebrew not found. Please install it first." >&2
  exit 1
fi

tools=(fzf bat lazygit btop zsh-autosuggestions zsh-syntax-highlighting)

for tool in "${tools[@]}"; do
  if brew list "$tool" &>/dev/null; then
    echo "$tool already installed"
  else
    echo "Installing $tool via Homebrew..."
    brew install "$tool"
  fi
done

# fzf installs keybindings and completion separately
if command -v fzf >/dev/null 2>&1; then
  echo "fzf keybindings will be loaded via .zshrc"
fi

echo ""
echo "Done. Tools installed:"
echo "  fzf     - fuzzy finder (ctrl-r for history, ctrl-t for files)"
echo "  bat     - syntax-highlighted cat"
echo "  lazygit - terminal git UI (alias: lg)"
echo "  btop    - system monitor (alias: top)"
echo "  zsh-autosuggestions   - ghost text from history"
echo "  zsh-syntax-highlighting - command coloring"
echo ""
echo "Run: source ~/.zshrc  (or open a new terminal)"
