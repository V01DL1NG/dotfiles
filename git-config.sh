#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=platform.sh
. "$SCRIPT_DIR/platform.sh"

GITCONFIG="$HOME/.gitconfig"
BACKUP="$GITCONFIG.backup.$(date +%Y%m%d%H%M%S)"

# Install git if missing
if ! command -v git >/dev/null 2>&1; then
  echo "Installing git..."
  $PKG_INSTALL "$(pkg git)"
else
  echo "git already installed: $(git --version)"
fi

# Install delta (optional — not available in all repos)
if ! command -v delta >/dev/null 2>&1; then
  _p="$(pkg delta)"; if [ -n "$_p" ]; then
    echo "Installing git-delta..."
    $PKG_INSTALL "$_p"
  else
    echo "Note: git-delta is not available via $PKG_MGR — using plain git diff"
  fi
else
  echo "delta already installed"
fi

# Back up existing config if it's a regular file (not already a symlink)
if [ -f "$GITCONFIG" ] && [ ! -L "$GITCONFIG" ]; then
  echo "Backing up $GITCONFIG to $BACKUP"
  cp "$GITCONFIG" "$BACKUP"
fi

# Preserve existing [user] section
USER_NAME=$(git config --global user.name 2>/dev/null || true)
USER_EMAIL=$(git config --global user.email 2>/dev/null || true)

# Symlink config into place
echo "Linking gitconfig → $GITCONFIG"
ln -sf "$SCRIPT_DIR/gitconfig" "$GITCONFIG"

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
