#!/usr/bin/env bash
# ============================================================================
# doctor.sh — dotfiles health check
#
# Usage:
#   ./doctor.sh
#
# Exit code 1 if any checks fail.
# ============================================================================
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=platform.sh
. "$SCRIPT_DIR/platform.sh"

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
error()   { echo -e "  ${RED}✗${RESET}  ${1}"; }
header()  { echo -e "\n${BOLD}${PURPLE}${1}${RESET}"; }

# ── Counters ──────────────────────────────────────────────────────────────────
PASS=0
WARN=0
FAIL=0

pass() { success "$1"; (( PASS++ )) || true; }
warn_count() { warn "$1"; (( WARN++ )) || true; }
fail() { error "$1"; (( FAIL++ )) || true; }

# ── Banner ────────────────────────────────────────────────────────────────────
echo ""
echo -e "${BOLD}${PURPLE}╔══════════════════════════════════════════════════╗${RESET}"
echo -e "${BOLD}${PURPLE}║           Dotfiles Doctor                        ║${RESET}"
echo -e "${BOLD}${PURPLE}╚══════════════════════════════════════════════════╝${RESET}"
echo ""

# ── Section: Homebrew ─────────────────────────────────────────────────────────
section_brew() {
  # Homebrew is macOS-only (or optional on Linux — skip check entirely on Linux)
  [ "$DOTFILES_OS" != "macos" ] && return

  header "Homebrew"

  if command -v brew >/dev/null 2>&1; then
    pass "brew found: $(brew --version | head -1)"
  else
    fail "brew not found — install from https://brew.sh"
  fi
}

# ── Section: Prompt engine ────────────────────────────────────────────────────
section_prompt() {
  header "Shell Prompt"

  local zshrc="$HOME/.zshrc"
  local engine="unknown"

  if [ -f "$zshrc" ]; then
    if grep -q 'powerlevel10k' "$zshrc" 2>/dev/null; then
      engine="powerlevel10k"
    elif grep -q 'oh-my-posh' "$zshrc" 2>/dev/null; then
      engine="oh-my-posh"
    elif grep -q 'PROMPT=' "$zshrc" 2>/dev/null; then
      engine="plain"
    fi
  fi

  info "Detected prompt engine: ${engine}"

  case "$engine" in
    oh-my-posh)
      if [ "$DOTFILES_OS" = "linux-server" ]; then
        warn_count "oh-my-posh check skipped on linux-server (GUI/prompt tools not expected)"
      else
        if command -v oh-my-posh >/dev/null 2>&1; then
          pass "oh-my-posh binary found: $(oh-my-posh --version 2>/dev/null | head -1)"
        else
          if [ "$DOTFILES_OS" = "macos" ]; then
            fail "oh-my-posh binary not found (brew install jandedobbeleer/oh-my-posh/oh-my-posh)"
          else
            fail "oh-my-posh binary not found (curl -s https://ohmyposh.dev/install.sh | bash -s -- -d ~/.local/bin)"
          fi
        fi
        local theme="$HOME/oh-my-posh/velvet.omp.json"
        if [ -f "$theme" ]; then
          pass "theme file found: $theme"
        else
          fail "theme file missing: $theme"
        fi
      fi
      ;;
    powerlevel10k)
      if [ "$DOTFILES_OS" = "linux-server" ]; then
        warn_count "powerlevel10k check skipped on linux-server (GUI/prompt tools not expected)"
      else
        local p10k_theme
        if [ "$DOTFILES_OS" = "macos" ]; then
          p10k_theme="/opt/homebrew/share/powerlevel10k/powerlevel10k.zsh-theme"
        else
          p10k_theme="/usr/share/zsh-theme-powerlevel10k/powerlevel10k.zsh-theme"
        fi
        if [ -f "$p10k_theme" ]; then
          pass "powerlevel10k theme found: $p10k_theme"
        else
          if [ "$DOTFILES_OS" = "macos" ]; then
            fail "powerlevel10k theme not found: $p10k_theme (brew install powerlevel10k)"
          else
            fail "powerlevel10k theme not found: $p10k_theme (install manually — see https://github.com/romkatv/powerlevel10k)"
          fi
        fi
        local p10k_cfg="$HOME/.p10k.zsh"
        if [ -f "$p10k_cfg" ]; then
          pass "p10k config found: $p10k_cfg"
        else
          fail "p10k config missing: $p10k_cfg (run: p10k configure)"
        fi
      fi
      ;;
    plain)
      pass "Plain PROMPT= detected in .zshrc"
      ;;
    *)
      warn_count "Could not detect prompt engine in $zshrc"
      ;;
  esac
}

