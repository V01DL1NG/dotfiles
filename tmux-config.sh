#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=platform.sh
. "$SCRIPT_DIR/platform.sh"

# ── Argument parsing ──────────────────────────────────────────────────────────
DRY_RUN=false
for arg in "$@"; do
  case "$arg" in
    --dry-run) DRY_RUN=true ;;
  esac
done

# ── Colors (if not already defined by platform.sh) ───────────────────────────
BOLD='\033[1m'
PURPLE='\033[38;2;105;48;122m'
LAVENDER='\033[38;2;239;220;249m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
RESET='\033[0m'

info()    { echo -e "  ${LAVENDER}${1}${RESET}"; }
success() { echo -e "  ${GREEN}✓${RESET}  ${1}"; }
warn()    { echo -e "  ${YELLOW}!${RESET}  ${1}"; }
header()  { echo -e "\n${BOLD}${PURPLE}${1}${RESET}"; }

# ── run_cmd ───────────────────────────────────────────────────────────────────
# Wraps file-write operations for --dry-run support.
# In dry-run mode, prints the command instead of executing it.
run_cmd() {
  if [ "$DRY_RUN" = "true" ]; then
    echo "  $*"
  else
    "$@"
  fi
}

# ── is_enabled <key> ──────────────────────────────────────────────────────────
# Returns 0 if key is in ENABLED array, 1 otherwise.
is_enabled() {
  local key="$1" k
  for k in "${ENABLED[@]:-}"; do
    [ "$k" = "$key" ] && return 0
  done
  return 1
}

# ── write_to_local <text> ─────────────────────────────────────────────────────
# Appends text to LOCAL_CONF_OUT (string buffer) during write_local_conf().
write_to_local() { LOCAL_CONF_OUT+="${1}"$'\n'; }

# ── write_to_plugins <text> ───────────────────────────────────────────────────
# Appends text to PLUGINS_CONF_OUT (string buffer) during write_plugins_conf().
write_to_plugins() { PLUGINS_CONF_OUT+="${1}"$'\n'; }

# ── Source-only guard (for testing) ──────────────────────────────────────────
# Set TMUX_CONFIG_SOURCE_ONLY=1 to source this file without executing install logic.
if [ "${TMUX_CONFIG_SOURCE_ONLY:-}" != "1" ]; then

TMUX_CONF="$HOME/.tmux.conf"
BACKUP="$TMUX_CONF.backup.$(date +%Y%m%d%H%M%S)"

# Install tmux if missing
if ! command -v tmux >/dev/null 2>&1; then
  echo "Installing tmux..."
  $PKG_INSTALL "$(pkg tmux)"
else
  echo "tmux already installed: $(tmux -V)"
fi

# Install nowplaying-cli (macOS only — no Linux equivalent)
if [ "$DOTFILES_OS" = "macos" ]; then
  if ! command -v nowplaying-cli >/dev/null 2>&1; then
    echo "Installing nowplaying-cli via Homebrew..."
    brew install nowplaying-cli
  else
    echo "nowplaying-cli already installed"
  fi
fi

# Back up existing config if it's a regular file (not already a symlink)
if [ -f "$TMUX_CONF" ] && [ ! -L "$TMUX_CONF" ]; then
  echo "Backing up $TMUX_CONF to $BACKUP"
  cp "$TMUX_CONF" "$BACKUP"
fi

# Symlink configs into place
echo "Linking tmux.conf → $TMUX_CONF"
ln -sf "$SCRIPT_DIR/tmux.conf" "$TMUX_CONF"

if [ "$DOTFILES_OS" = "macos" ]; then
  mkdir -p "$HOME/.tmux"
  echo "Linking now-playing.sh → $HOME/.tmux/now-playing.sh"
  ln -sf "$SCRIPT_DIR/now-playing.sh" "$HOME/.tmux/now-playing.sh"
  chmod +x "$SCRIPT_DIR/now-playing.sh"
fi

echo ""
echo "Done. To apply:"
echo "  - In a running tmux session: press Ctrl+a then r"
echo "  - Or start a fresh tmux session: tmux"

fi
