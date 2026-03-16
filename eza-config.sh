#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=platform.sh
. "$SCRIPT_DIR/platform.sh"

ZSHRC="$HOME/.zshrc"

# Ensure eza is installed
if ! command -v eza >/dev/null 2>&1; then
  echo "Installing eza..."
  $PKG_INSTALL "$(pkg eza)"
fi

# Ensure fd is installed (used by fzf for file listing)
if ! command -v fd >/dev/null 2>&1 && ! command -v fdfind >/dev/null 2>&1; then
  echo "Installing fd..."
  $PKG_INSTALL "$(pkg fd)"
fi

# Define aliases
ALIASES=(
    "alias ll='eza -la --icons'"
    "alias lt='eza --tree --icons --level=2'"
    "alias ls='eza --icons'"
)

# Backup existing .zshrc
if [ -f "$ZSHRC" ]; then
    cp "$ZSHRC" "${ZSHRC}-$(date +%Y%m%d%H%).bak"
    echo "Backup of .zshrc created."
fi

# Create .zshrc if it doesn't exist
if ! [ -f "$ZSHRC" ]; then
    echo "Creating shell config at $ZSHRC"
    touch "$ZSHRC"
fi

# Track if any aliases were added
added=false

# Check and add each alias
for alias_line in "${ALIASES[@]}"; do
    if ! grep -qF "$alias_line" "$ZSHRC"; then
        if [ "$added" = false ]; then
            echo "" >> "$ZSHRC"
            added=true
        fi
        echo "$alias_line" >> "$ZSHRC"
        echo "Added: $alias_line"
    else
        echo "Already exists: $alias_line"
    fi
done

if [ "$added" = true ]; then
    echo "Aliases added successfully to $ZSHRC"
else
    echo "All aliases already exist in $ZSHRC"
fi
