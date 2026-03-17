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

# ── macOS 13+ version caveat paths ────────────────────────────────────────────
section "macOS 13+ version caveats"

out="$(dry_run_output opinionated --dry-run)"

# On macOS 13+ (this machine is 15+), 24-hour clock write should be skipped
if echo "$out" | grep -q "defaults write com.apple.menuextra.clock Show24Hour"; then
  fail "opinionated --dry-run: 24-hour clock write should be skipped on macOS 13+"
else
  pass "opinionated --dry-run: 24-hour clock write correctly absent on macOS 13+"
fi

# On macOS 13+, Safari warning should be printed
if echo "$out" | grep -q "Safari defaults write is ignored on macOS 13+"; then
  pass "opinionated --dry-run: Safari macOS 13+ warning present"
else
  fail "opinionated --dry-run: Safari macOS 13+ warning missing"
fi

# ── Dry-run does not modify system settings ────────────────────────────────────
section "Dry-run: no actual writes"

# Read two keys before — one from minimal preset, one from opinionated-only
before_kr="$(defaults read NSGlobalDomain KeyRepeat 2>/dev/null || echo 'unset')"
before_dock="$(defaults read com.apple.dock autohide 2>/dev/null || echo 'unset')"
dry_run_output opinionated --dry-run >/dev/null 2>&1 || true
after_kr="$(defaults read NSGlobalDomain KeyRepeat 2>/dev/null || echo 'unset')"
after_dock="$(defaults read com.apple.dock autohide 2>/dev/null || echo 'unset')"

if [ "$before_kr" = "$after_kr" ]; then
  pass "dry-run: KeyRepeat unchanged (before=$before_kr after=$after_kr)"
else
  fail "dry-run: KeyRepeat changed! (before=$before_kr after=$after_kr)"
fi

if [ "$before_dock" = "$after_dock" ]; then
  pass "dry-run: Dock autohide unchanged (before=$before_dock after=$after_dock)"
else
  fail "dry-run: Dock autohide changed! (before=$before_dock after=$after_dock)"
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
