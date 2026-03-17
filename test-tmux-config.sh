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

# ── Summary ───────────────────────────────────────────────────────────────────
echo ""
echo "────────────────────────────────"
printf "  passed: %d  failed: %d\n" "$PASS" "$FAIL"
echo "────────────────────────────────"
echo ""

[ "$FAIL" -eq 0 ]
