#!/usr/bin/env bash
# test-dock-config.sh — tests for dock-config.sh
# macOS-only; exits 0 on Linux with a skip message.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PASS=0; FAIL=0

pass()    { echo "  ✓ $1"; PASS=$((PASS + 1)); }
fail()    { echo "  ✗ $1"; FAIL=$((FAIL + 1)); }
section() { echo ""; echo "── $1"; }

if [ "$(uname -s)" != "Darwin" ]; then
  echo "Skipping dock-config tests (macOS only)"
  exit 0
fi

# ── Syntax check ──────────────────────────────────────────────────────────────
section "Syntax"

if bash -n "$SCRIPT_DIR/dock-config.sh" 2>/dev/null; then
  pass "bash -n dock-config.sh"
else
  fail "bash -n dock-config.sh — syntax error"
fi

# ── Summary ───────────────────────────────────────────────────────────────────
echo ""
echo "────────────────────────────────"
printf "  passed: %d  failed: %d\n" "$PASS" "$FAIL"
echo "────────────────────────────────"
echo ""

[ "$FAIL" -eq 0 ]