# ── Section: CLI tools ────────────────────────────────────────────────────────
section_tools() {
  header "CLI Tools"

  local tools=(fzf fd bat eza lazygit btop zoxide atuin direnv)

  for tool in "${tools[@]}"; do
    if command -v "$tool" >/dev/null 2>&1; then
      pass "$tool"
    else
      local pkg_name
      pkg_name="$(pkg "$tool")"
      if [ -n "$pkg_name" ]; then
        fail "$tool not found (Install with: $PKG_INSTALL $pkg_name)"
      else
        fail "$tool not found (no package available via $PKG_MGR — install manually)"
      fi
    fi
  done

  # delta is shipped as 'git-delta' in most package managers but the binary is `delta`
  if command -v delta >/dev/null 2>&1; then
    pass "delta"
  else
    local delta_pkg
    delta_pkg="$(pkg delta)"
    if [ -n "$delta_pkg" ]; then
      fail "delta not found (Install with: $PKG_INSTALL $delta_pkg)"
    else
      fail "delta not found (no package available via $PKG_MGR — install manually)"
    fi
  fi
}

# ── Section: Zsh plugins ──────────────────────────────────────────────────────
section_plugins() {
  header "Zsh Plugins"

  # Each entry is "logical-name:pkg-name:relative-path-under-share"
  # We probe Homebrew paths first, then system paths (/usr/share).
  local plugin_specs=(
    "zsh-autosuggestions:zsh-autosuggestions:zsh-autosuggestions/zsh-autosuggestions.zsh"
    "zsh-syntax-highlighting:zsh-syntax-highlighting:zsh-syntax-highlighting/zsh-syntax-highlighting.zsh"
    "zsh-history-substring-search:zsh-history-substring-search:zsh-history-substring-search/zsh-history-substring-search.zsh"
  )

  for spec in "${plugin_specs[@]}"; do
    local logical pkg rel_path found_path
    logical="${spec%%:*}"
    pkg="${spec#*:}"; pkg="${pkg%%:*}"
    rel_path="${spec##*:}"
    found_path=""

    # Candidate directories: Homebrew (Intel + Apple Silicon) then system
    local candidates=(
      "/opt/homebrew/share/$rel_path"
      "/usr/local/share/$rel_path"
      "/usr/share/$rel_path"
    )

    for candidate in "${candidates[@]}"; do
      if [ -f "$candidate" ]; then
        found_path="$candidate"
        break
      fi
    done

    if [ -n "$found_path" ]; then
      pass "$logical ($found_path)"
    else
      fail "$logical not found (Install with: $PKG_INSTALL $pkg)"
    fi
  done
}

# ── Section: Config files ─────────────────────────────────────────────────────
section_configs() {
  header "Config Files"

  # ~/.zshrc — local copy is good; symlink is a warning; missing is a failure
  local zshrc="$HOME/.zshrc"
  if [ -L "$zshrc" ]; then
    warn_count "~/.zshrc is still a symlink — run choose-profile.sh to install a local copy"
  elif [ -f "$zshrc" ]; then
    pass "~/.zshrc (local copy)"
  else
    fail "~/.zshrc is missing"
  fi

  # Remaining configs — symlink or regular file are both acceptable
  local configs=(
    "$HOME/.gitconfig"
    "$HOME/.tmux.conf"
    "$HOME/.config/nvim/init.lua"
  )

  for cfg in "${configs[@]}"; do
    local label="${cfg/$HOME/\~}"
    if [ -L "$cfg" ]; then
      pass "$label (symlink)"
    elif [ -f "$cfg" ]; then
      pass "$label (local copy)"
    else
      fail "$label is missing"
    fi
  done
}

