# TouchID sudo + tmux Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add `touchid-sudo.sh` — a safe, idempotent script that enables TouchID for sudo in iTerm2 and tmux, with a LaunchDaemon-based emergency revert that requires no sudo, no osascript, and no Recovery Mode.

**Architecture:** A standalone `*-config.sh`-pattern bash script with three modes (`install`, `--revert`, `--status`) plus `--dry-run` for testability. A root-owned LaunchDaemon watchdog is pre-staged before any PAM changes so an emergency revert (`touch /tmp/.revert-touchid-sudo`) is always available. PAM control flags (`optional` + `sufficient`) guarantee password auth is never blocked regardless of module failures.

**Tech Stack:** bash, macOS PAM (`/etc/pam.d/sudo_local`), launchd (`WatchPaths`), Homebrew (`pam-reattach`)

**Spec:** `docs/superpowers/specs/2026-03-19-touchid-sudo-design.md`

---

## File Map

| File | Action | Responsibility |
|---|---|---|
| `touchid-sudo.sh` | Create | Main script — install/revert/status/dry-run modes |
| `test-touchid-sudo.sh` | Create | Test suite — output-based, no system writes, macOS-only |
| `Brewfile` | Modify | Add `pam-reattach` dependency |
| `HANDBOOK.md` | Modify | Add TouchID sudo section with emergency revert instructions |
| `test.sh` | Modify | Add `syntax_check touchid-sudo.sh` + call `test-touchid-sudo.sh` |

Runtime files (not in repo):
- `/etc/pam.d/sudo_local` — created by install, deleted by revert/watchdog
- `/Library/LaunchDaemons/com.dotfiles.touchid-sudo-revert.plist` — created by install, deleted by revert

---

## Task 1: Brewfile

**Files:**
- Modify: `Brewfile`

- [ ] **Step 1: Read Brewfile to find the right insertion point**

```bash
grep -n 'brew "p' Brewfile
```

- [ ] **Step 2: Add pam-reattach**

Add this line to `Brewfile` in alphabetical order among the `brew` entries:

```
brew "pam-reattach"
```

- [ ] **Step 3: Commit**

```bash
git add Brewfile
git commit -m "feat: add pam-reattach to Brewfile"
```

---

## Task 2: Script skeleton + test skeleton

**Files:**
- Create: `touchid-sudo.sh`
- Create: `test-touchid-sudo.sh`

- [ ] **Step 1: Write failing syntax test**

Create `test-touchid-sudo.sh`:

```bash
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

# ── Summary ───────────────────────────────────────────────────────────────────
echo ""
echo "────────────────────────────────"
printf "  passed: %d  failed: %d\n" "$PASS" "$FAIL"
echo "────────────────────────────────"
echo ""

[ "$FAIL" -eq 0 ]
```

- [ ] **Step 2: Run test — expect fail (file not found)**

```bash
bash test-touchid-sudo.sh
```

Expected: `✗ bash -n touchid-sudo.sh — syntax error` (or file-not-found error)

- [ ] **Step 3: Create touchid-sudo.sh skeleton**

```bash
#!/usr/bin/env bash
# ============================================================================
# touchid-sudo.sh — enable TouchID for sudo (iTerm2 + tmux)
#
# Usage:
#   ./touchid-sudo.sh              # install
#   ./touchid-sudo.sh --revert     # clean uninstall (requires working sudo)
#   ./touchid-sudo.sh --status     # show current state
#   ./touchid-sudo.sh --dry-run    # show what would be written, no changes
# ============================================================================
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=platform.sh
. "$SCRIPT_DIR/platform.sh"

# ── Colors ────────────────────────────────────────────────────────────────────
BOLD='\033[1m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
RED='\033[0;31m'
CYAN='\033[0;36m'
RESET='\033[0m'

info()    { echo -e "  ${CYAN}${1}${RESET}"; }
success() { echo -e "  ${GREEN}✓${RESET}  ${1}"; }
warn()    { echo -e "  ${YELLOW}!${RESET}  ${1}"; }
error()   { echo -e "  ${RED}✗${RESET}  ${1}" >&2; }
header()  { echo -e "\n${BOLD}${1}${RESET}"; }

# ── macOS guard ───────────────────────────────────────────────────────────────
if [ "$DOTFILES_OS" != "macos" ]; then
  info "Skipping TouchID sudo setup (macOS only)"
  exit 0
fi

# ── Arg parsing ───────────────────────────────────────────────────────────────
COMMAND="install"
case "${1:-}" in
  --revert)   COMMAND="revert" ;;
  --status)   COMMAND="status" ;;
  --dry-run)  COMMAND="dry-run" ;;
  "")         COMMAND="install" ;;
  *)
    echo "Usage: $0 [--revert|--status|--dry-run]" >&2
    exit 1
    ;;
esac

# ── Main dispatch (stubs) ─────────────────────────────────────────────────────
case "$COMMAND" in
  install)  echo "install: not yet implemented" ;;
  revert)   echo "revert: not yet implemented" ;;
  status)   echo "status: not yet implemented" ;;
  dry-run)  echo "dry-run: not yet implemented" ;;
esac
```

