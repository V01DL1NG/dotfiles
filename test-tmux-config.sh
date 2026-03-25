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
if echo "$out" | grep -q "set -g prefix C-b"; then pass "prefix C-b: override written"; else fail "prefix C-b: override missing"; fi
if echo "$out" | grep -q "unbind C-a"; then pass "prefix C-b: unbind C-a written"; else fail "prefix C-b: unbind C-a missing"; fi

# Test: prefix Ctrl+a (default) — no prefix lines
VARIANTS[prefix]="C-a"
out="$(_test_local_conf)"
if echo "$out" | grep -q "set -g prefix"; then fail "prefix C-a: should not write prefix override"; else pass "prefix C-a: no override written"; fi

# Test: mouse disabled
ENABLED=()
DISABLED=(mouse smart_scroll nowplaying border_labels)
VARIANTS[prefix]="C-a"
out="$(_test_local_conf)"
if echo "$out" | grep -q "set -g mouse off"; then pass "mouse disabled: written"; else fail "mouse disabled: missing"; fi

# Test: vim nav disabled
DISABLED=(vim_nav smart_scroll nowplaying border_labels)
ENABLED=(mouse vi_copy clipboard clock persistence)
out="$(_test_local_conf)"
if echo "$out" | grep -q "unbind h"; then pass "vim nav disabled: unbind written"; else fail "vim nav disabled: unbind missing"; fi

# Test: scrollback 50000
ENABLED=(mouse vim_nav vi_copy clipboard clock persistence)
DISABLED=(smart_scroll nowplaying border_labels)
VARIANTS[scrollback]="50000"
out="$(_test_local_conf)"
if echo "$out" | grep -q "history-limit 50000"; then pass "scrollback 50000: written"; else fail "scrollback 50000: missing"; fi

# Test: scrollback 0 (unlimited)
VARIANTS[scrollback]="0"
out="$(_test_local_conf)"
if echo "$out" | grep -q "history-limit 0"; then pass "scrollback unlimited: written"; else fail "scrollback unlimited: missing"; fi

# Test: scrollback 10000 (default) — no override
VARIANTS[scrollback]="10000"
out="$(_test_local_conf)"
if echo "$out" | grep -q "history-limit"; then fail "scrollback 10000: should not write override"; else pass "scrollback 10000: no override"; fi

# Test: border style single
VARIANTS[border_style]="single"
out="$(_test_local_conf)"
if echo "$out" | grep -q "pane-border-lines single"; then pass "border single: written"; else fail "border single: missing"; fi

# Test: border style heavy
VARIANTS[border_style]="heavy"
out="$(_test_local_conf)"
if echo "$out" | grep -q "pane-border-lines heavy"; then pass "border heavy: written"; else fail "border heavy: missing"; fi

# Test: border style double (default) — no override
VARIANTS[border_style]="double"
out="$(_test_local_conf)"
if echo "$out" | grep -q "pane-border-lines"; then fail "border double: should not write override"; else pass "border double: no override"; fi

# Test: border labels disabled
DISABLED=(border_labels smart_scroll nowplaying)
out="$(_test_local_conf)"
if echo "$out" | grep -q "pane-border-status off"; then pass "border labels disabled: written"; else fail "border labels disabled: missing"; fi

# Test: Linux clipboard always written (override pbcopy from base)
DOTFILES_OS="linux"
ENABLED=(mouse vim_nav vi_copy clipboard clock persistence)
DISABLED=(smart_scroll nowplaying border_labels)
VARIANTS[copy_cmd]="xclip"
VARIANTS[border_style]="double"; VARIANTS[scrollback]="10000"; VARIANTS[prefix]="C-a"
out="$(_test_local_conf)"
if echo "$out" | grep -q "xclip"; then pass "linux: clipboard written with xclip"; else fail "linux: xclip missing"; fi

# Test: clipboard disabled
DOTFILES_OS="macos"
DISABLED=(clipboard smart_scroll nowplaying border_labels)
ENABLED=(mouse vim_nav vi_copy clock persistence)
out="$(_test_local_conf)"
if echo "$out" | grep -q "unbind -T copy-mode-vi y"; then pass "clipboard disabled: unbind written"; else fail "clipboard disabled: unbind missing"; fi

