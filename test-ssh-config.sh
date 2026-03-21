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

# ── generate_ssh_config — connection settings ─────────────────────────────────

section "generate_ssh_config — connection settings"

# Helper: run generate_ssh_config with given feature/variant settings
_gen_with() {
  local method="$1" enabled_csv="$2" keepalive="$3" cp="$4"
  SSH_CONFIG_SOURCE_ONLY=1 . "$SCRIPT_DIR/ssh-config.sh"
  AUTH_METHOD="$method"
  IFS=',' read -r -a ENABLED <<< "$enabled_csv"
  DISABLED=()
  declare -gA VARIANTS=([keepalive]="$keepalive" [control_persist]="$cp")
  KEYGEN_PATH=""
  generate_ssh_config
}

# Multiplexing on
out="$(_gen_with fallback "multiplexing,hash_known_hosts" "60" "600")"
echo "$out" | grep -q 'ControlMaster auto' \
  && pass "mux on: ControlMaster present" \
  || fail "mux on: ControlMaster missing"
echo "$out" | grep -q 'ControlPath' \
  && pass "mux on: ControlPath present" \
  || fail "mux on: ControlPath missing"
echo "$out" | grep -q 'ControlPersist 600' \
  && pass "mux on: ControlPersist 600" \
  || fail "mux on: ControlPersist wrong"

# Multiplexing off
out="$(_gen_with fallback "hash_known_hosts" "60" "600")"
! echo "$out" | grep -q 'ControlMaster' \
  && pass "mux off: no ControlMaster" \
  || fail "mux off: ControlMaster should not appear"

# HashKnownHosts on
out="$(_gen_with fallback "multiplexing,hash_known_hosts" "60" "600")"
echo "$out" | grep -q 'HashKnownHosts yes' \
  && pass "hash on: HashKnownHosts yes" \
  || fail "hash on: HashKnownHosts missing"

# HashKnownHosts off
out="$(_gen_with fallback "multiplexing" "60" "600")"
! echo "$out" | grep -q 'HashKnownHosts' \
  && pass "hash off: no HashKnownHosts" \
  || fail "hash off: HashKnownHosts should not appear"

# Keepalive interval 30
out="$(_gen_with fallback "multiplexing" "30" "600")"
echo "$out" | grep -q 'ServerAliveInterval 30' \
  && pass "keepalive: interval 30" \
  || fail "keepalive: interval wrong"

# Keepalive disabled
out="$(_gen_with fallback "multiplexing" "no" "600")"
! echo "$out" | grep -q 'ServerAliveInterval' \
  && pass "keepalive disabled: no ServerAliveInterval" \
  || fail "keepalive disabled: ServerAliveInterval should not appear"

# ── --dry-run output ─────────────────────────────────────────────────────────

section "--dry-run output"

# Non-interactive --dry-run: TTY guard is bypassed when DRY_RUN=true.
# The TUI stages run but immediately hit non-interactive guards where relevant.
# stage_write in dry-run mode prints config content without writing files.
# We use pre-set env vars via SSH_CONFIG_SOURCE_ONLY to test the output directly.
dry_out="$(
  SSH_CONFIG_SOURCE_ONLY=1 . "$SCRIPT_DIR/ssh-config.sh"
  AUTH_METHOD="fallback"
  ENABLED=(multiplexing hash_known_hosts)
  DISABLED=()
  declare -gA VARIANTS=([keepalive]="60" [control_persist]="600")
  KEYGEN_PATH=""
  DRY_RUN=true
  stage_write
)" 2>/dev/null || true

echo "$dry_out" | grep -q 'generated by ssh-config.sh' \
  && pass "--dry-run: config header present in output" \
  || fail "--dry-run: config header missing from output"

echo "$dry_out" | grep -q 'dry-run mode' \
  && pass "--dry-run: dry-run notice present" \
  || fail "--dry-run: dry-run notice missing"

if echo "" | bash "$SCRIPT_DIR/ssh-config.sh" --dry-run >/dev/null 2>&1; then
  pass "--dry-run exits 0 (non-interactive)"
else
  fail "--dry-run exits non-zero (non-interactive)"
fi

# ── Arg parsing ───────────────────────────────────────────────────────────────

section "Arg parsing"

if bash "$SCRIPT_DIR/ssh-config.sh" --status >/dev/null 2>&1; then
  pass "--status exits 0"
else
  fail "--status exits non-zero"
fi

if bash "$SCRIPT_DIR/ssh-config.sh" --badflag >/dev/null 2>&1; then
  fail "--badflag should exit non-zero"
else
  pass "--badflag exits non-zero"
fi

if echo "" | bash "$SCRIPT_DIR/ssh-config.sh" --dry-run >/dev/null 2>&1; then
  pass "--dry-run exits 0 (non-interactive)"
else
  fail "--dry-run exits non-zero (non-interactive)"
fi

# ── Summary ──────────────────────────────────────────────────────────────────

echo ""
echo "────────────────────────────────"
printf "  passed: %d  failed: %d\n" "$PASS" "$FAIL"
echo "────────────────────────────────"
echo ""

[ "$FAIL" -eq 0 ]