- [ ] **Step 4: Run test — expect pass**

```bash
bash test-touchid-sudo.sh
```

Expected: `✓ bash -n touchid-sudo.sh`

- [ ] **Step 5: Commit**

```bash
git add touchid-sudo.sh test-touchid-sudo.sh
git commit -m "feat: touchid-sudo.sh skeleton + test skeleton"
```

---

## Task 3: Helper functions + dry-run mode

**Files:**
- Modify: `touchid-sudo.sh`
- Modify: `test-touchid-sudo.sh`

These helpers produce the content that will be written to disk. Testing them via
`--dry-run` output verifies the critical logic without touching any system files.

- [ ] **Step 1: Write failing dry-run tests**

Append to `test-touchid-sudo.sh`, before the summary block:

```bash
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
```

- [ ] **Step 2: Run tests — expect failures on the new checks**

```bash
bash test-touchid-sudo.sh
```

Expected: new dry-run tests fail (output is still the stub message)

- [ ] **Step 3: Implement helpers + dry-run in touchid-sudo.sh**

Replace the `# ── Main dispatch (stubs)` section and everything below it with:

```bash
# ── Helpers ───────────────────────────────────────────────────────────────────
BACKUP_DIR="$HOME/.dotfiles-backups"
DAEMON_LABEL="com.dotfiles.touchid-sudo-revert"
DAEMON_PLIST="/Library/LaunchDaemons/${DAEMON_LABEL}.plist"
PAM_SUDO_LOCAL="/etc/pam.d/sudo_local"

brew_prefix() {
  brew --prefix 2>/dev/null
}

pam_reattach_path() {
  echo "$(brew_prefix)/lib/pam/pam_reattach.so"
}

plist_content() {
  cat <<EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN"
  "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>Label</key>
    <string>${DAEMON_LABEL}</string>
    <key>WatchPaths</key>
    <array>
        <string>/private/tmp/.revert-touchid-sudo</string>
    </array>
    <key>ProgramArguments</key>
    <array>
        <string>/bin/sh</string>
        <string>-c</string>
        <string>rm -f ${PAM_SUDO_LOCAL} /private/tmp/.revert-touchid-sudo</string>
    </array>
    <key>RunAtLoad</key>
    <false/>
</dict>
</plist>
EOF
}

sudo_local_content() {
  local reattach_path
  reattach_path="$(pam_reattach_path)"
  cat <<EOF
# sudo_local — managed by touchid-sudo.sh
# Emergency revert (no sudo needed): touch /tmp/.revert-touchid-sudo
auth       optional       ${reattach_path}
auth       sufficient     pam_tid.so
EOF
}

# ── dry-run ───────────────────────────────────────────────────────────────────
cmd_dry_run() {
  header "TouchID sudo — dry run (no changes made)"

  echo ""
  info "Would write to: ${PAM_SUDO_LOCAL}"
  echo "────────────────────────────────────────────"
  sudo_local_content
  echo "────────────────────────────────────────────"

  echo ""
  info "Would write to: ${DAEMON_PLIST}"
  echo "────────────────────────────────────────────"
  plist_content
  echo "────────────────────────────────────────────"
}

# ── status ────────────────────────────────────────────────────────────────────
cmd_status() {
  header "TouchID sudo — status"

  echo ""
  if [ -f "$PAM_SUDO_LOCAL" ]; then
    success "sudo_local installed at ${PAM_SUDO_LOCAL}"
    echo ""
    cat "$PAM_SUDO_LOCAL"
    echo ""
  else
    warn "sudo_local not installed (${PAM_SUDO_LOCAL} missing)"
  fi

  local reattach_path
  reattach_path="$(pam_reattach_path)"
  if [ -f "$reattach_path" ]; then
    success "pam_reattach.so found at ${reattach_path}"
  else
    warn "pam_reattach.so not found at ${reattach_path} — run: brew install pam-reattach"
  fi

  if launchctl list "$DAEMON_LABEL" >/dev/null 2>&1; then
    success "LaunchDaemon loaded (${DAEMON_LABEL})"
  else
    warn "LaunchDaemon not loaded"
  fi

  echo ""
  info "To test sudo:  sudo echo ok"
}

# ── install ───────────────────────────────────────────────────────────────────
cmd_install() {
  header "TouchID sudo — install"
  echo ""

  # Step 1: install pam-reattach if needed
  local reattach_path
  reattach_path="$(pam_reattach_path)"
  if [ ! -f "$reattach_path" ]; then
    info "Installing pam-reattach via Homebrew..."
    brew install pam-reattach
  fi

  # Step 2: verify path exists (abort before touching anything)
  if [ ! -f "$reattach_path" ]; then
    error "pam_reattach.so not found at ${reattach_path} after install — aborting"
    exit 1
  fi
  success "pam_reattach.so verified at ${reattach_path}"

  # Step 3: install LaunchDaemon (emergency revert — must happen before PAM change)
  if launchctl list "$DAEMON_LABEL" >/dev/null 2>&1; then
    success "LaunchDaemon already loaded — skipping bootstrap"
  else
    info "Installing emergency revert LaunchDaemon..."
    local tmp_plist
    tmp_plist="$(mktemp)"
    plist_content > "$tmp_plist"
    sudo cp "$tmp_plist" "$DAEMON_PLIST"
    rm -f "$tmp_plist"
    sudo chown root:wheel "$DAEMON_PLIST"
    sudo chmod 644 "$DAEMON_PLIST"
    sudo launchctl bootstrap system "$DAEMON_PLIST"
    success "LaunchDaemon installed and loaded"
  fi

  # Step 4: backup existing sudo_local if present
  mkdir -p "$BACKUP_DIR"
  if [ -f "$PAM_SUDO_LOCAL" ]; then
    cp "$PAM_SUDO_LOCAL" "$BACKUP_DIR/sudo_local.bak"
    info "Backed up existing sudo_local to ${BACKUP_DIR}/sudo_local.bak"
  fi

  # Step 5: write sudo_local atomically
  local tmp_pam
  tmp_pam="$(mktemp)"
  chmod 600 "$tmp_pam"
  sudo_local_content > "$tmp_pam"

  # Verify content before copying
  if ! grep -q "optional.*pam_reattach.so" "$tmp_pam"; then
    rm -f "$tmp_pam"
    error "Content verification failed: pam_reattach.so line missing — aborting"
    exit 1
  fi
  if ! grep -q "sufficient.*pam_tid.so" "$tmp_pam"; then
    rm -f "$tmp_pam"
    error "Content verification failed: pam_tid.so line missing — aborting"
    exit 1
  fi

  sudo cp "$tmp_pam" "$PAM_SUDO_LOCAL"
  rm -f "$tmp_pam"

  # Step 6: verify post-copy content
  if ! grep -q "optional.*pam_reattach.so" "$PAM_SUDO_LOCAL"; then
    error "Post-copy verification failed — triggering emergency revert"
    touch /tmp/.revert-touchid-sudo
    exit 1
  fi
  if ! grep -q "sufficient.*pam_tid.so" "$PAM_SUDO_LOCAL"; then
    error "Post-copy verification failed — triggering emergency revert"
    touch /tmp/.revert-touchid-sudo
    exit 1
  fi

  success "sudo_local written and verified"

  # Step 7: print success + emergency instructions
  print_success
}

# ── revert ────────────────────────────────────────────────────────────────────
cmd_revert() {
  header "TouchID sudo — revert"
  echo ""
  warn "This requires working sudo."
  echo ""

  if [ -f "$PAM_SUDO_LOCAL" ]; then
    sudo rm -f "$PAM_SUDO_LOCAL"
    success "Removed ${PAM_SUDO_LOCAL}"
  else
    info "sudo_local not present — nothing to remove"
  fi

  if launchctl list "$DAEMON_LABEL" >/dev/null 2>&1; then
    sudo launchctl bootout system "$DAEMON_PLIST" 2>/dev/null || true
    success "LaunchDaemon unloaded"
  fi

  if [ -f "$DAEMON_PLIST" ]; then
    sudo rm -f "$DAEMON_PLIST"
    success "Removed ${DAEMON_PLIST}"
  fi

  echo ""
  success "Reverted. Run: sudo echo ok — to confirm sudo is clean"
}

# ── post-install message ──────────────────────────────────────────────────────
print_success() {
  echo ""
  success "TouchID sudo installed."
  echo ""
  info "To test:"
  echo "    Native terminal:  sudo echo ok"
  echo "    tmux session:     open a new tmux window, then: sudo echo ok"
  echo ""
  echo -e "  ${BOLD}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${RESET}"
  echo -e "  ${RED}${BOLD}EMERGENCY REVERT — no sudo, no osascript, no GUI needed:${RESET}"
  echo "    touch /tmp/.revert-touchid-sudo"
  echo ""
  echo "    Works even with completely broken sudo."
  echo "    If nothing happens in 30s:"
  echo "    launchctl kickstart system/${DAEMON_LABEL}"
  echo ""
  echo "  Clean uninstall (when sudo is working):"
  echo "    ./touchid-sudo.sh --revert"
  echo -e "  ${BOLD}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${RESET}"
  echo ""
}

# ── Main dispatch ─────────────────────────────────────────────────────────────
case "$COMMAND" in
  install)  cmd_install ;;
  revert)   cmd_revert ;;
  status)   cmd_status ;;
  dry-run)  cmd_dry_run ;;
esac
```

