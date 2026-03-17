#!/usr/bin/env bash
# ============================================================================
# choose-profile.sh — interactive profile selector
#
# Copies config files locally (no symlinks) so each user can freely edit
# their own copy without touching the repo.
#
# Usage:
#   ./choose-profile.sh              # interactive picker
#   ./choose-profile.sh velvet       # install a specific profile directly
#   ./choose-profile.sh p10k-velvet
# ============================================================================
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=platform.sh
. "$SCRIPT_DIR/platform.sh"
PROFILES_DIR="$SCRIPT_DIR/profiles"
TIMESTAMP="$(date +%Y%m%d_%H%M%S)"

# ── Colors ───────────────────────────────────────────────────────────────────
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

# ── Profile metadata ─────────────────────────────────────────────────────────
# Each entry: "dir_name|Display Name|Short description|required_tool"
declare -a PROFILES=(
  "velvet|Velvet|Oh-My-Posh prompt · original velvet/sakura theme · powerline segments|oh-my-posh"
  "p10k-velvet|P10k Velvet|Powerlevel10k prompt · velvet color palette blend · faster instant prompt|powerlevel10k"
  "catppuccin|Catppuccin|Powerlevel10k prompt · Catppuccin Mocha palette · mauve accents|powerlevel10k"
  "minimal|Minimal|Plain zsh PROMPT · path + git branch · no prompt engine · server-friendly|"
)

# ── Helper: install Ghostty + Kitty configs if those terminals are present ───
install_terminal_configs() {
  local profile_dir="$1"

  # Ghostty
  if [ -d "/Applications/Ghostty.app" ] || command -v ghostty >/dev/null 2>&1; then
    local ghostty_dir="$HOME/.config/ghostty"
    mkdir -p "$ghostty_dir"
    backup_if_exists "$ghostty_dir/config"
    cp "$profile_dir/ghostty.conf" "$ghostty_dir/config"
    success "installed Ghostty config"
  fi

  # Kitty
  if [ -d "/Applications/kitty.app" ] || command -v kitty >/dev/null 2>&1; then
    local kitty_dir="$HOME/.config/kitty"
    mkdir -p "$kitty_dir"
    backup_if_exists "$kitty_dir/kitty.conf"
    cp "$profile_dir/kitty.conf" "$kitty_dir/kitty.conf"
    success "installed Kitty config"
  fi
}

# ── Helper: read prompt engine of currently installed profile ─────────────────
current_engine() {
  local state_file="$HOME/.config/dotfiles/state"
  [ -f "$state_file" ] || { echo ""; return; }
  local prof
  prof="$(grep '^profile=' "$state_file" 2>/dev/null | cut -d= -f2)"
  case "$prof" in
    velvet)               echo "oh-my-posh" ;;
    p10k-velvet|catppuccin) echo "p10k" ;;
    minimal)              echo "plain" ;;
    *)                    echo "" ;;
  esac
}

# ── Helper: write state hash file ────────────────────────────────────────────
write_state() {
  local profile_name="$1"
  local state_dir="$HOME/.config/dotfiles"
  mkdir -p "$state_dir"
  {
    echo "profile=$profile_name"
    echo "timestamp=$(date -u +%Y-%m-%dT%H:%M:%S)"
    echo "$HOME/.zshrc=$(shasum -a 256 "$HOME/.zshrc" 2>/dev/null | awk '{print "sha256:"$1}')"
  } > "$state_dir/state"
}

# ── Helper: back up a file if it exists ──────────────────────────────────────
backup_if_exists() {
  local target="$1"
  if [ -e "$target" ] || [ -L "$target" ]; then
    local backup="${target}.backup.${TIMESTAMP}"
    mv "$target" "$backup"
    warn "backed up existing $(basename "$target") → $backup"
  fi
}

# ── Helper: copy a file, creating parent dirs ─────────────────────────────────
install_file() {
  local src="$1"
  local dst="$2"
  mkdir -p "$(dirname "$dst")"
  backup_if_exists "$dst"
  cp "$src" "$dst"
  success "installed $(basename "$dst")"
}

