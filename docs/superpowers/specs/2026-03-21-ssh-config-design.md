# SSH Config TUI — Design Spec

**Date:** 2026-03-21
**Status:** Draft

---

## Overview

Upgrade `ssh-config.sh` from a minimal symlink-installer into a full interactive TUI following the `tmux-config.sh` / `dock-config.sh` pattern. The script guides the user through four stages — auth method, connection settings, key generation, write/apply — and produces a fully generated `ssh_config` file.

**Goals:**
- First-class 1Password SSH agent support (with optional file-based fallback)
- Interactive key generation wizard (type, name, comment, passphrase)
- `--status` mode for diagnosing SSH auth state
- `--dry-run` for safe preview
- Consistent TUI pattern with rest of dotfiles

**Non-goals:**
- Multi-host config management (users add host aliases manually as before)
- SSH certificate authority / cert-based auth
- Uploading keys to GitHub/servers

---

## Architecture

### Files

| File | Action | Responsibility |
|---|---|---|
| `ssh-config.sh` | Rewrite | Full TUI — 4 stages, `--status`, `--dry-run` |
| `ssh_config` | Rewrite | Generated output — no longer static |
| `test-ssh-config.sh` | Create | Test suite — macOS-only, output-based |
| `test.sh` | Modify | Add `syntax_check ssh-config.sh` + test section |
| `HANDBOOK.md` | Modify | Update SSH section to cover 1Password + TUI |

### Pattern

Follows `tmux-config.sh` / `dock-config.sh`:
- `set -euo pipefail`
- `run_cmd()` dry-run wrapper — prints `[dry-run] <cmd>` instead of executing shell commands (mkdir, chmod, ln, ssh-keygen). Config content generation uses a string-buffer approach (like `write_local_conf` in `tmux-config.sh`): content is built in a variable and either printed (dry-run) or written to disk.
- `SSH_CONFIG_SOURCE_ONLY=1` source-only guard (macOS only — Linux exits at macOS guard before reaching the guard)
- Color helpers: `info`, `success`, `warn`, `error`, `header`
- `--dry-run` flag: shows generated `ssh_config` content + keygen command, no writes
- `--status` flag: diagnostic mode, no writes

### Arg parsing

```
./ssh-config.sh                  # interactive TUI
./ssh-config.sh --status         # show current SSH state
./ssh-config.sh --dry-run        # show what would be written
```

Unknown flags exit non-zero with usage message.

---

## TUI Stages

### Stage 1 — Auth method (`select` menu)

Three options:
1. **1Password agent only** — `IdentityAgent "~/.1password/agent.sock"`, no `IdentityFile`
2. **File-based keys only** — `IdentityFile ~/.ssh/<name>`, no `IdentityAgent`
3. **1Password with file-based fallback** *(recommended, default)* — both set; agent tried first

Sets `AUTH_METHOD` ∈ {`1password`, `file`, `fallback`}.

### Stage 2 — Connection settings

**fzf toggle checklist** (falls back to `select` preset if fzf absent):

| Toggle | Key | Default |
|---|---|---|
| Connection multiplexing | `multiplexing` | on |
| Hash known hosts | `hash_known_hosts` | on |

**Variant menus** (`select`, shown after toggles):

- **Keepalive interval** (always shown): 60s (default) / 30s / disabled
- **ControlPersist duration** (only if multiplexing on): 600s (default) / 60s / indefinite

Sets `ENABLED[]`, `DISABLED[]`, `VARIANTS[keepalive]`, `VARIANTS[control_persist]`.

### Stage 3 — Key generation wizard

**Skipped entirely** if:
- `AUTH_METHOD = 1password` (no key files needed), OR
- Key already exists at the chosen path (reports existing key, moves on), OR
- Running non-interactively (no TTY) — the `[ -t 0 ]` guard in the main dispatch fires before Stage 1, so Stage 3 is never reached in non-interactive mode

**Wizard prompts** (`select` + `read`):
1. Key name — default `id_ed25519`; `read -r -p` prompt, empty = use default
2. Key type — `select`: `ed25519` (default) / `rsa` / `ecdsa`
3. Comment — `read -r -p` prompt for email/label; empty = no comment
4. Passphrase — `select`: "Set a passphrase (prompted)" / "No passphrase (empty)"

If key already exists at `~/.ssh/<name>`: print fingerprint, skip generation.

Sets `KEYGEN_PATH`, `KEYGEN_TYPE`, `KEYGEN_COMMENT`, `KEYGEN_PASSPHRASE` ∈ {`yes`, `no`}.

### Stage 4 — Write + apply

A `generate_ssh_config` function builds the full config content as a string from `AUTH_METHOD`, `ENABLED[]`, `DISABLED[]`, `VARIANTS[]`, and `KEYGEN_PATH` (if set). This function is the testable unit: tests source the script with `SSH_CONFIG_SOURCE_ONLY=1`, set these variables directly, call `generate_ssh_config`, and assert on its output — no interactive TUI required.

Steps:
1. Call `generate_ssh_config` → store in `SSH_CONF_OUT` variable
2. In dry-run: print content between separator lines; print keygen command if applicable; return
3. Ensure `~/.ssh/` exists with `700` permissions (`run_cmd mkdir -p` + `run_cmd chmod`)
4. Ensure `~/.ssh/sockets/` exists (`run_cmd mkdir -p`)
5. Back up existing `~/.ssh/config` if it is a regular file (not symlink)
6. Write `SSH_CONF_OUT` to `ssh_config` in repo via `printf '%s\n' "$SSH_CONF_OUT" > "$SSH_CONFIG_FILE"`
7. Symlink `~/.ssh/config` → `ssh_config` (`run_cmd ln -sf`)
8. `chmod 600` on the repo file (not the symlink): `chmod 600 "$SCRIPT_DIR/ssh_config"`
9. If key generation requested and `DRY_RUN=false`: run `ssh-keygen` with chosen options
10. Print `--status`-style summary

