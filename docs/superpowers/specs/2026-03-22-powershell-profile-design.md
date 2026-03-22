# PowerShell 7 Profile — Design Spec

**Date:** 2026-03-22
**Status:** Draft

---

## Overview

Add a PowerShell 7 profile (`profile.ps1`) for the velvet dotfiles profile and a `powershell-config.sh` installer script that deploys it and ensures the VS Code terminal font is configured.

**Problem:** Users running PowerShell 7 on macOS or Linux have no dotfiles integration — no oh-my-posh prompt, no velvet theme, no font config.

**Goals:**
- Add `profiles/velvet/profile.ps1` with oh-my-posh velvet theme init
- New `powershell-config.sh` — copies profile to the correct path, detects and fixes VS Code terminal font
- macOS and Linux supported; no Windows

**Non-goals:**
- PowerShell support for profiles other than velvet
- Configuring VS Code to use pwsh as default terminal shell
- Installing pwsh or oh-my-posh (already in Brewfile / handled by install flow)
- Windows support
- Wiring into `choose-profile.sh` (opt-in via separate script)

---

## Architecture

### Files

| File | Action | Responsibility |
|---|---|---|
| `profiles/velvet/profile.ps1` | Create | PS7 profile — oh-my-posh velvet theme init (new file type in velvet profile dir; not deployed by `choose-profile.sh`, which is intentionally left unmodified) |
| `powershell-config.sh` | Create | Installer — copy profile + detect/fix VS Code font |
| `test-powershell-config.sh` | Create | Test suite — syntax, install logic, VS Code font, arg parsing |
| `test.sh` | Modify | Add `syntax_check powershell-config.sh` + PowerShell Config test section (no macOS guard) |
| `HANDBOOK.md` | Modify | Add PS7 section: what it does, prerequisites (pwsh + velvet profile installed), usage (`./powershell-config.sh`, `--status`, `--dry-run`), note that `choose-profile.sh` must be run first for the omp theme, VS Code font note |

No new Homebrew dependencies. `oh-my-posh` and `pwsh` are already in Brewfile.

### Profile Path

```
~/.config/powershell/Microsoft.PowerShell_profile.ps1
```

Same path on macOS and Linux (`$PROFILE` in pwsh resolves to this).

### oh-my-posh Theme Path

`choose-profile.sh` installs `profiles/velvet/velvet.omp.json` to `~/oh-my-posh/velvet.omp.json`. `profile.ps1` references this installed path.

---

## `profiles/velvet/profile.ps1`

```powershell
# ~/.config/powershell/Microsoft.PowerShell_profile.ps1
# Managed by dotfiles — reinstall with ./powershell-config.sh

if (Get-Command oh-my-posh -ErrorAction SilentlyContinue) {
    oh-my-posh init pwsh --config "$HOME/oh-my-posh/velvet.omp.json" | Invoke-Expression
}
```

Silently skips oh-my-posh init if the binary is absent (graceful on a fresh machine before `brew bundle`). References `~/oh-my-posh/velvet.omp.json` — the path `choose-profile.sh` installs the theme to.

---

## `powershell-config.sh`

### Pattern

Follows `font-config.sh` / `ssh-config.sh`:
- `set -euo pipefail`
- `SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"` — used to locate `platform.sh` and `profiles/velvet/profile.ps1`
- `DRY_RUN=false` initialized at the top (required before any `$DRY_RUN` reference due to `nounset`)
- `run_cmd()` dry-run wrapper
- `POWERSHELL_CONFIG_SOURCE_ONLY=1` source guard placed **after all function definitions**
- Color helpers: `info`, `success`, `warn`, `error`, `header`
- `platform.sh` sourced for `DOTFILES_OS` detection
- Cross-platform: macOS + Linux; no top-level OS guard
- **No non-interactive guard** — there is no interactive prompt (no fzf, no TTY input), so the script runs identically in interactive and non-interactive contexts

### Arg Parsing

```
./powershell-config.sh            # install profile + fix VS Code font
./powershell-config.sh --status   # report state, no changes
./powershell-config.sh --dry-run  # preview fixes, no writes
```

Unknown flags exit non-zero with usage message. Combining multiple flags (e.g., `--status --dry-run`) is an error — exit non-zero with usage message.

### Main Flow

**Step 1 — Check pwsh**

`command -v pwsh >/dev/null 2>&1`. If missing: warn and exit 1 — nothing to install to. This applies in both install and `--dry-run` mode; only `--status` skips this guard (it reports "not found" and exits 0).

**Step 2 — Install profile**

Copy `profiles/velvet/profile.ps1` → `~/.config/powershell/Microsoft.PowerShell_profile.ps1`.

- Creates `~/.config/powershell/` if absent
- Backs up existing file with an inline `backup_if_exists` function defined in `powershell-config.sh` itself (same `.backup.YYYYMMDD_HHMMSS` rename convention as `choose-profile.sh`; the function is not in any shared library so must be defined locally)
- Copy goes through `run_cmd` so `--dry-run` prints the action without executing