# ── Install: velvet ───────────────────────────────────────────────────────────
install_velvet() {
  local profile_dir="$PROFILES_DIR/velvet"
  local _prev_engine; _prev_engine="$(current_engine)"

  header "Installing: Velvet"

  # Check / install oh-my-posh
  if ! command -v oh-my-posh >/dev/null 2>&1; then
    warn "oh-my-posh not found"
    if command -v brew >/dev/null 2>&1; then
      info "Installing oh-my-posh via Homebrew..."
      brew install jandedobbeleer/oh-my-posh/oh-my-posh
    elif command -v apt-get >/dev/null 2>&1 || command -v dnf >/dev/null 2>&1; then
      info "Installing oh-my-posh via official script..."
      curl -s https://ohmyposh.dev/install.sh | bash -s -- -d ~/.local/bin
    else
      echo "Warning: oh-my-posh not installed — install manually"
    fi
  fi

  # zshrc
  install_file "$profile_dir/zshrc" "$HOME/.zshrc"

  # Oh-My-Posh theme
  mkdir -p "$HOME/oh-my-posh"
  install_file "$profile_dir/velvet.omp.json" "$HOME/oh-my-posh/velvet.omp.json"

  # iTerm2 dynamic profile
  local iterm_dir="$HOME/Library/Application Support/iTerm2/DynamicProfiles"
  if [ -d "$(dirname "$iterm_dir")" ]; then
    mkdir -p "$iterm_dir"
    install_file "$profile_dir/iterm.json" "$iterm_dir/velvet.json"
    info "iTerm2 profiles available: Velvet, Velvet Glass"
  else
    warn "iTerm2 not detected — skipping iTerm2 profile"
  fi

  install_terminal_configs "$profile_dir"
  write_state "velvet"
  _post_install "Velvet" "oh-my-posh" "Velvet" "$_prev_engine"
}

# ── Install: p10k-velvet ──────────────────────────────────────────────────────
install_p10k_velvet() {
  local profile_dir="$PROFILES_DIR/p10k-velvet"
  local _prev_engine; _prev_engine="$(current_engine)"

  header "Installing: P10k Velvet"

  # Check / install powerlevel10k
  if ! [ -f /opt/homebrew/share/powerlevel10k/powerlevel10k.zsh-theme ] && \
     ! [ -f /usr/share/powerlevel10k/powerlevel10k.zsh-theme ]; then
    warn "powerlevel10k not found"
    if command -v brew >/dev/null 2>&1; then
      info "Installing powerlevel10k via Homebrew..."
      brew install powerlevel10k
    elif command -v apt-get >/dev/null 2>&1; then
      echo "Warning: powerlevel10k is not in apt repos — install manually or use the minimal profile"
    else
      echo "Warning: powerlevel10k not installed — install manually"
    fi
  fi

  # zshrc
  install_file "$profile_dir/zshrc" "$HOME/.zshrc"

  # p10k config
  install_file "$profile_dir/.p10k.zsh" "$HOME/.p10k.zsh"

  # iTerm2 dynamic profile
  local iterm_dir="$HOME/Library/Application Support/iTerm2/DynamicProfiles"
  if [ -d "$(dirname "$iterm_dir")" ]; then
    mkdir -p "$iterm_dir"
    install_file "$profile_dir/iterm.json" "$iterm_dir/p10k-velvet.json"
    info "iTerm2 profiles available: P10k Velvet, P10k Velvet Glass"
  else
    warn "iTerm2 not detected — skipping iTerm2 profile"
  fi

  install_terminal_configs "$profile_dir"
  write_state "p10k-velvet"
  _post_install "P10k Velvet" "p10k" "P10k Velvet" "$_prev_engine"
}

# ── Install: catppuccin ───────────────────────────────────────────────────────
install_catppuccin() {
  local profile_dir="$PROFILES_DIR/catppuccin"
  local _prev_engine; _prev_engine="$(current_engine)"

  header "Installing: Catppuccin"

  # Check / install powerlevel10k
  if ! [ -f /opt/homebrew/share/powerlevel10k/powerlevel10k.zsh-theme ] && \
     ! [ -f /usr/share/powerlevel10k/powerlevel10k.zsh-theme ]; then
    warn "powerlevel10k not found"
    if command -v brew >/dev/null 2>&1; then
      info "Installing powerlevel10k via Homebrew..."
      brew install powerlevel10k
    elif command -v apt-get >/dev/null 2>&1; then
      echo "Warning: powerlevel10k is not in apt repos — install manually or use the minimal profile"
    else
      echo "Warning: powerlevel10k not installed — install manually"
    fi
  fi

  # zshrc
  install_file "$profile_dir/zshrc" "$HOME/.zshrc"

  # p10k config
  install_file "$profile_dir/.p10k.zsh" "$HOME/.p10k.zsh"

  # iTerm2 dynamic profile
  local iterm_dir="$HOME/Library/Application Support/iTerm2/DynamicProfiles"
  if [ -d "$(dirname "$iterm_dir")" ]; then
    mkdir -p "$iterm_dir"
    install_file "$profile_dir/iterm.json" "$iterm_dir/catppuccin.json"
    info "iTerm2 profiles available: Catppuccin Mocha, Catppuccin Mocha Glass"
  else
    warn "iTerm2 not detected — skipping iTerm2 profile"
  fi

  install_terminal_configs "$profile_dir"
  write_state "catppuccin"
  _post_install "Catppuccin" "p10k" "Catppuccin Mocha" "$_prev_engine"
}

