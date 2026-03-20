#!/usr/bin/env bash
# ============================================================================
# touchid-sudo.sh — enable TouchID for sudo (iTerm2 + tmux)
#
# Usage:
#   ./touchid-sudo.sh              # install
#   ./touchid-sudo.sh --revert     # clean uninstall (requires working sudo)
#   ./touchid-sudo.sh --status     # show current state
#   ./touchid-sudo.sh --dry-run    # show what would be written, no changes
# ============================================================================
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=platform.sh
. "$SCRIPT_DIR/platform.sh"

# ── Colors ────────────────────────────────────────────────────────────────────
BOLD='\033[1m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
RED='\033[0;31m'
CYAN='\033[0;36m'
RESET='\033[0m'

info()    { echo -e "  ${CYAN}${1}${RESET}"; }
success() { echo -e "  ${GREEN}✓${RESET}  ${1}"; }
warn()    { echo -e "  ${YELLOW}!${RESET}  ${1}"; }
error()   { echo -e "  ${RED}✗${RESET}  ${1}" >&2; }
header()  { echo -e "\n${BOLD}${1}${RESET}"; }

# ── macOS guard ───────────────────────────────────────────────────────────────
if [ "$DOTFILES_OS" != "macos" ]; then
  info "Skipping TouchID sudo setup (macOS only)"
  exit 0
fi

# ── Arg parsing ───────────────────────────────────────────────────────────────
COMMAND="install"
case "${1:-}" in
  --revert)   COMMAND="revert" ;;
  --status)   COMMAND="status" ;;
  --dry-run)  COMMAND="dry-run" ;;
  "")         COMMAND="install" ;;
  *)
    echo "Usage: $0 [--revert|--status|--dry-run]" >&2
    exit 1
    ;;
esac

# ── Helpers ───────────────────────────────────────────────────────────────────
BACKUP_DIR="$HOME/.dotfiles-backups"
DAEMON_LABEL="com.dotfiles.touchid-sudo-revert"
DAEMON_PLIST="/Library/LaunchDaemons/${DAEMON_LABEL}.plist"
PAM_SUDO_LOCAL="/etc/pam.d/sudo_local"

brew_prefix() {
  brew --prefix 2>/dev/null
}

pam_reattach_path() {
  echo "$(brew_prefix)/lib/pam/pam_reattach.so"
}

plist_content() {
  cat <<EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN"
  "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>Label</key>
    <string>${DAEMON_LABEL}</string>
    <key>WatchPaths</key>
    <array>
        <string>/private/tmp/.revert-touchid-sudo</string>
    </array>
    <key>ProgramArguments</key>
    <array>
        <string>/bin/sh</string>
        <string>-c</string>
        <string>rm -f ${PAM_SUDO_LOCAL} /private/tmp/.revert-touchid-sudo</string>
    </array>
    <key>RunAtLoad</key>
    <false/>
</dict>
</plist>
EOF
}

sudo_local_content() {
  local reattach_path
  reattach_path="$(pam_reattach_path)"
  cat <<EOF
# sudo_local — managed by touchid-sudo.sh
# Emergency revert (no sudo needed): touch /tmp/.revert-touchid-sudo
auth       optional       ${reattach_path}
auth       sufficient     pam_tid.so
EOF
}

# ── dry-run ───────────────────────────────────────────────────────────────────
cmd_dry_run() {
  header "TouchID sudo — dry run (no changes made)"

  echo ""
  info "Would write to: ${PAM_SUDO_LOCAL}"
  echo "────────────────────────────────────────────"
  sudo_local_content
  echo "────────────────────────────────────────────"

  echo ""
  info "Would write to: ${DAEMON_PLIST}"
  echo "────────────────────────────────────────────"
  plist_content
  echo "────────────────────────────────────────────"
}

# ── status ────────────────────────────────────────────────────────────────────
cmd_status() {
  header "TouchID sudo — status"

  echo ""
  if [ -f "$PAM_SUDO_LOCAL" ]; then
    success "sudo_local installed at ${PAM_SUDO_LOCAL}"
    echo ""
    cat "$PAM_SUDO_LOCAL"
    echo ""
  else
    warn "sudo_local not installed (${PAM_SUDO_LOCAL} missing)"
  fi

  local reattach_path
  reattach_path="$(pam_reattach_path)"
  if [ -f "$reattach_path" ]; then
    success "pam_reattach.so found at ${reattach_path}"
  else
    warn "pam_reattach.so not found at ${reattach_path} — run: brew install pam-reattach"
  fi

  if launchctl list "$DAEMON_LABEL" >/dev/null 2>&1; then
    success "LaunchDaemon loaded (${DAEMON_LABEL})"
  else
    warn "LaunchDaemon not loaded"
  fi

  echo ""
  info "To test sudo:  sudo echo ok"
}

