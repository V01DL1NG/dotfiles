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

Apple ships `/etc/pam.d/sudo_local.template` as the reference for this file.
Our config prepends `pam_reattach.so` to that template's structure.

The PAM config written to `sudo_local` (path shown is illustrative — the actual
path is resolved dynamically via `brew --prefix` at install time):

```
# sudo_local — managed by touchid-sudo.sh
# Emergency revert (no sudo needed): touch /tmp/.revert-touchid-sudo
auth       optional       <brew_prefix>/lib/pam/pam_reattach.so
auth       sufficient     pam_tid.so
```

On Apple Silicon the resolved path is `/opt/homebrew/lib/pam/pam_reattach.so`.
On Intel it is `/usr/local/lib/pam/pam_reattach.so`.
The script always uses `$(brew --prefix)` — never a hardcoded path.

**Control flags — why:**

| Module | Flag | Behaviour on failure |
|---|---|---|
| `pam_reattach.so` | `optional` | Module fails / path wrong → ignored, auth continues |
| `pam_tid.so` | `sufficient` | TouchID fails → falls through to password |

This guarantees `pam_opendirectory.so` (the password line in `/etc/pam.d/sudo`)
is always reachable. Password auth cannot be blocked by this config.

Note: `sudo_local` does not need to repeat `pam_opendirectory.so` — macOS PAM
prepends the `sudo_local` lines to the `sudo` lines at evaluation time (via the
`include` directive). The full runtime stack is: pam_reattach → pam_tid → smartcard
→ pam_opendirectory (password). The last line is never removed.

**How tmux support works:** tmux detaches from the login session's bootstrap port.
`pam_reattach` reattaches the process to the correct port before `pam_tid.so` runs.
That is its entire job. Using `optional` means if reattachment fails, auth continues.

---

## Emergency Revert — LaunchDaemon Watchdog

**The problem with other revert methods:**
- `sudo rm` → requires sudo (broken)
- `osascript` with admin privileges → requires SecurityAgent GUI (fails headlessly,
  in tmux, or under certain security policies — confirmed broken on prior machine)
- Recovery Mode → unacceptable

**Solution:** A root-owned LaunchDaemon pre-staged before any PAM changes are made.
It uses `WatchPaths` to monitor a trigger file and runs as root when the file appears.

**Trigger (zero privileges needed, works anywhere):**
```bash
touch /tmp/.revert-touchid-sudo
```

**What the daemon does when triggered:**
```bash
rm -f /etc/pam.d/sudo_local /private/tmp/.revert-touchid-sudo
```

**Why this is reliable in practice:**
- launchd is PID 1 — if launchd is down, the OS is down
- No auth, no GUI, no sudo required to create a file in `/tmp`
- Works headlessly, over SSH, inside tmux, with broken sudo, with broken osascript
- Persists across reboots (daemon lives in `/Library/LaunchDaemons/`)

**WatchPaths caveat:** `launchd.plist(5)` documents that `WatchPaths` is
"race-prone" and modifications can theoretically be missed. In practice, for a
manually-triggered single-file creation at low frequency this is reliable. If the
trigger fires but nothing happens within 30 seconds, verify with:
```bash
launchctl list com.dotfiles.touchid-sudo-revert
```
If the daemon is listed but did not fire, manually kickstart it:
```bash
launchctl kickstart system/com.dotfiles.touchid-sudo-revert
```
Note: `launchctl kickstart` targeting a system-domain service requires admin group
membership and may prompt for a password via GUI in an interactive session. In a
headless/SSH context it may fail with `Operation not permitted` if no auth agent
is available. If kickstart is unavailable, reboot — the daemon reloads from
`/Library/LaunchDaemons/` and a fresh `touch /tmp/.revert-touchid-sudo` will
trigger it.

**Sequence guarantee:** The LaunchDaemon is installed and loaded **before** any
changes to `/etc/pam.d/`. The emergency revert path exists before the risk exists.

---

## LaunchDaemon Plist

Full plist written to `/Library/LaunchDaemons/com.dotfiles.touchid-sudo-revert.plist`.
File must be owned `root:wheel` with permissions `644` — launchd rejects world-writable
or non-root-owned plists.

```xml
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN"
  "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>Label</key>
    <string>com.dotfiles.touchid-sudo-revert</string>
    <key>WatchPaths</key>
    <array>
        <string>/private/tmp/.revert-touchid-sudo</string>
    </array>
    <key>ProgramArguments</key>
    <array>
        <string>/bin/sh</string>
        <string>-c</string>
        <string>rm -f /etc/pam.d/sudo_local /private/tmp/.revert-touchid-sudo</string>
    </array>
    <key>RunAtLoad</key>
    <false/>
</dict>
</plist>
```

