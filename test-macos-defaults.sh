#!/usr/bin/env bash
# test-macos-defaults.sh — unit tests for macos-defaults.sh
# Only runs on macOS; exits 0 on Linux with a skip message.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PASS=0; FAIL=0

pass()    { echo "  ✓ $1"; PASS=$((PASS + 1)); }
fail()    { echo "  ✗ $1"; FAIL=$((FAIL + 1)); }
section() { echo ""; echo "── $1"; }

if [ "$(uname -s)" != "Darwin" ]; then
  echo "Skipping macos-defaults tests (macOS only)"
  exit 0
fi

# ── Helper: run script in dry-run mode and capture output ─────────────────────
dry_run_output() {
  bash "$SCRIPT_DIR/macos-defaults.sh" "$@" 2>&1 || true
}

# ── Dry-run output: minimal preset ────────────────────────────────────────────
section "Dry-run: minimal preset"

out="$(dry_run_output minimal --dry-run)"

# Should contain expected defaults write commands
if echo "$out" | grep -q "defaults write NSGlobalDomain KeyRepeat"; then
  pass "minimal --dry-run: KeyRepeat command present"
else
  fail "minimal --dry-run: KeyRepeat command missing"
fi

if echo "$out" | grep -q "defaults write NSGlobalDomain InitialKeyRepeat"; then
  pass "minimal --dry-run: InitialKeyRepeat command present"
else
  fail "minimal --dry-run: InitialKeyRepeat command missing"
fi

if echo "$out" | grep -q "defaults write com.apple.screencapture location"; then
  pass "minimal --dry-run: screenshot location command present"
else
  fail "minimal --dry-run: screenshot location command missing"
fi

# Should NOT contain opinionated-only commands
if echo "$out" | grep -q "defaults write com.apple.dock autohide"; then
  fail "minimal --dry-run: should not contain Dock autohide"
else
  pass "minimal --dry-run: Dock autohide correctly absent"
fi

# ── Dry-run output: opinionated preset ────────────────────────────────────────
section "Dry-run: opinionated preset"

out="$(dry_run_output opinionated --dry-run)"

if echo "$out" | grep -q "defaults write com.apple.dock autohide"; then
  pass "opinionated --dry-run: Dock autohide present"
else
  fail "opinionated --dry-run: Dock autohide missing"
fi

if echo "$out" | grep -q "defaults write com.apple.TextEdit RichText"; then
  pass "opinionated --dry-run: TextEdit plain text present"
else
  fail "opinionated --dry-run: TextEdit plain text missing"
fi

# ── Dry-run does not modify system settings ────────────────────────────────────
section "Dry-run: no actual writes"

# Read KeyRepeat before
before="$(defaults read NSGlobalDomain KeyRepeat 2>/dev/null || echo 'unset')"
dry_run_output minimal --dry-run >/dev/null 2>&1 || true
after="$(defaults read NSGlobalDomain KeyRepeat 2>/dev/null || echo 'unset')"

if [ "$before" = "$after" ]; then
  pass "dry-run: KeyRepeat unchanged (before=$before after=$after)"
else
  fail "dry-run: KeyRepeat changed! (before=$before after=$after)"
fi

# ── Argument parsing ──────────────────────────────────────────────────────────
section "Argument parsing"

# Invalid preset should exit non-zero
if bash "$SCRIPT_DIR/macos-defaults.sh" bogus 2>/dev/null; then
  fail "bogus preset: should exit non-zero"
else
  pass "bogus preset: exits with error"
fi

# ── Summary ───────────────────────────────────────────────────────────────────
echo ""
echo "────────────────────────────────"
printf "  passed: %d  failed: %d\n" "$PASS" "$FAIL"
echo "────────────────────────────────"
echo ""

[ "$FAIL" -eq 0 ]
