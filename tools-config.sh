#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=platform.sh
. "$SCRIPT_DIR/platform.sh"

# Install terminal productivity tools

# Required tools — always available on all supported package managers
$PKG_INSTALL "$(pkg fzf)"
$PKG_INSTALL "$(pkg bat)"
$PKG_INSTALL "$(pkg eza)"
$PKG_INSTALL "$(pkg fd)"
$PKG_INSTALL "$(pkg zoxide)"
$PKG_INSTALL "$(pkg btop)"
$PKG_INSTALL "$(pkg direnv)"

# zsh plugins — brew only; on Linux, these are loaded via the zsh plugin manager
if [ "$PKG_MGR" = "brew" ]; then
  $PKG_INSTALL zsh-autosuggestions
  $PKG_INSTALL zsh-syntax-highlighting
  $PKG_INSTALL zsh-history-substring-search
else
  echo "Skipping zsh plugins (managed via zsh plugin manager on Linux)"
fi

# Optional tools — may not be available in all package repos
_p="$(pkg atuin)"; [ -n "$_p" ] && $PKG_INSTALL "$_p" || echo "Skipping atuin (not available via $PKG_MGR — install manually from https://atuin.sh)"
_p="$(pkg lazygit)"; [ -n "$_p" ] && $PKG_INSTALL "$_p" || echo "Skipping lazygit (not available via $PKG_MGR — install via PPA or manually)"

# fzf installs keybindings and completion separately
if command -v fzf >/dev/null 2>&1; then
  echo "fzf keybindings will be loaded via .zshrc"
fi

# atuin sync setup — configure if ATUIN_KEY is present in the environment
# To enable cross-machine history sync:
#   1. Register: atuin register -u <user> -e <email> -p <password>
#   OR log in:   atuin login -u <user> -p <password>
#   2. Add to roles/secrets.zsh: export ATUIN_KEY="$(secret atuin-key)"
#   Sync runs automatically in the background on shell start (see zshrc).
if command -v atuin >/dev/null 2>&1; then
  echo ""
  echo "atuin installed. To enable cross-machine history sync:"
  echo "  atuin register -u <username> -e <email> -p <password>"
  echo "  Then add ATUIN_KEY to roles/secrets.zsh"
fi

echo ""
echo "Done. Tools installed:"
echo "  fzf                        - fuzzy finder (ctrl-r, ctrl-t, alt-c)"
echo "  bat                        - syntax-highlighted cat"
echo "  lazygit                    - terminal git UI (alias: lg)"
echo "  btop                       - system monitor (alias: top)"
echo "  fd                         - fast find, powers fzf file search"
echo "  zsh-autosuggestions        - ghost text from history"
echo "  zsh-syntax-highlighting    - command coloring"
echo "  zsh-history-substring-search - up/down matches anywhere in command"
echo "  zoxide                     - smart cd (z <partial-name>)"
echo "  atuin                      - history database (ctrl-r)"
echo "  direnv                     - auto-load .envrc per directory"
echo ""
echo "Run: source ~/.zshrc  (or open a new terminal)"
