#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
GITCONFIG="$HOME/.gitconfig"
BACKUP="$GITCONFIG.backup.$(date +%Y%m%d%H%M%S)"

# Install delta via Homebrew if missing
if ! command -v delta >/dev/null 2>&1; then
  if command -v brew >/dev/null 2>&1; then
    echo "Installing git-delta via Homebrew..."
    brew install git-delta
  else
    echo "Warning: delta not found. Diffs will use default pager." >&2
  fi
else
  echo "delta already installed"
fi

# Back up existing config
if [ -f "$GITCONFIG" ]; then
  echo "Backing up $GITCONFIG to $BACKUP"
  cp "$GITCONFIG" "$BACKUP"
fi

# Preserve existing [user] section
USER_NAME=$(git config --global user.name 2>/dev/null || true)
USER_EMAIL=$(git config --global user.email 2>/dev/null || true)

# Copy config into place
echo "Installing gitconfig to $GITCONFIG"
cp "$SCRIPT_DIR/gitconfig" "$GITCONFIG"

# Restore user identity
if [ -n "$USER_NAME" ]; then
  git config --global user.name "$USER_NAME"
fi
if [ -n "$USER_EMAIL" ]; then
  git config --global user.email "$USER_EMAIL"
fi

echo ""
echo "Done. Try these commands:"
echo "  git lg         - pretty log graph"
echo "  git st         - short status"
echo "  git diff       - side-by-side with syntax highlighting"
echo "  git amend      - amend last commit (keep message)"
echo "  git undo       - undo last commit (keep changes)"
echo "  git branches   - branches sorted by recent activity"
echo "  git last       - show last commit details"
