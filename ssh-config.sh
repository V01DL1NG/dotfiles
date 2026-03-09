#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SSH_DIR="$HOME/.ssh"
SSH_CONFIG="$SSH_DIR/config"
BACKUP="$SSH_CONFIG.backup.$(date +%Y%m%d%H%M%S)"

# Create .ssh directory with correct permissions
mkdir -p "$SSH_DIR"
chmod 700 "$SSH_DIR"

# Create sockets directory for ControlMaster
mkdir -p "$SSH_DIR/sockets"

# Back up existing config
if [ -f "$SSH_CONFIG" ]; then
  echo "Backing up $SSH_CONFIG to $BACKUP"
  cp "$SSH_CONFIG" "$BACKUP"
fi

# Copy config into place
echo "Installing ssh_config to $SSH_CONFIG"
cp "$SCRIPT_DIR/ssh_config" "$SSH_CONFIG"
chmod 600 "$SSH_CONFIG"

# Generate ed25519 key if none exists
if [ ! -f "$SSH_DIR/id_ed25519" ]; then
  echo ""
  echo "No SSH key found. Generate one with:"
  echo "  ssh-keygen -t ed25519 -C \"your_email@example.com\""
else
  echo "SSH key found: $SSH_DIR/id_ed25519"
fi

echo ""
echo "Done. Features enabled:"
echo "  - macOS Keychain integration"
echo "  - Connection keepalive (60s interval)"
echo "  - Connection multiplexing (reuse connections)"
echo "  - Add host aliases in ~/.ssh/config"
