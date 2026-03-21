#!/usr/bin/env bash
# test-ssh-config.sh — test suite for ssh-config.sh (macOS only)

if [ "$(uname -s)" != "Darwin" ]; then
  echo "  ! test-ssh-config.sh skipped (macOS only)"
  exit 0
fi

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PASS=0; FAIL=0

pass() { echo "  ✓ $1"; PASS=$((PASS + 1)); }
fail() { echo "  ✗ $1"; FAIL=$((FAIL + 1)); }

section() { echo ""; echo "── $1"; }

# ── Syntax check ─────────────────────────────────────────────────────────────

section "Syntax"

if bash -n "$SCRIPT_DIR/ssh-config.sh" 2>/dev/null; then
  pass "bash -n ssh-config.sh"
else
  fail "bash -n ssh-config.sh — syntax error"
fi

# ── generate_ssh_config — stub check ─────────────────────────────────────────

section "generate_ssh_config (source-only)"

SSH_CONFIG_SOURCE_ONLY=1 . "$SCRIPT_DIR/ssh-config.sh"

if declare -f generate_ssh_config >/dev/null 2>&1; then
  pass "generate_ssh_config function defined"
else
  fail "generate_ssh_config function not defined"
fi

# ── Summary ──────────────────────────────────────────────────────────────────

echo ""
echo "────────────────────────────────"
printf "  passed: %d  failed: %d\n" "$PASS" "$FAIL"
echo "────────────────────────────────"
echo ""

[ "$FAIL" -eq 0 ]