**Step 3 — VS Code font**

Set `VSCODE_SETTINGS_PATH` based on `$DOTFILES_OS`:
- macOS: `$HOME/Library/Application Support/Code/User/settings.json`
- Linux: `$HOME/.config/Code/User/settings.json`

If `command -v code >/dev/null 2>&1` fails: silently skip VS Code font step.

Check for existing font config with a shell-level grep before invoking python3:

```bash
grep -q '"terminal.integrated.fontFamily".*FiraCode' "$VSCODE_SETTINGS_PATH" 2>/dev/null
```

The pattern matches any FiraCode variant (FiraCode Nerd Font, FiraCode Nerd Font Mono, etc.) — any is acceptable for glyph rendering. Consistent with `font-config.sh`.

If the grep succeeds: print success and skip (font already configured).

If the file is absent or the key is not set: run inline `python3` JSON merge (same JSONC-safe strategy as `font-config.sh`):

```bash
python3 -c "
import json, sys
path = sys.argv[1]
try:
    with open(path) as f:
        data = json.load(f)
except FileNotFoundError:
    data = {}
except json.JSONDecodeError:
    print('JSONC_OR_INVALID')
    sys.exit(0)
data['terminal.integrated.fontFamily'] = 'FiraCode Nerd Font'
with open(path, 'w') as f:
    json.dump(data, f, indent=4)
print('OK')
" "$VSCODE_SETTINGS_PATH"
```

On `JSONC_OR_INVALID`: warn and print the exact line to add manually. No file is modified.
On `OK`: print success.

**`--dry-run` handling for VS Code:** `run_cmd` cannot wrap an inline python3 heredoc. Instead, guard with an explicit `if [ "$DRY_RUN" = "true" ]` check before invoking python3 — print what would be written and return early. This is the same pattern `font-config.sh` uses for its VS Code fix.

### `--status` Mode

Reports (no writes, always exits 0 regardless of state):
- pwsh installed / not found (reported, does not exit 1 in status mode)
- Profile path exists / missing
- VS Code font configured / not configured / VS Code not installed

### `--dry-run` Mode

Runs the full flow but writes nothing. When run non-interactively (no TTY), previews all actions that would be taken.

---

## VS Code `settings.json` Handling

VS Code settings files are officially JSON but may contain `//` comments or trailing commas (JSONC). Python's `json` module rejects these.

**Strategy:**
1. If file absent: run `mkdir -p "$(dirname "$VSCODE_SETTINGS_PATH")"` in the shell before invoking python3 (VS Code being in PATH does not guarantee the `User/` directory exists on a fresh install)
2. Attempt to parse with `python3 json.load()`
3. If parsing fails: `warn` and skip — print the exact line the user should add manually. No data is modified.
4. If file absent: python3 catches `FileNotFoundError` and creates a minimal file with just the font key
5. If file present and valid JSON: merge the font key, preserve all other keys

---

## Testing (`test-powershell-config.sh`)

`test-powershell-config.sh` has **no top-level OS guard** — all tests use mock paths and are platform-independent.

`test.sh` includes `test-powershell-config.sh` without a macOS guard.

### Tests

**Syntax check**
- `bash -n powershell-config.sh`

**Profile install** (source `POWERSHELL_CONFIG_SOURCE_ONLY=1`):
- Install to temp path → assert file exists and contents match source
- Install when target already exists → assert backup created, new file installed

**VS Code font detection and fix:**
- Mock `settings.json` without font key → assert python3 merge writes `terminal.integrated.fontFamily = FiraCode Nerd Font`
- Mock `settings.json` with font key already set → assert script prints success and file unchanged
- Mock `settings.json` with JSONC (`//` comment) → assert script warns and skips, file unchanged
- Mock absent `settings.json` in a temp directory → assert script creates parent directory and file with font key

**Arg parsing:**
- `--status` exits 0
- `--dry-run` exits 0
- `--badflag` exits non-zero

### Wire into `test.sh`

- `syntax_check powershell-config.sh` added after `syntax_check font-config.sh`
- PowerShell Config section added after Font Config section — **no macOS guard** on the section

---

## Edge Cases

| Scenario | Behaviour |
|---|---|
| `pwsh` not installed | Warn and exit 1 — nothing to configure |
| `oh-my-posh` not installed | Profile installs fine; init line silently skipped at runtime |
| `~/oh-my-posh/velvet.omp.json` absent | Profile installs fine; oh-my-posh warns at runtime — user should run `choose-profile.sh` first |
| Profile already installed | Backs up existing, installs fresh copy |
| VS Code not installed (`code` not in PATH) | Skip VS Code font step silently |
| VS Code `settings.json` has JSONC | Warn and skip; print line to add manually |
| VS Code `settings.json` absent | Create minimal file with font key |
| Font already configured | Print success, skip write |
| `--dry-run` non-interactive | Print all actions that would be taken |