Note: `WatchPaths` uses `/private/tmp/` (the resolved path) rather than the `/tmp`
symlink, ensuring launchd registers the FSEvents watch against the actual inode.
The user-facing `touch /tmp/.revert-touchid-sudo` command is fine — the shell
resolves the symlink transparently.

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
2. Detect Homebrew prefix (`brew --prefix`) — handles Apple Silicon and Intel
3. Install `pam-reattach` via Homebrew if not already installed
4. Resolve `pam_reattach.so` absolute path; **abort if file not found** — nothing is
   changed if the path cannot be verified
5. Write plist to a temp file, verify it is well-formed, then `sudo cp` to
   `/Library/LaunchDaemons/com.dotfiles.touchid-sudo-revert.plist` with `root:wheel 644`
   permissions (atomic — no partial plist in `/Library/LaunchDaemons/`).
   If the daemon label is already registered (`launchctl list
   com.dotfiles.touchid-sudo-revert` exits 0), skip the bootstrap step (idempotent).
   Otherwise: `sudo launchctl bootstrap system <plist>`. This sudo call must succeed
   before PAM is modified.
6. Back up any existing `/etc/pam.d/sudo_local` to `~/.dotfiles-backups/sudo_local.bak`
7. Write new `sudo_local` content to a temp file created with `mktemp` (mode `600`
   — content is not sensitive but limits unnecessary readability); grep-verify that
   both the `pam_reattach.so` line and the `pam_tid.so` line are present with correct
   control flags. Abort if verification fails.
8. `sudo cp /tmp/sudo_local.new /etc/pam.d/sudo_local && rm /tmp/sudo_local.new`
   (atomic — no partial writes to `/etc/pam.d/`)
9. Verify `/etc/pam.d/sudo_local` content post-copy (grep check — not a live sudo
   call; see note below)
10. Print success message with test instructions and emergency revert info

**Why no live `sudo -v` in the install flow:** `sudo -v` after `sudo -k` hangs
indefinitely in non-interactive / no-TTY contexts waiting for auth input. The
automated post-write check is the content grep in steps 7 and 9. The live test
is left to the user (step 10 instructions) so it runs in an interactive terminal
with a proper TTY and auth prompt.

### Revert Flow (`--revert`, requires working sudo)

1. `sudo rm -f /etc/pam.d/sudo_local`
2. `sudo launchctl bootout system /Library/LaunchDaemons/com.dotfiles.touchid-sudo-revert.plist`
   (skip if daemon not loaded)
3. `sudo rm -f /Library/LaunchDaemons/com.dotfiles.touchid-sudo-revert.plist`
4. Print: `"Run: sudo echo ok  — to confirm sudo is clean"`
   (not executed in-script — avoids hang risk in non-interactive contexts)

### Status (`--status`)

- Is `sudo_local` present? Print its content.
- Is `pam_reattach.so` at the expected path?
- Is the LaunchDaemon loaded? (`launchctl list com.dotfiles.touchid-sudo-revert`)
- Print: `"Run: sudo echo ok  — to test"`

### Printed Output After Install

```
TouchID sudo installed.

To test:
  Native terminal: sudo echo ok
  tmux session:    open a new tmux window, then: sudo echo ok

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
EMERGENCY REVERT — no sudo, no osascript, no GUI needed:
  touch /tmp/.revert-touchid-sudo

Works even with completely broken sudo.
If nothing happens in 30s: launchctl kickstart system/com.dotfiles.touchid-sudo-revert

Clean uninstall (when sudo is working):
  ./touchid-sudo.sh --revert
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
```

---

## Failsafe Layers Summary

| Layer | Protects against |
|---|---|
| `optional` on pam_reattach | Wrong path / module failure → auth continues |
| `sufficient` on pam_tid.so | TouchID failure → falls through to password |
| Pre-flight path check | Abort before writing if pam_reattach.so not found |
| Daemon loaded before PAM written | Emergency revert exists before risk exists |
| Atomic write via `/tmp` | No partial writes to sudo_local |
| Post-write content grep | Detect wrong content immediately after write |
| LaunchDaemon watchdog | Broken sudo + broken osascript + no GUI |
| `launchctl kickstart` fallback | WatchPaths race condition miss |
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
| LaunchDaemon not loaded before PAM change | Step 5 (load daemon) gated before step 8 (write PAM) |
| launchctl bootstrap fails on re-run | Skip if label already registered (idempotent) |
| WatchPaths misses trigger | `launchctl kickstart` fallback documented |
| macOS update wipes sudo_local | Script is idempotent — re-run to restore |
| pam_reattach Homebrew path changes | Dynamically detected via `brew --prefix` at install time |
