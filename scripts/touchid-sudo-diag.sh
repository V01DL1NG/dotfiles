#!/usr/bin/env bash
# ============================================================================
# touchid-sudo-diag.sh — diagnostic for TouchID sudo + tmux failures
#
# Run this on an endpoint where `sudo` in tmux doesn't prompt TouchID.
# Paste the full output back — no fix is applied, read-only.
# ============================================================================
set -uo pipefail

echo "═══ macOS version ═══"
sw_vers
echo

echo "═══ /etc/pam.d/sudo ═══"
if [ -f /etc/pam.d/sudo ]; then
  cat /etc/pam.d/sudo
  echo
  if grep -q "include.*sudo_local" /etc/pam.d/sudo; then
    echo "[OK] sudo_local is included"
  else
    echo "[MISSING] no 'auth include sudo_local' line — sudo_local will be ignored"
  fi
else
  echo "[MISSING] /etc/pam.d/sudo not found"
fi
echo

echo "═══ /etc/pam.d/sudo_local ═══"
if [ -f /etc/pam.d/sudo_local ]; then
  cat /etc/pam.d/sudo_local
else
  echo "[MISSING] not installed"
fi
echo

echo "═══ pam_reattach.so ═══"
BREW_PREFIX="$(brew --prefix 2>/dev/null)"
REATTACH="$BREW_PREFIX/lib/pam/pam_reattach.so"
if [ -f "$REATTACH" ]; then
  ls -la "$REATTACH"
  echo "brew info:"
  brew info pam-reattach 2>/dev/null | head -5
else
  echo "[MISSING] $REATTACH not found"
fi
echo

echo "═══ tmux ═══"
tmux -V 2>/dev/null || echo "[MISSING] tmux not found"
echo "In tmux session: ${TMUX:+yes}${TMUX:-no}"
echo

echo "═══ Session context ═══"
echo "SSH_TTY: ${SSH_TTY:-<not set>}"
echo "SSH_CONNECTION: ${SSH_CONNECTION:-<not set>}"
echo "TERM_PROGRAM: ${TERM_PROGRAM:-<not set>}"
echo

echo "═══ LaunchDaemon (emergency revert) ═══"
launchctl list com.dotfiles.touchid-sudo-revert 2>/dev/null && echo "[loaded]" || echo "[not loaded]"
echo

echo "═══ Live test ═══"
echo "Run manually inside tmux: sudo -k && sudo echo ok"