# ── install ───────────────────────────────────────────────────────────────────
cmd_install() {
  header "TouchID sudo — install"
  echo ""

  # Step 1: install pam-reattach if needed
  local reattach_path
  reattach_path="$(pam_reattach_path)"
  if [ ! -f "$reattach_path" ]; then
    info "Installing pam-reattach via Homebrew..."
    brew install pam-reattach
  fi

  # Step 2: verify path exists (abort before touching anything)
  if [ ! -f "$reattach_path" ]; then
    error "pam_reattach.so not found at ${reattach_path} after install — aborting"
    exit 1
  fi
  success "pam_reattach.so verified at ${reattach_path}"

  # Step 3: install LaunchDaemon (emergency revert — must happen before PAM change)
  if launchctl list "$DAEMON_LABEL" >/dev/null 2>&1; then
    success "LaunchDaemon already loaded — skipping bootstrap"
  else
    info "Installing emergency revert LaunchDaemon..."
    local tmp_plist
    tmp_plist="$(mktemp)"
    plist_content > "$tmp_plist"
    sudo cp "$tmp_plist" "$DAEMON_PLIST"
    rm -f "$tmp_plist"
    sudo chown root:wheel "$DAEMON_PLIST"
    sudo chmod 644 "$DAEMON_PLIST"
    sudo launchctl bootstrap system "$DAEMON_PLIST"
    success "LaunchDaemon installed and loaded"
  fi

  # Step 4: backup existing sudo_local if present
  mkdir -p "$BACKUP_DIR"
  if [ -f "$PAM_SUDO_LOCAL" ]; then
    cp "$PAM_SUDO_LOCAL" "$BACKUP_DIR/sudo_local.bak"
    info "Backed up existing sudo_local to ${BACKUP_DIR}/sudo_local.bak"
  fi

  # Step 5: write sudo_local atomically
  local tmp_pam
  tmp_pam="$(mktemp)"
  chmod 600 "$tmp_pam"
  sudo_local_content > "$tmp_pam"

  # Verify content before copying
  if ! grep -q "optional.*pam_reattach.so" "$tmp_pam"; then
    rm -f "$tmp_pam"
    error "Content verification failed: pam_reattach.so line missing — aborting"
    exit 1
  fi
  if ! grep -q "sufficient.*pam_tid.so" "$tmp_pam"; then
    rm -f "$tmp_pam"
    error "Content verification failed: pam_tid.so line missing — aborting"
    exit 1
  fi

  sudo cp "$tmp_pam" "$PAM_SUDO_LOCAL"
  sudo chmod 644 "$PAM_SUDO_LOCAL"
  rm -f "$tmp_pam"

  # Step 6: verify post-copy content
  if ! grep -q "optional.*pam_reattach.so" "$PAM_SUDO_LOCAL"; then
    error "Post-copy verification failed — triggering emergency revert"
    touch /tmp/.revert-touchid-sudo
    exit 1
  fi
  if ! grep -q "sufficient.*pam_tid.so" "$PAM_SUDO_LOCAL"; then
    error "Post-copy verification failed — triggering emergency revert"
    touch /tmp/.revert-touchid-sudo
    exit 1
  fi

  success "sudo_local written and verified"

  # Step 7: print success + emergency instructions
  print_success
}

# ── revert ────────────────────────────────────────────────────────────────────
cmd_revert() {
  header "TouchID sudo — revert"
  echo ""
  warn "This requires working sudo."
  echo ""

  if [ -f "$PAM_SUDO_LOCAL" ]; then
    sudo rm -f "$PAM_SUDO_LOCAL"
    success "Removed ${PAM_SUDO_LOCAL}"
  else
    info "sudo_local not present — nothing to remove"
  fi

  if launchctl list "$DAEMON_LABEL" >/dev/null 2>&1; then
    sudo launchctl bootout system "$DAEMON_PLIST" 2>/dev/null || true
    success "LaunchDaemon unloaded"
  fi

  if [ -f "$DAEMON_PLIST" ]; then
    sudo rm -f "$DAEMON_PLIST"
    success "Removed ${DAEMON_PLIST}"
  fi

  echo ""
  success "Reverted. Run: sudo echo ok — to confirm sudo is clean"
}

# ── post-install message ──────────────────────────────────────────────────────
print_success() {
  echo ""
  success "TouchID sudo installed."
  echo ""
  info "To test:"
  echo "    Native terminal:  sudo echo ok"
  echo "    tmux session:     open a new tmux window, then: sudo echo ok"
  echo ""
  echo -e "  ${BOLD}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${RESET}"
  echo -e "  ${RED}${BOLD}EMERGENCY REVERT — no sudo, no osascript, no GUI needed:${RESET}"
  echo "    touch /tmp/.revert-touchid-sudo"
  echo ""
  echo "    Works even with completely broken sudo."
  echo "    If nothing happens in 30s:"
  echo "    launchctl kickstart system/${DAEMON_LABEL}"
  echo ""
  echo "  Clean uninstall (when sudo is working):"
  echo "    ./touchid-sudo.sh --revert"
  echo -e "  ${BOLD}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${RESET}"
  echo ""
}

# ── Main dispatch ─────────────────────────────────────────────────────────────
case "$COMMAND" in
  install)  cmd_install ;;
  revert)   cmd_revert ;;
  status)   cmd_status ;;
  dry-run)  cmd_dry_run ;;
esac
