#!/usr/bin/env bash
# Test suite — verifies the dotfiles setup is complete and correctly symlinked.

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PASS=0; FAIL=0; WARN=0

pass() { echo "  ✓ $1"; PASS=$((PASS + 1)); }
fail() { echo "  ✗ $1"; FAIL=$((FAIL + 1)); }
warn() { echo "  ! $1"; WARN=$((WARN + 1)); }
section() { echo ""; echo "── $1"; }

# ── check_symlink <link> <expected_target>
check_symlink() {
  local link="$1" target="$2" actual
  if [ -L "$link" ]; then
    actual="$(readlink "$link")"
    if [ "$actual" = "$target" ]; then
      pass "$link"
    else
      warn "$link is a symlink but points to $actual (expected $target)"
    fi
  elif [ -e "$link" ]; then
    warn "$link exists as a regular file — re-run the install script to symlink it"
  else
    fail "$link missing"
  fi
}

# ════════════════════════════════════════════════
section "Tools"
# ════════════════════════════════════════════════

for tool in oh-my-posh eza bat fzf fd lazygit btop delta tmux nvim \
            zoxide atuin direnv; do
  if command -v "$tool" >/dev/null 2>&1; then
    pass "$tool"
  else
    fail "$tool not installed"
  fi
done

# ════════════════════════════════════════════════
section "Zsh Plugins"
# ════════════════════════════════════════════════

ZSH_PLUGIN_DIR="/opt/homebrew/share"
for plugin in \
  zsh-autosuggestions/zsh-autosuggestions.zsh \
  zsh-syntax-highlighting/zsh-syntax-highlighting.zsh \
  zsh-history-substring-search/zsh-history-substring-search.zsh; do
  if [ -f "$ZSH_PLUGIN_DIR/$plugin" ]; then
    pass "$(dirname "$plugin")"
  else
    fail "$(dirname "$plugin") not found at $ZSH_PLUGIN_DIR/$plugin"
  fi
done

# ════════════════════════════════════════════════
section "Symlinks"
# ════════════════════════════════════════════════

check_symlink "$HOME/.zshrc"                    "$SCRIPT_DIR/zshrc"
check_symlink "$HOME/.gitconfig"                "$SCRIPT_DIR/gitconfig"
check_symlink "$HOME/.tmux.conf"                "$SCRIPT_DIR/tmux.conf"
check_symlink "$HOME/.config/nvim/init.lua"     "$SCRIPT_DIR/init.lua"
check_symlink "$HOME/.ssh/config"               "$SCRIPT_DIR/ssh_config"
check_symlink "$HOME/oh-my-posh/velvet.omp.json" "$SCRIPT_DIR/velvet.omp.json"
check_symlink "$HOME/Library/Application Support/iTerm2/DynamicProfiles/velvet.json" \
              "$SCRIPT_DIR/velvet.iterm2profile.json"
check_symlink "$HOME/.tmux/now-playing.sh"      "$SCRIPT_DIR/now-playing.sh"

# ════════════════════════════════════════════════
section "Oh-My-Posh Theme"
# ════════════════════════════════════════════════

OMP_THEME="$HOME/oh-my-posh/velvet.omp.json"
if [ -f "$OMP_THEME" ]; then
  if python3 -c "import json, sys; json.load(open(sys.argv[1]))" "$OMP_THEME" 2>/dev/null; then
    pass "velvet.omp.json valid JSON"
  else
    fail "velvet.omp.json invalid JSON"
  fi
else
  fail "velvet.omp.json missing"
fi

# ════════════════════════════════════════════════
section "Tmux Plugins"
# ════════════════════════════════════════════════

if [ -d "$HOME/.tmux/plugins/tpm" ]; then
  pass "TPM"
else
  fail "TPM not found — start tmux and press Ctrl+a I to install"
fi
for plugin in tmux-resurrect tmux-continuum; do
  if [ -d "$HOME/.tmux/plugins/$plugin" ]; then
    pass "$plugin"
  else
    fail "$plugin not found"
  fi
done

# ════════════════════════════════════════════════
section "iTerm2"
# ════════════════════════════════════════════════

ITERM_PROFILE="$HOME/Library/Application Support/iTerm2/DynamicProfiles/velvet.json"
if [ -e "$ITERM_PROFILE" ]; then
  pass "Velvet dynamic profile installed"
