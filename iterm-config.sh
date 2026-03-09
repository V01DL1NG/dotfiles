#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DYNAMIC_PROFILES_DIR="$HOME/Library/Application Support/iTerm2/DynamicProfiles"

# Check if iTerm2 is installed
if [ ! -d "/Applications/iTerm.app" ]; then
  echo "Error: iTerm2 is not installed." >&2
  exit 1
fi

# Create DynamicProfiles directory if it doesn't exist
mkdir -p "$DYNAMIC_PROFILES_DIR"

# Copy profile into place
echo "Installing Velvet iTerm2 profile..."
cp "$SCRIPT_DIR/velvet.iterm2profile.json" "$DYNAMIC_PROFILES_DIR/velvet.json"

echo ""
echo "Done. To activate:"
echo "  1. Open iTerm2 > Preferences > Profiles"
echo "  2. Select 'Velvet'"
echo "  3. Click 'Other Actions...' > 'Set as Default'"
