#!/usr/bin/env bash
# test-tmux-config.sh — unit tests for tmux-config.sh TUI functions
# Sources tmux-config.sh in TMUX_CONFIG_SOURCE_ONLY=1 mode to test functions directly.
# Only tests TUI logic; does not install tmux or modify live configs.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PASS=0; FAIL=0

pass()    { echo "  ✓ $1"; PASS=$((PASS + 1)); }
fail()    { echo "  ✗ $1"; FAIL=$((FAIL + 1)); }
section() { echo ""; echo "── $1"; }

# Source the script in test mode — runs no install logic, just defines functions
TMUX_CONFIG_SOURCE_ONLY=1 . "$SCRIPT_DIR/tmux-config.sh"

# ── write_plugins_conf ────────────────────────────────────────────────────────
section "write_plugins_conf"

# Test: persistence enabled → resurrect + continuum declared
ENABLED=(mouse vim_nav vi_copy clipboard clock persistence)
DISABLED=(smart_scroll nowplaying border_labels)
declare -A VARIANTS=()
PLUGINS_CONF_OUT=""
DRY_RUN=true
write_plugins_conf

if echo "$PLUGINS_CONF_OUT" | grep -q "tmux-resurrect"; then
  pass "persistence enabled: tmux-resurrect declared"
else
  fail "persistence enabled: tmux-resurrect missing"
fi

if echo "$PLUGINS_CONF_OUT" | grep -q "@continuum-save-interval"; then
  pass "persistence enabled: continuum options present"
else
  fail "persistence enabled: continuum options missing"
fi

# Test: persistence disabled → header comment only, no plugin lines
ENABLED=(mouse vim_nav)
DISABLED=(persistence)
PLUGINS_CONF_OUT=""
write_plugins_conf

if echo "$PLUGINS_CONF_OUT" | grep -q "tmux-resurrect"; then
  fail "persistence disabled: should not contain tmux-resurrect"
else
  pass "persistence disabled: tmux-resurrect correctly absent"
fi

# ── write_local_conf — non-status-bar sections ────────────────────────────────
section "write_local_conf: prefix, mouse, nav, copy, clipboard, scrollback, borders"

_test_local_conf() {
  LOCAL_CONF_OUT=""
  write_local_conf
  echo "$LOCAL_CONF_OUT"
}

# Test: prefix Ctrl+b — override written
ENABLED=(mouse vim_nav vi_copy clipboard clock persistence)
DISABLED=(smart_scroll nowplaying border_labels)
declare -A VARIANTS=([prefix]="C-b" [border_style]="double" [statusbar_style]="themed" [scrollback]="10000" [copy_cmd]="pbcopy" [clock_pos]="right")
DRY_RUN=true; DOTFILES_OS="macos"
out="$(_test_local_conf)"
echo "$out" | grep -q "set -g prefix C-b" && pass "prefix C-b: override written" || fail "prefix C-b: override missing"
echo "$out" | grep -q "unbind C-a" && pass "prefix C-b: unbind C-a written" || fail "prefix C-b: unbind C-a missing"

# Test: prefix Ctrl+a (default) — no prefix lines
VARIANTS[prefix]="C-a"
out="$(_test_local_conf)"
echo "$out" | grep -q "set -g prefix" && fail "prefix C-a: should not write prefix override" || pass "prefix C-a: no override written"

# Test: mouse disabled
ENABLED=()
DISABLED=(mouse smart_scroll nowplaying border_labels)
VARIANTS[prefix]="C-a"
out="$(_test_local_conf)"
echo "$out" | grep -q "set -g mouse off" && pass "mouse disabled: written" || fail "mouse disabled: missing"

# Test: vim nav disabled
DISABLED=(vim_nav smart_scroll nowplaying border_labels)
ENABLED=(mouse vi_copy clipboard clock persistence)
out="$(_test_local_conf)"
echo "$out" | grep -q "unbind h" && pass "vim nav disabled: unbind written" || fail "vim nav disabled: unbind missing"

# Test: scrollback 50000
ENABLED=(mouse vim_nav vi_copy clipboard clock persistence)
DISABLED=(smart_scroll nowplaying border_labels)
VARIANTS[scrollback]="50000"
out="$(_test_local_conf)"
echo "$out" | grep -q "history-limit 50000" && pass "scrollback 50000: written" || fail "scrollback 50000: missing"

# Test: scrollback 0 (unlimited)
VARIANTS[scrollback]="0"
out="$(_test_local_conf)"
echo "$out" | grep -q "history-limit 0" && pass "scrollback unlimited: written" || fail "scrollback unlimited: missing"

# Test: scrollback 10000 (default) — no override
VARIANTS[scrollback]="10000"
out="$(_test_local_conf)"
echo "$out" | grep -q "history-limit" && fail "scrollback 10000: should not write override" || pass "scrollback 10000: no override"

# Test: border style single
VARIANTS[border_style]="single"
out="$(_test_local_conf)"
echo "$out" | grep -q "pane-border-lines single" && pass "border single: written" || fail "border single: missing"

# Test: border style heavy
VARIANTS[border_style]="heavy"
out="$(_test_local_conf)"
echo "$out" | grep -q "pane-border-lines heavy" && pass "border heavy: written" || fail "border heavy: missing"

# Test: border style double (default) — no override
VARIANTS[border_style]="double"
out="$(_test_local_conf)"
echo "$out" | grep -q "pane-border-lines" && fail "border double: should not write override" || pass "border double: no override"

# Test: border labels disabled
DISABLED=(border_labels smart_scroll nowplaying)
out="$(_test_local_conf)"
echo "$out" | grep -q "pane-border-status off" && pass "border labels disabled: written" || fail "border labels disabled: missing"

# Test: Linux clipboard always written (override pbcopy from base)
DOTFILES_OS="linux"
ENABLED=(mouse vim_nav vi_copy clipboard clock persistence)
DISABLED=(smart_scroll nowplaying border_labels)
VARIANTS[copy_cmd]="xclip"
VARIANTS[border_style]="double"; VARIANTS[scrollback]="10000"; VARIANTS[prefix]="C-a"
out="$(_test_local_conf)"
echo "$out" | grep -q "xclip" && pass "linux: clipboard written with xclip" || fail "linux: xclip missing"

# Test: clipboard disabled
DOTFILES_OS="macos"
DISABLED=(clipboard smart_scroll nowplaying border_labels)
ENABLED=(mouse vim_nav vi_copy clock persistence)
out="$(_test_local_conf)"
echo "$out" | grep -q "unbind -T copy-mode-vi y" && pass "clipboard disabled: unbind written" || fail "clipboard disabled: unbind missing"

# ── Summary ───────────────────────────────────────────────────────────────────
echo ""
echo "────────────────────────────────"
printf "  passed: %d  failed: %d\n" "$PASS" "$FAIL"
echo "────────────────────────────────"
echo ""

[ "$FAIL" -eq 0 ]
