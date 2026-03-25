#!/usr/bin/env bash
# test-ssh-config.sh — test suite for ssh-config.sh (macOS only)
# shellcheck disable=SC2031  # SCRIPT_DIR false positive: set via $() at top level

if [ "$(uname -s)" != "Darwin" ]; then
  echo "  ! test-ssh-config.sh skipped (macOS only)"
  exit 0
fi

# shellcheck disable=SC2031  # SCRIPT_DIR set via $() — SC2031 false positive
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

# shellcheck disable=SC1091  # ssh-config.sh not specified as input
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
  # shellcheck disable=SC1091  # ssh-config.sh not specified as input
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
if echo "$out" | grep -q 'IdentityAgent "~/.1password/agent.sock"'; then pass "1password: IdentityAgent present"; else fail "1password: IdentityAgent missing"; fi
if ! echo "$out" | grep -q 'IdentityFile'; then pass "1password: no IdentityFile"; else fail "1password: IdentityFile should not be present"; fi

# File-based mode
out="$(_run_gen file)"
if echo "$out" | grep -q 'IdentityFile'; then pass "file: IdentityFile present"; else fail "file: IdentityFile missing"; fi
if ! echo "$out" | grep -q 'IdentityAgent'; then pass "file: no IdentityAgent"; else fail "file: IdentityAgent should not be present"; fi

# Fallback mode
out="$(_run_gen fallback)"
if echo "$out" | grep -q 'IdentityAgent "~/.1password/agent.sock"'; then pass "fallback: IdentityAgent present"; else fail "fallback: IdentityAgent missing"; fi
if echo "$out" | grep -q 'IdentityFile'; then pass "fallback: IdentityFile present"; else fail "fallback: IdentityFile missing"; fi

# Auth method header comment
out="$(_run_gen 1password)"
if echo "$out" | grep -q '# Auth method: 1password'; then pass "header comment includes auth method"; else fail "header comment missing auth method"; fi

# ── generate_ssh_config — connection settings ─────────────────────────────────

section "generate_ssh_config — connection settings"

# Helper: run generate_ssh_config with given feature/variant settings
_gen_with() {
  local method="$1" enabled_csv="$2" keepalive="$3" cp="$4"
  # shellcheck disable=SC1091  # ssh-config.sh not specified as input
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
if echo "$out" | grep -q 'ControlMaster auto'; then pass "mux on: ControlMaster present"; else fail "mux on: ControlMaster missing"; fi
if echo "$out" | grep -q 'ControlPath'; then pass "mux on: ControlPath present"; else fail "mux on: ControlPath missing"; fi
if echo "$out" | grep -q 'ControlPersist 600'; then pass "mux on: ControlPersist 600"; else fail "mux on: ControlPersist wrong"; fi

# Multiplexing off
out="$(_gen_with fallback "hash_known_hosts" "60" "600")"
if ! echo "$out" | grep -q 'ControlMaster'; then pass "mux off: no ControlMaster"; else fail "mux off: ControlMaster should not appear"; fi

# HashKnownHosts on
out="$(_gen_with fallback "multiplexing,hash_known_hosts" "60" "600")"
if echo "$out" | grep -q 'HashKnownHosts yes'; then pass "hash on: HashKnownHosts yes"; else fail "hash on: HashKnownHosts missing"; fi

# HashKnownHosts off
out="$(_gen_with fallback "multiplexing" "60" "600")"
if ! echo "$out" | grep -q 'HashKnownHosts'; then pass "hash off: no HashKnownHosts"; else fail "hash off: HashKnownHosts should not appear"; fi

# Keepalive interval 30
out="$(_gen_with fallback "multiplexing" "30" "600")"
if echo "$out" | grep -q 'ServerAliveInterval 30'; then pass "keepalive: interval 30"; else fail "keepalive: interval wrong"; fi

# Keepalive disabled
out="$(_gen_with fallback "multiplexing" "no" "600")"
if ! echo "$out" | grep -q 'ServerAliveInterval'; then pass "keepalive disabled: no ServerAliveInterval"; else fail "keepalive disabled: ServerAliveInterval should not appear"; fi

# ── --dry-run output ─────────────────────────────────────────────────────────

section "--dry-run output"

# Non-interactive --dry-run: TTY guard is bypassed when DRY_RUN=true.
# The TUI stages run but immediately hit non-interactive guards where relevant.
# stage_write in dry-run mode prints config content without writing files.
# We use pre-set env vars via SSH_CONFIG_SOURCE_ONLY to test the output directly.
dry_out="$(
  # shellcheck disable=SC1091  # ssh-config.sh not specified as input
  SSH_CONFIG_SOURCE_ONLY=1 . "$SCRIPT_DIR/ssh-config.sh"
  # shellcheck disable=SC2034  # vars used by sourced script
  AUTH_METHOD="fallback"
  # shellcheck disable=SC2034
  ENABLED=(multiplexing hash_known_hosts)
  # shellcheck disable=SC2034
  DISABLED=()
  # shellcheck disable=SC2034
  declare -gA VARIANTS=([keepalive]="60" [control_persist]="600")
  # shellcheck disable=SC2034
  KEYGEN_PATH=""
  # shellcheck disable=SC2034
  DRY_RUN=true
  stage_write
)" 2>/dev/null || true

if echo "$dry_out" | grep -q 'generated by ssh-config.sh'; then pass "--dry-run: config header present in output"; else fail "--dry-run: config header missing from output"; fi

if echo "$dry_out" | grep -q 'dry-run mode'; then pass "--dry-run: dry-run notice present"; else fail "--dry-run: dry-run notice missing"; fi

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

# ── Summary ──────────────────────────────────────────────────────────────────

echo ""
echo "────────────────────────────────"
printf "  passed: %d  failed: %d\n" "$PASS" "$FAIL"
echo "────────────────────────────────"
echo ""

[ "$FAIL" -eq 0 ]