- [ ] **Step 4: Run tests — expect all pass**

```bash
bash test-touchid-sudo.sh
```

Expected: all tests pass including the 5 new dry-run checks

- [ ] **Step 5: Commit**

```bash
git add touchid-sudo.sh test-touchid-sudo.sh
git commit -m "feat: touchid-sudo.sh helpers, dry-run, status, install, revert"
```

---

## Task 4: Arg parsing tests

**Files:**
- Modify: `test-touchid-sudo.sh`

- [ ] **Step 1: Write failing arg parsing tests**

Append to `test-touchid-sudo.sh`, before the summary block:

```bash
# ── Arg parsing ───────────────────────────────────────────────────────────────
section "Arg parsing"

# Invalid arg should exit non-zero
if ! bash "$SCRIPT_DIR/touchid-sudo.sh" --invalid-flag >/dev/null 2>&1; then
  pass "invalid flag exits non-zero"
else
  fail "invalid flag should exit non-zero"
fi

# --status exits 0 even when not installed
if bash "$SCRIPT_DIR/touchid-sudo.sh" --status >/dev/null 2>&1; then
  pass "--status exits 0"
else
  fail "--status should exit 0"
fi

# --dry-run exits 0
if bash "$SCRIPT_DIR/touchid-sudo.sh" --dry-run >/dev/null 2>&1; then
  pass "--dry-run exits 0"
else
  fail "--dry-run should exit 0"
fi
```

