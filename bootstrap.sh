#!/usr/bin/env bash
# ============================================================================
# bootstrap.sh — new Mac setup script, curl-installable
#
# Usage:
#   curl -fsSL https://raw.githubusercontent.com/V01DL1NG/dotfiles/master/bootstrap.sh | bash
#   REPO_URL=https://github.com/you/dotfiles.git bash bootstrap.sh
# ============================================================================

# ── TTY redirect (must come before set -euo pipefail) ────────────────────────
# When piped from curl, stdin is the script itself. Redirect stdin from the
# terminal so interactive prompts work correctly.
if [ ! -t 0 ]; then
  exec </dev/tty
fi

set -euo pipefail

# ── Env-overridable config ────────────────────────────────────────────────────
REPO_URL="${REPO_URL:-https://github.com/V01DL1NG/dotfiles.git}"
REPO_DIR="${REPO_DIR:-$HOME/code/dotfiles}"

# ── Colors ────────────────────────────────────────────────────────────────────
BOLD='\033[1m'
DIM='\033[2m'
PURPLE='\033[38;2;105;48;122m'
LAVENDER='\033[38;2;239;220;249m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
RED='\033[0;31m'
RESET='\033[0m'

info()    { echo -e "  ${LAVENDER}${1}${RESET}"; }
success() { echo -e "  ${GREEN}✓${RESET}  ${1}"; }
warn()    { echo -e "  ${YELLOW}!${RESET}  ${1}"; }
error()   { echo -e "  ${RED}✗${RESET}  ${1}" >&2; }
header()  { echo -e "\n${BOLD}${PURPLE}${1}${RESET}"; }

# ── Banner ────────────────────────────────────────────────────────────────────
echo ""
echo -e "${BOLD}${PURPLE}╔══════════════════════════════════════════════════╗${RESET}"
echo -e "${BOLD}${PURPLE}║           Dotfiles Bootstrap                     ║${RESET}"
echo -e "${BOLD}${PURPLE}║           New Mac Setup                          ║${RESET}"
echo -e "${BOLD}${PURPLE}╚══════════════════════════════════════════════════╝${RESET}"
echo ""
echo -e "  ${DIM}Repo: ${REPO_URL}${RESET}"
echo -e "  ${DIM}Dir:  ${REPO_DIR}${RESET}"
echo ""

# ── Step 1: Check macOS ───────────────────────────────────────────────────────
check_macos() {
  header "Checking macOS"

  if [ "$(uname)" != "Darwin" ]; then
    error "This script is for macOS only. Detected OS: $(uname)"
    exit 1
  fi

  local version
  version="$(sw_vers -productVersion)"
  local major
  major="$(echo "$version" | cut -d. -f1)"

  if [ "$major" -lt 12 ]; then
    error "macOS 12 (Monterey) or later is required. Detected: $version"
    exit 1
  fi

  success "macOS $version detected"
}

# ── Step 2: Check Xcode Command Line Tools ────────────────────────────────────
check_xcode_clt() {
  header "Checking Xcode Command Line Tools"

  if xcode-select -p >/dev/null 2>&1; then
    success "Xcode CLT found at $(xcode-select -p)"
    return
  fi

  error "Xcode Command Line Tools are not installed."
  echo ""
  echo -e "  ${BOLD}Please install them manually, then re-run this script:${RESET}"
  echo ""
  echo "    xcode-select --install"
  echo ""
  echo "  A dialog will appear. Click 'Install' and wait for it to complete."
  echo "  Then run this script again."
  echo ""
  exit 1
}

# ── Step 3: Install Homebrew ──────────────────────────────────────────────────
install_homebrew() {
  header "Checking Homebrew"

  if command -v brew >/dev/null 2>&1; then
    success "Homebrew already installed: $(brew --version | head -1)"
    return
  fi

  info "Installing Homebrew..."
  /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"

  # Add brew to PATH for the rest of this session
  eval "$(/opt/homebrew/bin/brew shellenv)" 2>/dev/null \
    || eval "$(/usr/local/bin/brew shellenv)" 2>/dev/null \
    || true

  if command -v brew >/dev/null 2>&1; then
    success "Homebrew installed: $(brew --version | head -1)"
  else
    error "Homebrew installation failed or brew not found in PATH."
    exit 1
  fi
}

# ── Step 4: Clone or update repo ──────────────────────────────────────────────
clone_repo() {
  header "Setting up dotfiles repo"

  if [ -d "$REPO_DIR" ]; then
    info "Repo already exists at $REPO_DIR — pulling latest..."
    git -C "$REPO_DIR" pull
    success "Repo updated"
  else
    info "Cloning $REPO_URL → $REPO_DIR"
    mkdir -p "$(dirname "$REPO_DIR")"
    git clone "$REPO_URL" "$REPO_DIR"
    success "Repo cloned"
  fi
}

# ── Step 5–6: Run profile selector then full install ─────────────────────────
run_setup() {
  header "Choosing shell profile"
  bash "$REPO_DIR/choose-profile.sh"

  header "Applying macOS system defaults (minimal preset)"
  bash "$REPO_DIR/macos-defaults.sh" minimal

  header "Running full install"
  bash "$REPO_DIR/install-all.sh"
}

# ── Step 7: Next steps summary ────────────────────────────────────────────────
print_next_steps() {
  echo ""
  echo -e "${BOLD}${GREEN}Bootstrap complete!${RESET}"
  echo ""
  echo -e "${BOLD}${PURPLE}Next steps:${RESET}"
  echo ""
  echo "  1.  source ~/.zshrc          (or open a new terminal)"
  echo "  2.  Open Neovim — plugins auto-install on first launch"
  echo "  3.  In tmux, press Ctrl+a r to reload config"
  echo "  4.  In iTerm2, set your chosen profile as default"
  echo "  5.  Generate an SSH key if needed:"
  echo "        ssh-keygen -t ed25519 -C \"you@example.com\""
  echo "  6.  Run doctor.sh anytime to check your setup:"
  echo "        $REPO_DIR/doctor.sh"
  echo ""
  echo -e "  ${DIM}Your dotfiles live at: ${REPO_DIR}${RESET}"
  echo ""
}

# ── Main ──────────────────────────────────────────────────────────────────────
main() {
  check_macos
  check_xcode_clt
  install_homebrew
  clone_repo
  run_setup
  print_next_steps
}

main
