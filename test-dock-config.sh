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

# ── dry-run output ────────────────────────────────────────────────────────────
section "dry-run output"

# Build a fixture config dir with a known config
FIXTURE_DIR="$(mktemp -d)"
trap 'rm -rf "$FIXTURE_DIR"' EXIT
cat > "$FIXTURE_DIR/work.txt" <<'EOF'
# dock-position: left
# dock-clear: yes
/Applications/Finder.app
---
/Applications/Arc.app
EOF

dry_out() {
  DOCK_CONFIG_DIR="$FIXTURE_DIR" \
    bash "$SCRIPT_DIR/dock-config.sh" --apply work --dry-run 2>&1 || true
}
out="$(dry_out)"

# dockutil --remove all must appear
if echo "$out" | grep -q "dockutil --remove all"; then
  pass "dry-run: dockutil --remove all appears"
else
  fail "dry-run: dockutil --remove all missing"
fi

# /Applications/Finder.app must appear
if echo "$out" | grep -q "/Applications/Finder.app"; then
  pass "dry-run: /Applications/Finder.app appears"
else
  fail "dry-run: /Applications/Finder.app missing from output"
fi

# spacer command must appear (from --- line in fixture)
if echo "$out" | grep -q "type spacer"; then
  pass "dry-run: spacer command (--type spacer) appears"
else
  fail "dry-run: spacer command missing"
fi

# killall Dock must appear
if echo "$out" | grep -q "killall Dock"; then
  pass "dry-run: killall Dock appears"
else
  fail "dry-run: killall Dock missing"
fi

rm -rf "$FIXTURE_DIR"

# ── Summary ───────────────────────────────────────────────────────────────────
echo ""
echo "────────────────────────────────"
printf "  passed: %d  failed: %d\n" "$PASS" "$FAIL"
echo "────────────────────────────────"
echo ""

[ "$FAIL" -eq 0 ]
