# TouchID sudo + tmux — Design Spec

**Date:** 2026-03-19
**Status:** Approved

---

## Problem

macOS's default sudo requires a password. TouchID can authenticate sudo in a native
terminal, but not in tmux — tmux detaches from the login session's bootstrap port
that the TouchID PAM module (`pam_tid.so`) requires.

A previous attempt to fix this broke sudo entirely by using the wrong path for
`pam_reattach.so` (Intel path on Apple Silicon) with a `required` control flag,
locking the user out of sudo with no fallback.

---

## Goals

- TouchID works for sudo in iTerm2 native windows
- TouchID works for sudo inside tmux sessions
- Password fallback always works — sudo is never fully broken
- Emergency revert requires no sudo, no osascript, no GUI, no Recovery Mode
- Fits the dotfiles `*-config.sh` script pattern
- Idempotent: safe to re-run

---

## Non-Goals

- Linux support (macOS only)
- Integration into `install-all.sh` (run explicitly, not automatically)
- Supporting other terminals beyond iTerm2 / tmux

---

## PAM Configuration

The script creates `/etc/pam.d/sudo_local` — the macOS-blessed override file.
It is already `include`d by `/etc/pam.d/sudo` and survives system updates.
The script never modifies `/etc/pam.d/sudo` directly.

```
# sudo_local — managed by touchid-sudo.sh
# Emergency revert (no sudo needed): touch /tmp/.revert-touchid-sudo
auth       optional       /opt/homebrew/lib/pam/pam_reattach.so
auth       sufficient     pam_tid.so
```

**Control flags — why:**

| Module | Flag | Behaviour on failure |
|---|---|---|
| `pam_reattach.so` | `optional` | Module fails / path wrong → ignored, auth continues |
| `pam_tid.so` | `sufficient` | TouchID fails → falls through to password |

This guarantees `pam_opendirectory.so` (the password line in `/etc/pam.d/sudo`)
is always reachable. Password auth cannot be blocked by this config.

**How tmux support works:** tmux detaches from the login session's bootstrap port.
`pam_reattach` reattaches the process to the correct port before `pam_tid.so` runs.
That is its entire job. Using `optional` means if reattachment fails, auth continues.

---

## Emergency Revert — LaunchDaemon Watchdog

**The problem with other revert methods:**
- `sudo rm` → requires sudo (broken)
- `osascript` with admin privileges → requires SecurityAgent GUI (can fail headlessly,
  in tmux, or under certain security policies — confirmed gotcha on prior machine)
- Recovery Mode → unacceptable

**Solution:** A root-owned LaunchDaemon pre-staged before any PAM changes are made.
It uses `WatchPaths` to monitor a trigger file and runs as root when the file appears.

**Trigger (zero privileges needed, works anywhere):**
```bash
touch /tmp/.revert-touchid-sudo
```

**What the daemon does when triggered:**
```bash
rm -f /etc/pam.d/sudo_local /tmp/.revert-touchid-sudo
```

**Why this is always reliable:**
- launchd is PID 1 — if launchd is down, the OS is down
- No auth, no GUI, no sudo required to create a file in `/tmp`
- Works headlessly, over SSH, inside tmux, with broken sudo, with broken osascript
- Persists across reboots (daemon lives in `/Library/LaunchDaemons/`)

**Sequence guarantee:** The LaunchDaemon is installed and loaded **before** any
changes to `/etc/pam.d/`. The emergency revert path exists before the risk exists.

---

## Script: `touchid-sudo.sh`

### Modes

```
./touchid-sudo.sh           # install TouchID sudo
./touchid-sudo.sh --revert  # clean uninstall (when sudo is working)
./touchid-sudo.sh --status  # show current state
```

### Install Flow

1. Guard: exit 0 on non-macOS
2. Detect Homebrew prefix (`brew --prefix`) — handles Apple Silicon (`/opt/homebrew`)
   and Intel (`/usr/local`) transparently
3. Install `pam-reattach` via Homebrew if not already installed
4. Resolve `pam_reattach.so` absolute path; **abort if file not found** — nothing is
   changed if the path cannot be verified
5. Install LaunchDaemon watchdog plist to `/Library/LaunchDaemons/`; load it with
   `sudo launchctl bootstrap system <plist>` — this is the **only** sudo call that
   must succeed before PAM is modified
6. Back up any existing `/etc/pam.d/sudo_local` to `~/.dotfiles-backups/sudo_local.bak`
7. Write new content to `/tmp/sudo_local.new`; grep-verify expected lines are present
8. `sudo cp /tmp/sudo_local.new /etc/pam.d/sudo_local` (atomic — no partial writes)
   then `rm /tmp/sudo_local.new`
9. Post-write test: `sudo -k && sudo -v` — forces password re-auth to confirm the
   password path is intact; if this fails → immediately trigger
   `touch /tmp/.revert-touchid-sudo` for auto-revert
10. Print success message and emergency revert instructions (prominently)

### Revert Flow (`--revert`, requires working sudo)

1. `sudo rm -f /etc/pam.d/sudo_local`
2. `sudo launchctl bootout system /Library/LaunchDaemons/com.dotfiles.touchid-sudo-revert.plist`
3. `sudo rm -f /Library/LaunchDaemons/com.dotfiles.touchid-sudo-revert.plist`
4. `sudo -k && sudo -v` to confirm sudo is clean

### Status (`--status`)

- Is `sudo_local` present? Print its content.
- Is `pam_reattach.so` at the expected path?
- Is the LaunchDaemon loaded?
- Run `sudo -v` and report result

### Printed Output After Install

```
TouchID sudo installed.

To test: open a new terminal and run: sudo echo ok
In tmux:  new tmux session and run: sudo echo ok

Emergency revert (NO sudo required — works even with broken sudo):
  touch /tmp/.revert-touchid-sudo

Clean uninstall (when sudo is working):
  ./touchid-sudo.sh --revert
```

---

## Failsafe Layers Summary

| Layer | Protects against |
|---|---|
| `optional` on pam_reattach | Wrong path / module failure → auth continues |
| `sufficient` on pam_tid.so | TouchID failure → falls through to password |
| Pre-flight path check | Abort before writing if pam_reattach.so not found |
| Atomic write via `/tmp` | No partial writes to sudo_local |
| Post-write sudo test | Detect breakage immediately after write |
| LaunchDaemon watchdog | Broken sudo + broken osascript + no GUI |
| `--revert` flag | Clean uninstall when sudo is healthy |
| HANDBOOK.md entry | Emergency instructions always findable |

---

## Files Changed

| File | Change |
|---|---|
| `touchid-sudo.sh` | New script |
| `Brewfile` | Add `pam-reattach` |
| `HANDBOOK.md` | Add TouchID sudo section with emergency revert instructions |
| `/etc/pam.d/sudo_local` | Created at runtime (not in repo) |
| `/Library/LaunchDaemons/com.dotfiles.touchid-sudo-revert.plist` | Created at runtime (not in repo) |

---

## Risks and Mitigations

| Risk | Mitigation |
|---|---|
| pam_reattach path wrong | Pre-flight abort; `optional` flag |
| sudo_local corrupt write | Atomic write via temp file + content verification |
| Post-write sudo broken | Auto-trigger LaunchDaemon revert |
| LaunchDaemon not loaded before PAM change | Step 5 (load daemon) is gated before step 8 (write PAM) |
| macOS update wipes sudo_local | Script is idempotent — re-run to restore |
| pam_reattach Homebrew path changes | Dynamically detected via `brew --prefix` at install time |
