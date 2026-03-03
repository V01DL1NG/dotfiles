#!/usr/bin/env bash
set -euo pipefail

ZSHRC="$HOME/.zshrc"
BACKUP="$ZSHRC.backup.$(date +%Y%m%d%H%M%S)"

echo "Backing up $ZSHRC to $BACKUP"
if [ -f "$ZSHRC" ]; then
  cp "$ZSHRC" "$BACKUP"
fi

# Try to install oh-my-posh via Homebrew if it's not installed
if ! command -v oh-my-posh >/dev/null 2>&1; then
  if command -v brew >/dev/null 2>&1; then
    echo "Installing oh-my-posh via Homebrew..."
    brew install jandedobbeleer/oh-my-posh/oh-my-posh || brew install jandedobbeleer/oh-my-posh || true
  else
    echo "Homebrew not found. Please install Homebrew or oh-my-posh manually: https://ohmyposh.dev/docs/installation"
  fi
else
  echo "oh-my-posh already installed."
fi

# Ensure config directory and download a theme if possible
OMPPATH="$HOME/.config/oh-my-posh"
mkdir -p "$OMPPATH"
THEME="$OMPPATH/clean-detailed.omp.json"
if [ ! -f "$THEME" ]; then
  if command -v curl >/dev/null 2>&1; then
    echo "Downloading clean-detailed theme to $THEME..."
    curl -fsSL -o "$THEME" "https://raw.githubusercontent.com/JanDeDobbeleer/oh-my-posh/main/themes/clean-detailed.omp.json" || echo "Failed to download theme; place a theme at $THEME"
  else
    echo "curl not found; please download a theme into $THEME"
  fi
fi

# Append init and aliases to .zshrc idempotently
if ! grep -q "oh-my-posh init zsh" "$ZSHRC" 2>/dev/null; then
  cat >> "$ZSHRC" <<'EOF'

# --- oh-my-posh: start ---
# Initialize Oh My Posh (prompt theming)
if command -v oh-my-posh >/dev/null 2>&1; then
  eval "$(oh-my-posh init zsh --config \"$HOME/.config/oh-my-posh/clean-detailed.omp.json\")"
fi

# Handy aliases
alias ll='ls -laF'
alias la='ls -A'
alias l='ls -CF'
alias gs='git status'
alias ga='git add'
alias gc='git commit -v'
alias gp='git push'
alias gpl='git pull'
alias ..='cd ..'
# --- oh-my-posh: end ---
EOF
  echo "Appended oh-my-posh init and aliases to $ZSHRC"
else
  echo "oh-my-posh initialization already present in $ZSHRC; skipping append"
fi

echo "Done. To apply changes run: source $ZSHRC or open a new terminal session."