---

## Generated Config Format

```
# ~/.ssh/config — generated by ssh-config.sh
# Generated: YYYY-MM-DD HH:MM:SS
# Auth method: <1password|file|fallback>
# Re-run ./ssh-config.sh to regenerate.

Host *
    # ── Auth ──────────────────────────────────────────────────────────────────
    AddKeysToAgent yes
    UseKeychain yes                              # macOS only
    IdentityAgent "~/.1password/agent.sock"      # if 1password or fallback
    IdentityFile ~/.ssh/<name>                   # if file or fallback

    # ── Keepalive ─────────────────────────────────────────────────────────────
    ServerAliveInterval 60                       # omitted if disabled
    ServerAliveCountMax 3                        # omitted if disabled

    # ── Multiplexing ──────────────────────────────────────────────────────────
    ControlMaster auto                           # omitted if disabled
    ControlPath ~/.ssh/sockets/%r@%h-%p          # omitted if disabled
    ControlPersist 600                           # omitted if disabled

    # ── Security ──────────────────────────────────────────────────────────────
    HashKnownHosts yes                           # omitted if disabled
```

`UseKeychain yes` is macOS-only — omitted on Linux (detected via `DOTFILES_OS` from `platform.sh`).

---

## `--status` Mode

Reports the following, using `success` / `warn` helpers:

1. **Symlink** — `~/.ssh/config` symlinked to repo's `ssh_config`?
2. **Permissions** — `~/.ssh` is `700`?
3. **Sockets dir** — `~/.ssh/sockets/` exists?
4. **1Password agent** — socket present at `~/.1password/agent.sock`?
5. **Key files** — lists any `~/.ssh/id_*` found; for each: shows type + fingerprint via `ssh-keygen -l -f`
6. **Auth method** — parsed from `# Auth method:` comment in generated config (or "unknown" if manually edited / missing)

Exits 0 regardless of state (diagnostic only).

---

## `--dry-run` Mode

Prints the full `ssh_config` content that would be written (bounded by separator lines), followed by the `ssh-keygen` command that would be run (if applicable).

Example output:
```
  (dry-run mode — no files will be written)

  Would write to: /path/to/dotfiles/ssh_config
  ────────────────────────────────────────────
  # ~/.ssh/config — generated by ssh-config.sh
  ...
  ────────────────────────────────────────────

  Would run: ssh-keygen -t ed25519 -C "user@example.com" -f ~/.ssh/id_ed25519
```

---

## Testing (`test-ssh-config.sh`)

macOS-only (same guard pattern as `test-touchid-sudo.sh`, `test-dock-config.sh`).

### Syntax check
- `bash -n ssh-config.sh`

### dry-run output checks

Tests source the script with `SSH_CONFIG_SOURCE_ONLY=1`, set `AUTH_METHOD`, `ENABLED[]`, `DISABLED[]`, and `VARIANTS[]` directly, then call `generate_ssh_config` and assert on its output. No interactive TUI is invoked. Example:

```bash
SSH_CONFIG_SOURCE_ONLY=1 . "$SCRIPT_DIR/ssh-config.sh"
AUTH_METHOD="1password"
ENABLED=(multiplexing hash_known_hosts)
DISABLED=()
VARIANTS=([keepalive]="60" [control_persist]="600")
out="$(generate_ssh_config)"
```

For each auth method, assert output contains expected strings:

| Check | Expected substring |
|---|---|
| 1Password mode | `IdentityAgent "~/.1password/agent.sock"` |
| 1Password mode | no `IdentityFile` line |
| File-based mode | `IdentityFile` |
| File-based mode | no `IdentityAgent` line |
| Fallback mode | `IdentityAgent` AND `IdentityFile` both present |
| Multiplexing on | `ControlMaster auto` |
| Multiplexing off | no `ControlMaster` |
| HashKnownHosts on | `HashKnownHosts yes` |

### Arg parsing checks
- `--status` exits 0
- `--dry-run` exits 0 (non-interactive stdin)
- Invalid flag exits non-zero

### Wire into `test.sh`
- `syntax_check ssh-config.sh` added to syntax block
- macOS-guarded `test-ssh-config.sh` section added (mirrors dock-config pattern)

---

## HANDBOOK.md Updates

Replace the existing minimal SSH section with:
- Overview: 1Password agent + file-based fallback explained
- Setup: `./ssh-config.sh` — describe the 4 stages
- Status: `./ssh-config.sh --status`
- Key generation: covered by wizard, document the key types
- 1Password setup prerequisite: link to 1Password SSH agent docs (mention the `~/.1password/agent.sock` path)
- Host aliases: keep existing example
- Connection multiplexing: keep existing example

---

## macOS Guard

`ssh-config.sh` is macOS-only (1Password agent, `UseKeychain`). On Linux it prints a skip message and exits 0. All test files and `test.sh` section are guarded with `[ "$(uname -s)" != "Darwin" ]`.

---

## Edge Cases

| Scenario | Behaviour |
|---|---|
| `ssh-keygen` fails | `error` message, exit 1 |
| Key exists at chosen path | Skip generation, print fingerprint |
| 1Password socket missing at `--status` | `warn` (not error — app might just be closed) |
| `~/.ssh/config` is regular file | Backed up before symlink |
| Running non-interactively (no TTY) | Skip TUI, print skip message, exit 0 |
| `--dry-run` in non-interactive | Show dry-run output, exit 0 — `--dry-run` check fires before the TTY guard, so non-interactive dry-run always produces output (same pattern as `tmux-config.sh`) |