# ── Section: Git identity ─────────────────────────────────────────────────────
section_git() {
  header "Git Identity"

  local git_name
  git_name="$(git config --global user.name 2>/dev/null || true)"
  if [ -n "$git_name" ]; then
    pass "user.name = $git_name"
  else
    warn_count "git config --global user.name is not set"
  fi

  local git_email
  git_email="$(git config --global user.email 2>/dev/null || true)"
  if [ -n "$git_email" ]; then
    pass "user.email = $git_email"
  else
    warn_count "git config --global user.email is not set"
  fi
}

# ── Section: Nerd Font ────────────────────────────────────────────────────────
section_font() {
  header "Nerd Font (FiraCode)"

  # Font file presence check (platform-specific paths)
  local font_found=false
  if [ "$DOTFILES_OS" = "macos" ]; then
    ls ~/Library/Fonts/FiraCode*.ttf \
       ~/Library/Fonts/FiraCodeNerdFont*.ttf \
       /Library/Fonts/FiraCode*.ttf \
       2>/dev/null | grep -q . && font_found=true
  else
    ls ~/.local/share/fonts/FiraCode*.ttf \
       ~/.local/share/fonts/FiraCodeNerdFont*.ttf \
       /usr/share/fonts/truetype/firacode/FiraCode*.ttf \
       2>/dev/null | grep -q . && font_found=true
  fi

  if [ "$font_found" = "true" ]; then
    pass "FiraCode Nerd Font found"
  else
    warn_count "FiraCode Nerd Font not found — install with: brew install --cask font-fira-code-nerd-font"
    return 0
  fi

  # Terminal font config checks (shared function from font-config.sh)
  # shellcheck source=font-config.sh
  FONT_CONFIG_SOURCE_ONLY=1 . "$SCRIPT_DIR/font-config.sh"

  local status
  for terminal in ghostty kitty vscode; do
    status="$(detect_terminal_font_status "$terminal")"
    case "$status" in
      not_installed) ;;  # silently skip
      installed_configured)
        case "$terminal" in
          ghostty) pass "Ghostty: font configured" ;;
          kitty)   pass "Kitty: font configured" ;;
          vscode)  pass "VS Code: terminal font configured" ;;
        esac
        ;;
      installed_not_configured)
        case "$terminal" in
          ghostty) warn_count "Ghostty: installed but font not configured — run ./choose-profile.sh or ./font-config.sh" ;;
          kitty)   warn_count "Kitty: installed but font not configured — run ./choose-profile.sh or ./font-config.sh" ;;
          vscode)  warn_count "VS Code: terminal font not configured — run ./font-config.sh" ;;
        esac
        ;;
    esac
  done

  if [ "$DOTFILES_OS" = "macos" ]; then
    status="$(detect_terminal_font_status iterm2)"
    case "$status" in
      not_installed) ;;
      installed_configured)     pass "iTerm2: font configured" ;;
      installed_not_configured) warn_count "iTerm2: installed but font not configured — run ./iterm-config.sh" ;;
    esac
  fi
}

