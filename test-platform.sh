#!/usr/bin/env bash
# test-platform.sh — unit tests for platform.sh detection library
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PASS=0; FAIL=0

pass()    { echo "  ✓ $1"; PASS=$((PASS + 1)); }
fail()    { echo "  ✗ $1"; FAIL=$((FAIL + 1)); }
section() { echo ""; echo "── $1"; }

# Source platform.sh with forced overrides, capture key vars as KEY=value pairs
source_platform() {
  local force_os="${1:-}" force_pm="${2:-}"
  (
    export _DOTFILES_FORCE_OS="$force_os"
    export _DOTFILES_FORCE_PKG_MGR="$force_pm"
    # shellcheck source=platform.sh
    . "$SCRIPT_DIR/platform.sh"
    printf 'OS=%s PKG_MGR=%s\n' "$DOTFILES_OS" "$PKG_MGR"
    printf 'PKG_INSTALL=%s\n' "$PKG_INSTALL"
    printf 'SED=%s\n' "$SED_INPLACE"
    printf 'B64=%s\n' "$BASE64_DECODE"
    printf 'CLIPBOARD=%s\n' "$DOTFILES_CLIPBOARD"
  )
}

check() {
  local label="$1" actual="$2" expected="$3"
  if [ "$actual" = "$expected" ]; then
    pass "$label"
  else
    fail "$label: expected '$expected', got '$actual'"
  fi
}

# Source platform.sh in a subshell and call pkg() with a given PM
pkg_result() {
  local force_pm="$1" name="$2"
  (
    export _DOTFILES_FORCE_OS="linux-server"
    export _DOTFILES_FORCE_PKG_MGR="$force_pm"
    . "$SCRIPT_DIR/platform.sh"
    pkg "$name"
  )
}

# ── OS detection ──────────────────────────────────────────────────────────────
section "OS + PKG_MGR mapping"

out="$(source_platform macos brew)"
check "macos → DOTFILES_OS"  "$(echo "$out" | grep '^OS=' | cut -d= -f2 | awk '{print $1}')" "macos"
check "macos → PKG_MGR"      "$(echo "$out" | grep '^OS=' | grep -o 'PKG_MGR=[^ ]*' | cut -d= -f2)" "brew"
check "macos → PKG_INSTALL"  "$(echo "$out" | grep '^PKG_INSTALL=' | cut -d= -f2-)" "brew install"
check "macos → SED_INPLACE"  "$(echo "$out" | grep '^SED=' | cut -d= -f2-)" "sed -i ''"
check "macos → BASE64_DECODE" "$(echo "$out" | grep '^B64=' | cut -d= -f2-)" "base64 -D"

out="$(source_platform linux-server apt)"
check "linux → SED_INPLACE"   "$(echo "$out" | grep '^SED=' | cut -d= -f2-)" "sed -i"
check "linux → BASE64_DECODE" "$(echo "$out" | grep '^B64=' | cut -d= -f2-)" "base64 -d"

section "DOTFILES_CLIPBOARD"
# macOS should always be pbcopy
out="$(source_platform macos brew)"
check "macos → DOTFILES_CLIPBOARD" \
  "$(echo "$out" | grep '^CLIPBOARD=' | cut -d= -f2-)" "pbcopy"

# linux-server should always be empty
out="$(source_platform linux-server apt)"
check "linux-server → DOTFILES_CLIPBOARD empty" \
  "$(echo "$out" | grep '^CLIPBOARD=' | cut -d= -f2-)" ""

out="$(source_platform linux-desktop apt)"
check "linux-desktop → DOTFILES_OS" "$(echo "$out" | grep '^OS=' | cut -d= -f2 | awk '{print $1}')" "linux-desktop"
check "linux-desktop/apt → PKG_INSTALL" \
  "$(echo "$out" | grep '^PKG_INSTALL=' | cut -d= -f2-)" "sudo apt-get install -y"

out="$(source_platform linux-server dnf)"
check "linux-server → DOTFILES_OS" "$(echo "$out" | grep '^OS=' | cut -d= -f2 | awk '{print $1}')" "linux-server"
check "linux-server/dnf → PKG_INSTALL" \
  "$(echo "$out" | grep '^PKG_INSTALL=' | cut -d= -f2-)" "sudo dnf install -y"