# ── write_local_conf — status bar ─────────────────────────────────────────────
section "write_local_conf: status bar"

_sb() {
  ENABLED=(mouse vim_nav vi_copy clipboard clock persistence "$@")
  DISABLED=(smart_scroll border_labels)
  VARIANTS[prefix]="${VARIANTS[prefix]:-C-a}"
  VARIANTS[border_style]="${VARIANTS[border_style]:-double}"
  VARIANTS[scrollback]="${VARIANTS[scrollback]:-10000}"
  VARIANTS[copy_cmd]="${VARIANTS[copy_cmd]:-pbcopy}"
  VARIANTS[statusbar_style]="${VARIANTS[statusbar_style]:-themed}"
  VARIANTS[clock_pos]="${VARIANTS[clock_pos]:-right}"
  LOCAL_CONF_OUT=""
  DRY_RUN=true
  DOTFILES_OS="macos"
  write_local_conf
  echo "$LOCAL_CONF_OUT"
}

# Minimal style
VARIANTS[statusbar_style]="minimal"
out="$(_sb)"
if echo "$out" | grep -q 'status-left " #S "'; then pass "minimal: plain status-left"; else fail "minimal: plain status-left missing"; fi
if echo "$out" | grep -q 'status-right " %H:%M "'; then pass "minimal: plain status-right"; else fail "minimal: plain status-right missing"; fi

# Both right (base default) — no status bar override written
declare -A VARIANTS=()
VARIANTS[nowplaying_pos]="right"; VARIANTS[clock_pos]="right"
out="$(_sb nowplaying)"
if echo "$out" | grep -q "status-left "; then fail "both right: should not write status-bar override"; else pass "both right: no override"; fi

# Now-playing left, clock right
VARIANTS[nowplaying_pos]="left"
out="$(_sb nowplaying)"
if echo "$out" | grep -q 'now-playing.sh'; then pass "np-left: now-playing in status-left"; else fail "np-left: now-playing missing from status-left"; fi
if echo "$out" | grep -q '%H:%M'; then pass "np-left: clock present"; else fail "np-left: clock missing"; fi

# Now-playing right, clock left
VARIANTS[nowplaying_pos]="right"; VARIANTS[clock_pos]="left"
out="$(_sb nowplaying)"
if echo "$out" | grep -q '%H:%M'; then pass "clock-left: clock present in output"; else fail "clock-left: clock missing"; fi

# Both left
VARIANTS[nowplaying_pos]="left"; VARIANTS[clock_pos]="left"
out="$(_sb nowplaying)"
if echo "$out" | grep -q 'status-right ""'; then pass "both-left: status-right cleared"; else fail "both-left: status-right not cleared"; fi

# Nowplaying disabled, clock right (default)
declare -A VARIANTS=()
VARIANTS[nowplaying_pos]="right"; VARIANTS[clock_pos]="right"
out="$(_sb)"
if echo "$out" | grep -q 'now-playing.sh'; then fail "np-off clock-right: now-playing should be absent"; else pass "np-off clock-right: now-playing absent"; fi
if echo "$out" | grep -q '%H:%M'; then pass "np-off clock-right: clock present"; else fail "np-off clock-right: clock missing"; fi

# Nowplaying disabled, clock left
VARIANTS[clock_pos]="left"
out="$(_sb)"
if echo "$out" | grep -q '%H:%M'; then pass "np-off clock-left: clock present"; else fail "np-off clock-left: clock missing"; fi
if echo "$out" | grep -q 'status-right ""'; then pass "np-off clock-left: status-right cleared"; else fail "np-off clock-left: status-right not cleared"; fi

# ── fzf fallback presets ──────────────────────────────────────────────────────
section "fzf fallback: preset key mappings"

ENABLED=(); DISABLED=()
_apply_preset "full"
if is_enabled "mouse"; then pass "full preset: mouse enabled"; else fail "full preset: mouse disabled"; fi
if is_enabled "persistence"; then pass "full preset: persistence enabled"; else fail "full preset: persistence missing"; fi

