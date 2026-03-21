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

# ── generate_ssh_config — auth methods ───────────────────────────────────────

section "generate_ssh_config — auth methods"

# Helper: run generate_ssh_config with given auth method
_run_gen() {
  local method="$1"
  # Re-source to get a clean function context
  SSH_CONFIG_SOURCE_ONLY=1 . "$SCRIPT_DIR/ssh-config.sh"
  AUTH_METHOD="$method"
  ENABLED=(multiplexing hash_known_hosts)
  DISABLED=()
  declare -gA VARIANTS=([keepalive]="60" [control_persist]="600")
  KEYGEN_PATH=""
  generate_ssh_config
}

# 1Password mode
out="$(_run_gen 1password)"
echo "$out" | grep -q 'IdentityAgent "~/.1password/agent.sock"' \
  && pass "1password: IdentityAgent present" \
  || fail "1password: IdentityAgent missing"
! echo "$out" | grep -q 'IdentityFile' \
  && pass "1password: no IdentityFile" \
  || fail "1password: IdentityFile should not be present"

# File-based mode
out="$(_run_gen file)"
echo "$out" | grep -q 'IdentityFile' \
  && pass "file: IdentityFile present" \
  || fail "file: IdentityFile missing"
! echo "$out" | grep -q 'IdentityAgent' \
  && pass "file: no IdentityAgent" \
  || fail "file: IdentityAgent should not be present"

# Fallback mode
out="$(_run_gen fallback)"
echo "$out" | grep -q 'IdentityAgent "~/.1password/agent.sock"' \
  && pass "fallback: IdentityAgent present" \
  || fail "fallback: IdentityAgent missing"
echo "$out" | grep -q 'IdentityFile' \
  && pass "fallback: IdentityFile present" \
  || fail "fallback: IdentityFile missing"

# Auth method header comment
out="$(_run_gen 1password)"
echo "$out" | grep -q '# Auth method: 1password' \
  && pass "header comment includes auth method" \
  || fail "header comment missing auth method"

# ── Summary ──────────────────────────────────────────────────────────────────

echo ""
echo "────────────────────────────────"
printf "  passed: %d  failed: %d\n" "$PASS" "$FAIL"
echo "────────────────────────────────"
echo ""

[ "$FAIL" -eq 0 ]