- [ ] **Step 2: Run tests — expect pass (implementation already handles these)**

```bash
bash test-touchid-sudo.sh
```

Expected: all tests pass

- [ ] **Step 3: Commit**

```bash
git add test-touchid-sudo.sh
git commit -m "test: add arg parsing tests to test-touchid-sudo.sh"
```

---

## Task 5: Wire into test.sh + HANDBOOK.md

**Files:**
- Modify: `test.sh`
- Modify: `HANDBOOK.md`

- [ ] **Step 1: Add syntax_check to test.sh**

In `test.sh`, find the `syntax_check` calls block (around line 168) and add:

```bash
syntax_check touchid-sudo.sh
```

- [ ] **Step 2: Add test-touchid-sudo.sh section to test.sh**

After the `tmux Config` section (around line 212), add:

```bash
# ════════════════════════════════════════════════
section "TouchID sudo — test-touchid-sudo.sh"
# ════════════════════════════════════════════════

if [ "$(uname -s)" != "Darwin" ]; then
  warn "test-touchid-sudo.sh skipped (macOS only)"
elif bash "$SCRIPT_DIR/test-touchid-sudo.sh" >/dev/null 2>&1; then
  pass "test-touchid-sudo.sh passed"
else
  fail "test-touchid-sudo.sh — one or more checks failed (run ./test-touchid-sudo.sh for details)"
fi
```