ENABLED=(); DISABLED=()
_apply_preset "minimal"
if is_enabled "mouse"; then pass "minimal preset: mouse enabled"; else fail "minimal preset: mouse disabled"; fi
if is_enabled "persistence"; then fail "minimal preset: persistence should be disabled"; else pass "minimal preset: persistence disabled"; fi
if is_enabled "border_labels"; then fail "minimal preset: border_labels should be disabled"; else pass "minimal preset: border_labels disabled"; fi

# ── variant_stage defaults ────────────────────────────────────────────────────
section "variant_stage: defaults"

# When called non-interactively (stdin redirected from /dev/null), select
# returns immediately. We can't test the interactive menus, but we can
# verify defaults are set correctly when user presses Enter on each.
# Instead, test that VARIANTS is populated with sensible defaults by
# calling _set_variant_defaults directly.
declare -A VARIANTS=()
_set_variant_defaults
if [ "${VARIANTS[prefix]:-}" = "C-a" ]; then pass "default prefix C-a"; else fail "default prefix not C-a: ${VARIANTS[prefix]:-unset}"; fi
if [ "${VARIANTS[border_style]:-}" = "double" ]; then pass "default border double"; else fail "default border: ${VARIANTS[border_style]:-unset}"; fi
if [ "${VARIANTS[statusbar_style]:-}" = "themed" ]; then pass "default statusbar themed"; else fail "default statusbar: ${VARIANTS[statusbar_style]:-unset}"; fi
if [ "${VARIANTS[scrollback]:-}" = "10000" ]; then pass "default scrollback 10000"; else fail "default scrollback: ${VARIANTS[scrollback]:-unset}"; fi
if [ "${VARIANTS[copy_cmd]:-}" = "auto" ]; then pass "default copy_cmd auto"; else fail "default copy_cmd: ${VARIANTS[copy_cmd]:-unset}"; fi
if [ "${VARIANTS[clock_pos]:-}" = "right" ]; then pass "default clock_pos right"; else fail "default clock_pos: ${VARIANTS[clock_pos]:-unset}"; fi
if [ "${VARIANTS[nowplaying_pos]:-}" = "right" ]; then pass "default nowplaying_pos right"; else fail "default nowplaying_pos: ${VARIANTS[nowplaying_pos]:-unset}"; fi

# ── end-to-end: dry-run output ────────────────────────────────────────────────
section "end-to-end dry-run"

# Simulate a non-interactive run to verify no writes happen
before_local="$(cat "$HOME/.tmux.conf.local" 2>/dev/null | md5 || echo 'absent')"
before_plugins="$(cat "$HOME/.tmux.conf.plugins" 2>/dev/null | md5 || echo 'absent')"

# Call write_local_conf + write_plugins_conf directly in dry-run mode
ENABLED=(mouse vim_nav vi_copy clipboard clock persistence)
DISABLED=(smart_scroll nowplaying border_labels)
declare -A VARIANTS=([prefix]="C-a" [border_style]="double" [statusbar_style]="themed" \
                     [scrollback]="10000" [copy_cmd]="pbcopy" [clock_pos]="right" [nowplaying_pos]="right")
DRY_RUN=true; DOTFILES_OS="macos"
LOCAL_CONF_OUT=""; PLUGINS_CONF_OUT=""
write_local_conf >/dev/null 2>&1 || true
write_plugins_conf >/dev/null 2>&1 || true

after_local="$(cat "$HOME/.tmux.conf.local" 2>/dev/null | md5 || echo 'absent')"
after_plugins="$(cat "$HOME/.tmux.conf.plugins" 2>/dev/null | md5 || echo 'absent')"

if [ "$before_local" = "$after_local" ]; then pass "dry-run: ~/.tmux.conf.local unchanged"; else fail "dry-run: ~/.tmux.conf.local was modified!"; fi
if [ "$before_plugins" = "$after_plugins" ]; then pass "dry-run: ~/.tmux.conf.plugins unchanged"; else fail "dry-run: ~/.tmux.conf.plugins was modified!"; fi

# ── Summary ───────────────────────────────────────────────────────────────────
echo ""
echo "────────────────────────────────"
printf "  passed: %d  failed: %d\n" "$PASS" "$FAIL"
echo "────────────────────────────────"
echo ""

[ "$FAIL" -eq 0 ]
