#!/usr/bin/env bash
set -euo pipefail

# Install terminal productivity tools via Homebrew

if ! command -v brew >/dev/null 2>&1; then
  echo "Error: Homebrew not found. Please install it first." >&2
  exit 1
fi

tools=(
  fzf bat lazygit btop
  zsh-autosuggestions zsh-syntax-highlighting zsh-history-substring-search
  zoxide atuin direnv fd
)

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
echo "  fzf                        - fuzzy finder (ctrl-r, ctrl-t, alt-c)"
echo "  bat                        - syntax-highlighted cat"
echo "  lazygit                    - terminal git UI (alias: lg)"
echo "  btop                       - system monitor (alias: top)"
echo "  fd                         - fast find, powers fzf file search"
echo "  zsh-autosuggestions        - ghost text from history"
echo "  zsh-syntax-highlighting    - command coloring"
echo "  zsh-history-substring-search - up/down matches anywhere in command"
echo "  zoxide                     - smart cd (z <partial-name>)"
echo "  atuin                      - history database (ctrl-r)"
echo "  direnv                     - auto-load .envrc per directory"
echo ""
echo "Run: source ~/.zshrc  (or open a new terminal)"