# ── Install: minimal ─────────────────────────────────────────────────────────
install_minimal() {
  local profile_dir="$PROFILES_DIR/minimal"
  local _prev_engine; _prev_engine="$(current_engine)"

  header "Installing: Minimal"

  # zshrc only — no prompt engine, no iTerm2 profile
  install_file "$profile_dir/zshrc" "$HOME/.zshrc"

  install_terminal_configs "$profile_dir"
  write_state "minimal"
  _post_install "Minimal" "plain" "" "$_prev_engine"
}

# ── Post-install message ──────────────────────────────────────────────────────
# Args: display_name  engine  iterm_profile_name  [prev_engine]
_post_install() {
  local name="$1"
  local engine="$2"
  local iterm_profile="$3"
  local prev_engine="${4:-}"

  echo ""
  echo -e "${BOLD}${GREEN}Profile '${name}' installed.${RESET}"
  echo ""
  echo "  Next steps:"
  if [ -n "$prev_engine" ] && [ "$prev_engine" != "$engine" ]; then
    # Engine changed — source won't clear the old engine's hooks in this session
    echo "    1.  Open a new terminal  ← required when switching prompt engines"
    echo -e "        ${DIM}(source ~/.zshrc won't fully unload ${prev_engine})${RESET}"
  else
    echo "    1.  source ~/.zshrc   (or open a new terminal)"
  fi
  local step=2
  if [ -n "$iterm_profile" ] && [ -d "$HOME/Library/Application Support/iTerm2" ]; then
    echo "    ${step}.  In iTerm2 → Preferences → Profiles → set '${iterm_profile}' as default"
    step=$((step + 1))
  fi
  echo ""
  echo "  Your config files are local copies — edit them freely:"
  echo "    ~/.zshrc"
  case "$engine" in
    oh-my-posh)
      echo "    ~/oh-my-posh/velvet.omp.json"
      ;;
    p10k)
      echo "    ~/.p10k.zsh"
      echo ""
      echo "  Tip: run 'p10k configure' anytime to interactively tweak the prompt."
      ;;
    plain)
      echo ""
      echo "  Tip: edit the PROMPT line in ~/.zshrc to change the prompt appearance."
      ;;
  esac
  echo ""
}

# ── Profile picker ────────────────────────────────────────────────────────────
pick_profile() {
  echo ""
  echo -e "${BOLD}${PURPLE}╔══════════════════════════════════════════════════╗${RESET}"
  echo -e "${BOLD}${PURPLE}║          Shell Profile Selector                  ║${RESET}"
  echo -e "${BOLD}${PURPLE}╚══════════════════════════════════════════════════╝${RESET}"
  echo ""
  echo "  All files are copied locally — no symlinks."
  echo "  Edit them freely at any time."
  echo ""

  local i=1
  local -a keys=()
  for entry in "${PROFILES[@]}"; do
    local key="${entry%%|*}"
    local rest="${entry#*|}"
    local display="${rest%%|*}"
    rest="${rest#*|}"
    local desc="${rest%%|*}"
    keys+=("$key")
    echo -e "  ${BOLD}${i})${RESET} ${LAVENDER}${display}${RESET}"
    echo -e "     ${DIM}${desc}${RESET}"
    echo ""
    (( i++ ))
  done

  echo -e "  ${BOLD}q)${RESET} Quit"
  echo ""

  while true; do
    read -r -p "  Choose a profile [1-${#PROFILES[@]}]: " choice
    case "$choice" in
      q|Q) echo "Aborted."; exit 0 ;;
      *)
        if [[ "$choice" =~ ^[0-9]+$ ]] && (( choice >= 1 && choice <= ${#PROFILES[@]} )); then
          SELECTED_KEY="${keys[$((choice - 1))]}"
          break
        fi
        warn "Invalid choice — enter a number between 1 and ${#PROFILES[@]}, or q to quit."
        ;;
    esac
  done
}

# ── Dispatch ──────────────────────────────────────────────────────────────────
run_profile() {
  case "$1" in
    velvet)      install_velvet ;;
    p10k-velvet) install_p10k_velvet ;;
    catppuccin)  install_catppuccin ;;
    minimal)     install_minimal ;;
    *)
      error "Unknown profile: $1"
      error "Available profiles: velvet, p10k-velvet, catppuccin, minimal"
      exit 1
      ;;
  esac
}

# ── Entry point ───────────────────────────────────────────────────────────────
main() {
  if [ "${1:-}" != "" ]; then
    # Direct install via argument
    run_profile "$1"
  else
    # Interactive picker
    pick_profile
    run_profile "$SELECTED_KEY"
  fi
}

main "${1:-}"
