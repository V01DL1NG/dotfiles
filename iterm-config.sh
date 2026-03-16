#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=platform.sh
. "$SCRIPT_DIR/platform.sh"

if [ "$DOTFILES_OS" != "macos" ]; then
  echo "Skipping iTerm2 config (macOS only)"
  exit 0
fi

DYNAMIC_PROFILES_DIR="$HOME/Library/Application Support/iTerm2/DynamicProfiles"

# Check if iTerm2 is installed
if [ ! -d "/Applications/iTerm.app" ]; then
  echo "Error: iTerm2 is not installed." >&2
  exit 1
fi

# Create DynamicProfiles directory if it doesn't exist
mkdir -p "$DYNAMIC_PROFILES_DIR"

# Symlink profile into place (iTerm2 watches this directory live)
echo "Linking Velvet iTerm2 profile..."
ln -sf "$SCRIPT_DIR/velvet.iterm2profile.json" "$DYNAMIC_PROFILES_DIR/velvet.json"

echo ""
echo "Done. To activate:"
echo "  1. Open iTerm2 > Preferences > Profiles"
echo "  2. Select 'Velvet'"
echo "  3. Click 'Other Actions...' > 'Set as Default'"