out="$(source_platform linux-server pacman)"
check "linux-server/pacman → PKG_INSTALL" \
  "$(echo "$out" | grep '^PKG_INSTALL=' | cut -d= -f2-)" "sudo pacman -S --noconfirm"

out="$(source_platform linux-server unknown)"
check "unknown PM → PKG_INSTALL=false" \
  "$(echo "$out" | grep '^PKG_INSTALL=' | cut -d= -f2-)" "false"

# ── pkg() helper ──────────────────────────────────────────────────────────────
section "pkg() — fd name mapping"
check "brew fd"    "$(pkg_result brew   fd)" "fd"
check "apt fd"     "$(pkg_result apt    fd)" "fd-find"
check "dnf fd"     "$(pkg_result dnf    fd)" "fd-find"
check "pacman fd"  "$(pkg_result pacman fd)" "fd"

section "pkg() — delta (optional on apt)"
check "brew delta"   "$(pkg_result brew   delta)" "git-delta"
check "apt delta"    "$(pkg_result apt    delta)" ""
check "dnf delta"    "$(pkg_result dnf    delta)" "git-delta"
check "pacman delta" "$(pkg_result pacman delta)" "git-delta"

section "pkg() — lazygit (optional on apt)"
check "brew lazygit"   "$(pkg_result brew   lazygit)" "lazygit"
check "apt lazygit"    "$(pkg_result apt    lazygit)" ""
check "dnf lazygit"    "$(pkg_result dnf    lazygit)" "lazygit"
check "pacman lazygit" "$(pkg_result pacman lazygit)" "lazygit"

section "pkg() — atuin (optional on apt/dnf)"
check "brew atuin"   "$(pkg_result brew   atuin)" "atuin"
check "apt atuin"    "$(pkg_result apt    atuin)" ""
check "dnf atuin"    "$(pkg_result dnf    atuin)" ""
check "pacman atuin" "$(pkg_result pacman atuin)" "atuin"

section "pkg() — neovim (available everywhere)"
check "brew neovim"   "$(pkg_result brew   neovim)" "neovim"
check "apt neovim"    "$(pkg_result apt    neovim)" "neovim"
check "dnf neovim"    "$(pkg_result dnf    neovim)" "neovim"
check "pacman neovim" "$(pkg_result pacman neovim)" "neovim"

section "pkg() — bat (available everywhere)"
check "brew bat"   "$(pkg_result brew   bat)" "bat"
check "apt bat"    "$(pkg_result apt    bat)" "bat"
check "dnf bat"    "$(pkg_result dnf    bat)" "bat"
check "pacman bat" "$(pkg_result pacman bat)" "bat"

section "pkg() — eza (available everywhere)"
check "brew eza"   "$(pkg_result brew   eza)" "eza"
check "apt eza"    "$(pkg_result apt    eza)" "eza"
check "dnf eza"    "$(pkg_result dnf    eza)" "eza"
check "pacman eza" "$(pkg_result pacman eza)" "eza"

section "pkg() — fzf (available everywhere)"
check "brew fzf"   "$(pkg_result brew   fzf)" "fzf"
check "apt fzf"    "$(pkg_result apt    fzf)" "fzf"
check "dnf fzf"    "$(pkg_result dnf    fzf)" "fzf"
check "pacman fzf" "$(pkg_result pacman fzf)" "fzf"

section "pkg() — zoxide (available everywhere)"
check "brew zoxide"   "$(pkg_result brew   zoxide)" "zoxide"
check "apt zoxide"    "$(pkg_result apt    zoxide)" "zoxide"
check "dnf zoxide"    "$(pkg_result dnf    zoxide)" "zoxide"
check "pacman zoxide" "$(pkg_result pacman zoxide)" "zoxide"

# ── Summary ───────────────────────────────────────────────────────────────────
echo ""
echo "────────────────────────────────"
printf "  passed: %d  failed: %d\n" "$PASS" "$FAIL"
echo "────────────────────────────────"
echo ""
[ "$FAIL" -eq 0 ]
