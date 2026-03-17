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

# ── Summary ───────────────────────────────────────────────────────────────────
echo ""
echo "────────────────────────────────"
printf "  passed: %d  failed: %d\n" "$PASS" "$FAIL"
echo "────────────────────────────────"
echo ""

[ "$FAIL" -eq 0 ]
