#!/usr/bin/env bash
# test-touchid-sudo.sh — tests for touchid-sudo.sh
# Only runs on macOS; exits 0 on Linux with a skip message.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PASS=0; FAIL=0

pass()    { echo "  ✓ $1"; PASS=$((PASS + 1)); }
fail()    { echo "  ✗ $1"; FAIL=$((FAIL + 1)); }
section() { echo ""; echo "── $1"; }

if [ "$(uname -s)" != "Darwin" ]; then
  echo "Skipping touchid-sudo tests (macOS only)"
  exit 0
fi

# ── Syntax check ──────────────────────────────────────────────────────────────
section "Syntax"

if bash -n "$SCRIPT_DIR/touchid-sudo.sh" 2>/dev/null; then
  pass "bash -n touchid-sudo.sh"
else
  fail "bash -n touchid-sudo.sh — syntax error"
fi

# ── dry-run output ────────────────────────────────────────────────────────────
section "dry-run output"

dry_run_out() { bash "$SCRIPT_DIR/touchid-sudo.sh" --dry-run 2>&1 || true; }
out="$(dry_run_out)"

# PAM config must use optional for pam_reattach
if echo "$out" | grep -q "optional.*pam_reattach.so"; then
  pass "dry-run: pam_reattach uses optional control flag"
else
  fail "dry-run: pam_reattach optional flag missing"
fi

# PAM config must use sufficient for pam_tid.so
if echo "$out" | grep -q "sufficient.*pam_tid.so"; then
  pass "dry-run: pam_tid.so uses sufficient control flag"
else
  fail "dry-run: pam_tid.so sufficient flag missing"
fi

# Plist must watch /private/tmp (not /tmp symlink)
if echo "$out" | grep -q "/private/tmp/.revert-touchid-sudo"; then
  pass "dry-run: plist WatchPaths uses /private/tmp resolved path"
else
  fail "dry-run: plist WatchPaths should use /private/tmp not /tmp"
fi

# Plist RunAtLoad must be false
if echo "$out" | grep -q "<false/>"; then
  pass "dry-run: plist RunAtLoad is false"
else
  fail "dry-run: plist RunAtLoad should be false"
fi

# PAM config path must use brew --prefix (not hardcoded /opt/homebrew)
BREW_PREFIX="$(brew --prefix 2>/dev/null || true)"
if [ -n "$BREW_PREFIX" ] && echo "$out" | grep -q "${BREW_PREFIX}/lib/pam/pam_reattach.so"; then
  pass "dry-run: pam_reattach path uses brew --prefix (${BREW_PREFIX})"
else
  fail "dry-run: pam_reattach path should contain brew --prefix"
fi

# ── Summary ───────────────────────────────────────────────────────────────────
echo ""
echo "────────────────────────────────"
printf "  passed: %d  failed: %d\n" "$PASS" "$FAIL"
echo "────────────────────────────────"
echo ""

[ "$FAIL" -eq 0 ]