# ── Section: iTerm2 ───────────────────────────────────────────────────────────
section_iterm2() {
  # iTerm2 is macOS-only
  [ "$DOTFILES_OS" != "macos" ] && return

  header "iTerm2 Dynamic Profiles"

  local iterm_profiles_dir="$HOME/Library/Application Support/iTerm2/DynamicProfiles"

  if [ -d "$iterm_profiles_dir" ]; then
    pass "DynamicProfiles directory exists"
    if ls "$iterm_profiles_dir"/*.json >/dev/null 2>&1; then
      local count
      count="$(ls "$iterm_profiles_dir"/*.json 2>/dev/null | wc -l | tr -d ' ')"
      pass "$count .json profile(s) installed"
    else
      warn_count "No .json profiles found in DynamicProfiles — run choose-profile.sh to install"
    fi
  else
    warn_count "iTerm2 DynamicProfiles directory not found — is iTerm2 installed?"
  fi
}

# ── Section: macOS defaults ───────────────────────────────────────────────────
section_macos_defaults() {
  # macOS-only checks — skip on Linux
  [ "$DOTFILES_OS" != "macos" ] && return

  header "macOS System Defaults"

  # Check 1: Screenshots directory
  if [ -d "$HOME/Desktop/Screenshots" ]; then
    pass "~/Desktop/Screenshots directory exists"
  else
    warn_count "~/Desktop/Screenshots not found — run: ./macos-defaults.sh"
  fi

  # Check 2: KeyRepeat — macOS default is 6; anything >= 6 means defaults not applied
  local key_repeat
  key_repeat="$(defaults read NSGlobalDomain KeyRepeat 2>/dev/null || echo 99)"
  if [ "$key_repeat" -lt 6 ] 2>/dev/null; then
    pass "KeyRepeat = $key_repeat (fast repeat configured)"
  else
    warn_count "KeyRepeat = $key_repeat (macOS default or higher) — run: ./macos-defaults.sh"
  fi
}

# ── Section: Roles ────────────────────────────────────────────────────────────
section_roles() {
  header "Shell Roles"

  local zshrc="$HOME/.zshrc"
  local roles=(work personal server)

  for role in "${roles[@]}"; do
    if [ -f "$zshrc" ] && grep -q "# <<< role:${role} >>>" "$zshrc" 2>/dev/null; then
      echo -e "  ${GREEN}●${RESET}  ${role} ${DIM}(active)${RESET}"
    else
      echo -e "  ${DIM}○  ${role} (inactive)${RESET}"
    fi
  done
}

# ── Section: Linux clipboard ──────────────────────────────────────────────────
section_linux_clipboard() {
  # Only run on Linux desktop
  [ "$DOTFILES_OS" != "linux-desktop" ] && return

  header "Clipboard Tool (Linux Desktop)"

  if command -v xclip >/dev/null 2>&1; then
    pass "xclip found"
  elif command -v xsel >/dev/null 2>&1; then
    pass "xsel found"
  else
    warn_count "Neither xclip nor xsel found — clipboard integration will not work (install xclip or xsel)"
  fi
}

# ── Section: Linux shell ───────────────────────────────────────────────────────
section_linux_shell() {
  # Only run on Linux (any tier)
  case "$DOTFILES_OS" in linux-*) ;; *) return ;; esac

  header "Linux Shell"

  # Check that zsh is the login shell
  local zsh_path
  zsh_path="$(command -v zsh 2>/dev/null || true)"
  if [ -z "$zsh_path" ]; then
    fail "zsh not found in PATH"
  elif [ "$SHELL" = "$zsh_path" ]; then
    pass "Login shell is zsh ($SHELL)"
  else
    warn_count "Login shell is $SHELL — expected zsh ($zsh_path). Run: chsh -s $zsh_path"
  fi

  # Check that package manager was detected
  if [ "$PKG_MGR" = "unknown" ]; then
    warn_count "Package manager not detected (PKG_MGR=unknown) — automatic installs will be skipped"
  else
    pass "Package manager: $PKG_MGR"
  fi
}

# ── Section: Linux server sanity ──────────────────────────────────────────────
section_linux_server() {
  # Only run on linux-server
  [ "$DOTFILES_OS" != "linux-server" ] && return

  header "Linux Server Sanity"

  if [ -n "${DISPLAY:-}" ]; then
    warn_count "\$DISPLAY is set ('$DISPLAY') on a headless server — SSH X-forwarding may cause unexpected behavior"
  else
    pass "\$DISPLAY not set (expected on headless server)"
  fi
}

# ── Summary ───────────────────────────────────────────────────────────────────
print_summary() {
  echo ""
  echo -e "${DIM}──────────────────────────────${RESET}"
  echo -e "  ${GREEN}${PASS} passed${RESET}  ${YELLOW}${WARN} warnings${RESET}  ${RED}${FAIL} failed${RESET}"
  echo ""
}

# ── Main ──────────────────────────────────────────────────────────────────────
main() {
  section_brew
  section_prompt
  section_tools
  section_plugins
  section_configs
  section_git
  section_font
  section_iterm2
  section_macos_defaults
  section_roles
  section_linux_shell
  section_linux_clipboard
  section_linux_server
  print_summary

  if [ "$FAIL" -gt 0 ]; then
    exit 1
  fi
}

main