- [ ] **Step 3: Run test.sh to confirm no regressions**

```bash
bash test.sh
```

Expected: all existing tests pass + new `touchid-sudo.sh` syntax check passes + `test-touchid-sudo.sh` passes

- [ ] **Step 4: Add HANDBOOK.md section**

Append to `HANDBOOK.md` (at end of file, or after the macOS section if one exists):

```markdown
---

## TouchID sudo

TouchID authentication for `sudo` in iTerm2 and tmux.

### Setup

```bash
./touchid-sudo.sh
```

Test it in a native terminal window and in a new tmux session:

```bash
sudo echo ok
```

### How it works

Creates `/etc/pam.d/sudo_local` with:
- `pam_reattach.so` (`optional`) — reattaches tmux to the correct bootstrap port
- `pam_tid.so` (`sufficient`) — TouchID auth; falls through to password on failure

Password auth is never blocked. `sudo_local` survives macOS system updates.

### Status

```bash
./touchid-sudo.sh --status
```

### Emergency revert — no sudo needed

If sudo breaks for any reason, a root LaunchDaemon watches for a trigger file:

```bash
touch /tmp/.revert-touchid-sudo
```

This removes `/etc/pam.d/sudo_local` as root via launchd — no sudo, no osascript, no GUI, no Recovery Mode required. Works headlessly, over SSH, inside tmux.

If nothing happens within 30 seconds:

```bash
launchctl kickstart system/com.dotfiles.touchid-sudo-revert
```

Note: `kickstart` requires admin group membership and may prompt for a password in a GUI session. If unavailable (headless/SSH), reboot — the daemon reloads and a fresh `touch /tmp/.revert-touchid-sudo` will trigger it.

### Clean uninstall

```bash
./touchid-sudo.sh --revert
```

Removes `sudo_local` and the LaunchDaemon. Requires working sudo.
```

- [ ] **Step 5: Commit**

```bash
git add test.sh HANDBOOK.md
git commit -m "feat: wire touchid-sudo.sh into test.sh and HANDBOOK.md"
```

---

## Task 6: Make script executable + final test run

**Files:**
- Modify: `touchid-sudo.sh` (chmod)

- [ ] **Step 1: Make executable**

```bash
chmod +x touchid-sudo.sh
git add touchid-sudo.sh
git diff --cached touchid-sudo.sh  # verify mode change
```

- [ ] **Step 2: Full test suite**

```bash
bash test.sh
```

Expected output (macOS):
```
── Linux Platform — Syntax Checks
  ✓ bash -n touchid-sudo.sh

── TouchID sudo — test-touchid-sudo.sh
  ✓ test-touchid-sudo.sh passed
```

All other existing tests should still pass.

- [ ] **Step 3: Manual dry-run verification**

```bash
./touchid-sudo.sh --dry-run
```

Expected: shows the PAM config with your actual `brew --prefix` path (e.g., `/opt/homebrew/lib/pam/pam_reattach.so`) and the full LaunchDaemon plist with `/private/tmp/.revert-touchid-sudo`.

- [ ] **Step 4: Manual status check**

```bash
./touchid-sudo.sh --status
```

Expected: reports sudo_local not installed, shows pam_reattach.so status, shows LaunchDaemon not loaded.

- [ ] **Step 5: Commit**

```bash
git add touchid-sudo.sh
git commit -m "feat: make touchid-sudo.sh executable"
```

---

## Post-Implementation: Manual install

After all tests pass, run the actual install interactively:

```bash
./touchid-sudo.sh
```

Then test in a **new** terminal window:
```bash
sudo echo ok   # should prompt for TouchID
```

Then test in a **new tmux session**:
```bash
sudo echo ok   # should prompt for TouchID
```

Emergency revert is always available if anything goes wrong:
```bash
touch /tmp/.revert-touchid-sudo
```
