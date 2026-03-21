#!/usr/bin/env bash
# test-font-config.sh — test suite for font-config.sh

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PASS=0; FAIL=0

pass() { echo "  ✓ $1"; PASS=$((PASS + 1)); }
fail() { echo "  ✗ $1"; FAIL=$((FAIL + 1)); }
section() { echo ""; echo "── $1"; }

# ── Syntax ────────────────────────────────────────────────────────────────────
section "Syntax"

if bash -n "$SCRIPT_DIR/font-config.sh" 2>/dev/null; then
  pass "bash -n font-config.sh"
else
  fail "bash -n font-config.sh — syntax error"
fi

# ── Summary ───────────────────────────────────────────────────────────────────
echo ""
echo "────────────────────────────────"
printf "  passed: %d  failed: %d\n" "$PASS" "$FAIL"
echo "────────────────────────────────"
[ "$FAIL" -eq 0 ]