else
  fail "Velvet profile missing — run iterm-config.sh"
fi

# ════════════════════════════════════════════════
section "Neovim"
# ════════════════════════════════════════════════

if nvim --headless +q 2>/dev/null; then
  pass "nvim starts cleanly"
else
  fail "nvim exited with errors on startup"
fi

LAZY_DIR="$HOME/.local/share/nvim/lazy"
if [ -d "$LAZY_DIR" ] && [ -n "$(ls -A "$LAZY_DIR" 2>/dev/null)" ]; then
  pass "lazy.nvim plugins installed"
else
  warn "lazy.nvim not yet bootstrapped — open nvim once to install plugins"
fi

# ════════════════════════════════════════════════
section "Git"
# ════════════════════════════════════════════════

pager=$(git config --global core.pager 2>/dev/null || true)
if echo "$pager" | grep -q "delta"; then
  pass "delta configured as pager"
else
  fail "delta not set as git pager"
fi

if [ "$(git config --global pull.rebase 2>/dev/null)" = "true" ]; then
  pass "pull.rebase = true"
else
  warn "pull.rebase not set to true"
fi

if [ "$(git config --global rerere.enabled 2>/dev/null)" = "true" ]; then
  pass "rerere.enabled = true"
else
  warn "rerere.enabled not set"
fi

# ════════════════════════════════════════════════
section "Linux Platform — Syntax Checks"
# ════════════════════════════════════════════════

syntax_check() {
  local file="$1"
  if bash -n "$SCRIPT_DIR/$file" 2>/dev/null; then
    pass "bash -n $file"
  else
    fail "bash -n $file — syntax error"
  fi
}

syntax_check platform.sh
syntax_check tools-config.sh
syntax_check git-config.sh
syntax_check tmux-config.sh
syntax_check nvim-config.sh
syntax_check eza-config.sh
syntax_check install-all.sh
syntax_check iterm-config.sh
syntax_check setup.sh
syntax_check choose-profile.sh
syntax_check doctor.sh
syntax_check bootstrap-server.sh
syntax_check macos-defaults.sh
syntax_check touchid-sudo.sh

# ════════════════════════════════════════════════
section "Linux Platform — test-platform.sh"
# ════════════════════════════════════════════════

if bash "$SCRIPT_DIR/test-platform.sh" >/dev/null 2>&1; then
  pass "test-platform.sh passed"
else
  fail "test-platform.sh — one or more checks failed (run ./test-platform.sh for details)"
fi

# ════════════════════════════════════════════════
section "macOS Defaults — test-macos-defaults.sh"
# ════════════════════════════════════════════════

if [ "$(uname -s)" != "Darwin" ]; then
  warn "test-macos-defaults.sh skipped (macOS only)"
elif bash "$SCRIPT_DIR/test-macos-defaults.sh" >/dev/null 2>&1; then
  pass "test-macos-defaults.sh passed"
else
  fail "test-macos-defaults.sh — one or more checks failed (run ./test-macos-defaults.sh for details)"
fi

# ════════════════════════════════════════════════
section "tmux Config — test-tmux-config.sh"
# ════════════════════════════════════════════════

if bash "$SCRIPT_DIR/test-tmux-config.sh" >/dev/null 2>&1; then
  pass "test-tmux-config.sh passed"
else
  fail "test-tmux-config.sh — one or more checks failed (run ./test-tmux-config.sh for details)"
fi

# ════════════════════════════════════════════════
section "TouchID sudo — test-touchid-sudo.sh"
# ════════════════════════════════════════════════

if [ "$(uname -s)" != "Darwin" ]; then
  warn "test-touchid-sudo.sh skipped (macOS only)"
elif bash "$SCRIPT_DIR/test-touchid-sudo.sh" >/dev/null 2>&1; then
  pass "test-touchid-sudo.sh passed"
else
  fail "test-touchid-sudo.sh — one or more checks failed (run ./test-touchid-sudo.sh for details)"
fi

# ════════════════════════════════════════════════
echo ""
echo "────────────────────────────────"
printf "  passed: %d  failed: %d  warnings: %d\n" "$PASS" "$FAIL" "$WARN"
echo "────────────────────────────────"
echo ""

[ "$FAIL" -eq 0 ]
