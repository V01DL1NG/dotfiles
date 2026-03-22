# PowerShell 7 Profile Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add a PowerShell 7 profile (`profile.ps1`) for the velvet dotfiles theme and a `powershell-config.sh` installer that deploys it and configures the VS Code terminal font.

**Architecture:** `profiles/velvet/profile.ps1` contains the PS7 oh-my-posh init. `powershell-config.sh` copies it to `~/.config/powershell/Microsoft.PowerShell_profile.ps1`, detects and sets the VS Code terminal font via inline python3 JSON merge, and exposes `--status` and `--dry-run` modes. Tests in `test-powershell-config.sh` use mock paths to run platform-independently.

**Tech Stack:** bash, PowerShell 7 (`pwsh`), oh-my-posh, python3 (stdlib only)

---

## File Map

| File | Change |
|---|---|
| `profiles/velvet/profile.ps1` | Create |
| `powershell-config.sh` | Create |
| `test-powershell-config.sh` | Create |
| `test.sh` | Modify — add syntax check + test section |
| `HANDBOOK.md` | Modify — add PowerShell 7 section |

---

## Task 1: `profiles/velvet/profile.ps1`

**Files:**
- Create: `profiles/velvet/profile.ps1`

- [ ] **Step 1: Create `profiles/velvet/profile.ps1`**

```powershell
# ~/.config/powershell/Microsoft.PowerShell_profile.ps1
# Managed by dotfiles — reinstall with ./powershell-config.sh

if (Get-Command oh-my-posh -ErrorAction SilentlyContinue) {
    oh-my-posh init pwsh --config "$HOME/oh-my-posh/velvet.omp.json" | Invoke-Expression
}
```

- [ ] **Step 2: Verify the file is correct**

```bash
cat profiles/velvet/profile.ps1
```

Expected: the four lines above, no extra content.

- [ ] **Step 3: Commit**

```bash
git add profiles/velvet/profile.ps1
git commit -m "feat: add PS7 oh-my-posh profile for velvet theme"
```

---

## Task 2: `test-powershell-config.sh` — write all tests (red phase)

Write the full test file before implementing the script. Every test in the profile install, VS Code font, and arg parsing sections will fail until Task 3 implements `powershell-config.sh`.

**Files:**
- Create: `test-powershell-config.sh`

- [ ] **Step 1: Create `test-powershell-config.sh`**

```bash
#!/usr/bin/env bash
# test-powershell-config.sh — test suite for powershell-config.sh

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PASS=0; FAIL=0

pass() { echo "  ✓ $1"; PASS=$((PASS + 1)); }
fail() { echo "  ✗ $1"; FAIL=$((FAIL + 1)); }
section() { echo ""; echo "── $1"; }

# ── Syntax ────────────────────────────────────────────────────────────────────
section "Syntax"

if bash -n "$SCRIPT_DIR/powershell-config.sh" 2>/dev/null; then
  pass "bash -n powershell-config.sh"
else
  fail "bash -n powershell-config.sh — syntax error"
fi

# ── Profile install ───────────────────────────────────────────────────────────
section "Profile install"

POWERSHELL_CONFIG_SOURCE_ONLY=1 . "$SCRIPT_DIR/powershell-config.sh"

TMPDIR_TEST="$(mktemp -d)"
trap 'rm -rf "$TMPDIR_TEST"' EXIT

# Fresh install → file exists and contents match source
dst="$TMPDIR_TEST/fresh/Microsoft.PowerShell_profile.ps1"
install_profile "$dst"
if [ -f "$dst" ]; then
  if diff -q "$SCRIPT_DIR/profiles/velvet/profile.ps1" "$dst" >/dev/null 2>&1; then
    pass "profile install: file created and matches source"
  else
    fail "profile install: file contents differ from source"
  fi
else
  fail "profile install: file not created at $dst"
fi

# Install when target already exists → backup created, new file installed
dst2="$TMPDIR_TEST/backup/Microsoft.PowerShell_profile.ps1"
mkdir -p "$(dirname "$dst2")"
echo "old content" > "$dst2"
install_profile "$dst2"
backup_count=$(ls "$TMPDIR_TEST/backup/"*.backup.* 2>/dev/null | wc -l | tr -d ' ')
if [ "$backup_count" -ge 1 ]; then
  pass "profile install: backup created when target exists"
else
  fail "profile install: no backup created when target exists"
fi
if diff -q "$SCRIPT_DIR/profiles/velvet/profile.ps1" "$dst2" >/dev/null 2>&1; then
  pass "profile install: new file installed after backup"
else
  fail "profile install: new file does not match source after backup"
fi

# ── VS Code font ──────────────────────────────────────────────────────────────
section "VS Code font"

# settings.json without font key → fontFamily written
settings_no_font="$TMPDIR_TEST/vscode_no_font/settings.json"
mkdir -p "$(dirname "$settings_no_font")"
printf '{\n    "editor.fontSize": 14\n}\n' > "$settings_no_font"
fix_vscode_font "$settings_no_font"
if grep -q '"terminal.integrated.fontFamily".*FiraCode' "$settings_no_font" 2>/dev/null; then
  pass "vscode font: fontFamily written when key absent"
else
  fail "vscode font: fontFamily not written — expected FiraCode key"
fi

# settings.json with font key already set → file unchanged
settings_already="$TMPDIR_TEST/vscode_already/settings.json"
mkdir -p "$(dirname "$settings_already")"
printf '{\n    "terminal.integrated.fontFamily": "FiraCode Nerd Font"\n}\n' > "$settings_already"
content_before="$(cat "$settings_already")"
fix_vscode_font "$settings_already"
content_after="$(cat "$settings_already")"
if [ "$content_before" = "$content_after" ]; then
  pass "vscode font: file unchanged when fontFamily already set"
else
  fail "vscode font: file was modified when fontFamily already set"
fi

# settings.json with JSONC comment → file unchanged, warn printed
settings_jsonc="$TMPDIR_TEST/vscode_jsonc/settings.json"
mkdir -p "$(dirname "$settings_jsonc")"
printf '// VS Code settings\n{\n    "editor.fontSize": 14\n}\n' > "$settings_jsonc"
content_before="$(cat "$settings_jsonc")"
output="$(fix_vscode_font "$settings_jsonc" 2>&1)"
content_after="$(cat "$settings_jsonc")"
if [ "$content_before" = "$content_after" ]; then
  pass "vscode font (JSONC): file unchanged"
else
  fail "vscode font (JSONC): file was modified — expected no change"
fi
if echo "$output" | grep -qi "comment\|invalid\|manually"; then
  pass "vscode font (JSONC): warns user to add manually"
else
  fail "vscode font (JSONC): no warning printed"
fi

# absent settings.json in nested temp dir → parent dirs created, file with font key
settings_absent="$TMPDIR_TEST/vscode_absent/Code/User/settings.json"
fix_vscode_font "$settings_absent"
if [ -d "$(dirname "$settings_absent")" ]; then
  pass "vscode font (absent): parent directory created"
else
  fail "vscode font (absent): parent directory not created"
fi
if grep -q '"terminal.integrated.fontFamily".*FiraCode' "$settings_absent" 2>/dev/null; then
  pass "vscode font (absent): settings.json created with font key"
else
  fail "vscode font (absent): settings.json not created or missing font key"
fi

# ── Arg parsing ───────────────────────────────────────────────────────────────
section "Arg parsing"

# --status always exits 0
bash "$SCRIPT_DIR/powershell-config.sh" --status </dev/null >/dev/null 2>&1 \
  && pass "--status exits 0" \
  || fail "--status exits non-zero"

# --dry-run: exits 0 when pwsh available; exits 1 when not (both are correct)
if command -v pwsh >/dev/null 2>&1; then
  bash "$SCRIPT_DIR/powershell-config.sh" --dry-run </dev/null >/dev/null 2>&1 \
    && pass "--dry-run exits 0 (pwsh available)" \
    || fail "--dry-run exits non-zero (pwsh available)"
else
  dry_exit=0
  bash "$SCRIPT_DIR/powershell-config.sh" --dry-run </dev/null >/dev/null 2>&1 || dry_exit=$?
  [ "$dry_exit" -eq 1 ] \
    && pass "--dry-run exits 1 (pwsh not installed, expected)" \
    || fail "--dry-run exited $dry_exit (expected 1 when pwsh not installed)"
fi

# --badflag exits non-zero
bash "$SCRIPT_DIR/powershell-config.sh" --badflag </dev/null >/dev/null 2>&1 \
  && fail "--badflag should exit non-zero" \
  || pass "--badflag exits non-zero"

# ── Summary ───────────────────────────────────────────────────────────────────
echo ""
echo "────────────────────────────────"
printf "  passed: %d  failed: %d\n" "$PASS" "$FAIL"
echo "────────────────────────────────"
[ "$FAIL" -eq 0 ]
```

- [ ] **Step 2: Run the tests — confirm they fail**

```bash
bash test-powershell-config.sh
```

Expected: FAIL on every test (script doesn't exist yet). The only failure to watch for: if `bash -n` reports a "file not found" error rather than a syntax failure, that's fine — it still fails.

- [ ] **Step 3: Commit the test file**

```bash
git add test-powershell-config.sh
git commit -m "test: add test-powershell-config.sh (red phase)"
```

---

## Task 3: `powershell-config.sh` — implement to make all tests pass

**Files:**
- Create: `powershell-config.sh`

- [ ] **Step 1: Create `powershell-config.sh`**

```bash
#!/usr/bin/env bash
# powershell-config.sh — PowerShell 7 profile installer
#
# Usage:
#   ./powershell-config.sh            # install profile + configure VS Code font
#   ./powershell-config.sh --status   # report state, no changes
#   ./powershell-config.sh --dry-run  # preview actions, no writes
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DRY_RUN=false

# shellcheck source=platform.sh
source "$SCRIPT_DIR/platform.sh"

# ── Colors ────────────────────────────────────────────────────────────────────
BOLD='\033[1m'
PURPLE='\033[38;2;105;48;122m'
LAVENDER='\033[38;2;239;220;249m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
RED='\033[0;31m'
RESET='\033[0m'

info()    { echo -e "  ${LAVENDER}${1}${RESET}"; }
success() { echo -e "  ${GREEN}✓${RESET}  ${1}"; }
warn()    { echo -e "  ${YELLOW}!${RESET}  ${1}"; }
error()   { echo -e "  ${RED}✗${RESET}  ${1}" >&2; }
header()  { echo -e "\n${BOLD}${PURPLE}${1}${RESET}"; }

# ── run_cmd ───────────────────────────────────────────────────────────────────
run_cmd() {
  if [ "$DRY_RUN" = "true" ]; then
    echo "  [dry-run] $*"
  else
    "$@"
  fi
}

# ── backup_if_exists ──────────────────────────────────────────────────────────
TIMESTAMP="$(date +%Y%m%d_%H%M%S)"

backup_if_exists() {
  local target="$1"
  if [ -e "$target" ] || [ -L "$target" ]; then
    local backup="${target}.backup.${TIMESTAMP}"
    mv "$target" "$backup"
    warn "backed up existing $(basename "$target") → $backup"
  fi
}

# ── install_profile ───────────────────────────────────────────────────────────
# Usage: install_profile [DEST_PATH_OVERRIDE]
# When override provided, installs to that path (used in tests).
install_profile() {
  local dst="${1:-$HOME/.config/powershell/Microsoft.PowerShell_profile.ps1}"
  local src="$SCRIPT_DIR/profiles/velvet/profile.ps1"
  run_cmd mkdir -p "$(dirname "$dst")"
  backup_if_exists "$dst"
  run_cmd cp "$src" "$dst"
  success "PS7 profile installed to $dst"
}

# ── fix_vscode_font ───────────────────────────────────────────────────────────
# Usage: fix_vscode_font [SETTINGS_PATH_OVERRIDE]
# When override provided, skips the `code` binary check.
fix_vscode_font() {
  local settings_path="${1:-}"

  if [ -z "$settings_path" ]; then
    command -v code >/dev/null 2>&1 || {
      info "VS Code not found — skipping font config"
      return 0
    }
    if [ "$DOTFILES_OS" = "macos" ]; then
      settings_path="$HOME/Library/Application Support/Code/User/settings.json"
    else
      settings_path="$HOME/.config/Code/User/settings.json"
    fi
  fi

  # Already configured — nothing to do
  if grep -q '"terminal.integrated.fontFamily".*FiraCode' "$settings_path" 2>/dev/null; then
    success "VS Code: terminal.integrated.fontFamily already configured"
    return 0
  fi

  run_cmd mkdir -p "$(dirname "$settings_path")"

  if [ "$DRY_RUN" = "true" ]; then
    info "[dry-run] Would set terminal.integrated.fontFamily = FiraCode Nerd Font in:"
    info "          $settings_path"
    return 0
  fi

  local result
  result=$(python3 -c "
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
" "$settings_path")

  if [ "$result" = "JSONC_OR_INVALID" ]; then
    warn "VS Code settings.json contains comments or is invalid JSON — cannot auto-edit."
    warn "Add this line manually:"
    info '    "terminal.integrated.fontFamily": "FiraCode Nerd Font"'
  elif [ "$result" = "OK" ]; then
    success "VS Code: terminal.integrated.fontFamily set to FiraCode Nerd Font"
  else
    error "VS Code: unexpected python3 output: $result"
  fi
}

# ── cmd_status ────────────────────────────────────────────────────────────────
cmd_status() {
  header "PowerShell 7 Configuration"

  if command -v pwsh >/dev/null 2>&1; then
    success "pwsh installed ($(pwsh --version 2>/dev/null | head -1))"
  else
    warn "pwsh not found — install with: brew install --cask powershell"
  fi

  local profile_path="$HOME/.config/powershell/Microsoft.PowerShell_profile.ps1"
  if [ -f "$profile_path" ]; then
    success "profile installed at $profile_path"
  else
    warn "profile not installed — run ./powershell-config.sh"
  fi

  if ! command -v code >/dev/null 2>&1; then
    info "VS Code not installed — skipping font check"
    return 0
  fi

  local settings_path
  if [ "$DOTFILES_OS" = "macos" ]; then
    settings_path="$HOME/Library/Application Support/Code/User/settings.json"
  else
    settings_path="$HOME/.config/Code/User/settings.json"
  fi

  if grep -q '"terminal.integrated.fontFamily".*FiraCode' "$settings_path" 2>/dev/null; then
    success "VS Code: terminal.integrated.fontFamily configured"
  else
    warn "VS Code: terminal.integrated.fontFamily not set — run ./powershell-config.sh"
  fi
}

# ── main ──────────────────────────────────────────────────────────────────────
main() {
  header "PowerShell 7 Profile Setup"

  if ! command -v pwsh >/dev/null 2>&1; then
    error "pwsh not found — install with: brew install --cask powershell"
    exit 1
  fi

  install_profile
  fix_vscode_font

  echo ""
  success "Done. Restart pwsh to apply the new profile."
}

# ── Source-only guard (place after ALL function definitions) ──────────────────
[ "${POWERSHELL_CONFIG_SOURCE_ONLY:-}" = "1" ] && return 0

# ── Dispatch ──────────────────────────────────────────────────────────────────
if [ $# -gt 1 ]; then
  echo "Usage: powershell-config.sh [--status|--dry-run]" >&2
  exit 1
fi
case "${1:-}" in
  --status)  cmd_status; exit 0 ;;
  --dry-run) DRY_RUN=true; main ;;
  "")        main ;;
  *)         echo "Usage: powershell-config.sh [--status|--dry-run]" >&2; exit 1 ;;
esac
```

- [ ] **Step 2: Make the script executable**

```bash
chmod +x powershell-config.sh
```

- [ ] **Step 3: Run the tests — all should pass**

```bash
bash test-powershell-config.sh
```

Expected output:

```
── Syntax
  ✓ bash -n powershell-config.sh

── Profile install
  ✓ profile install: file created and matches source
  ✓ profile install: backup created when target exists
  ✓ profile install: new file installed after backup

── VS Code font
  ✓ vscode font: fontFamily written when key absent
  ✓ vscode font: file unchanged when fontFamily already set
  ✓ vscode font (JSONC): file unchanged
  ✓ vscode font (JSONC): warns user to add manually
  ✓ vscode font (absent): parent directory created
  ✓ vscode font (absent): settings.json created with font key

── Arg parsing
  ✓ --status exits 0
  ✓ --dry-run exits 0 (pwsh available)   [or exits 1 if pwsh not installed]
  ✓ --badflag exits non-zero

────────────────────────────────
  passed: 13  failed: 0
────────────────────────────────
```

If any tests fail: re-read the failing test assertion, compare with the function implementation, and fix the function. Common issues:
- `backup_if_exists` — check the `[ -e "$target" ]` condition and the `mv` command
- `fix_vscode_font` JSONC test — confirm the python3 `JSONDecodeError` path prints `JSONC_OR_INVALID` and the shell checks `grep -qi "manually"` output
- `fix_vscode_font` absent test — confirm `run_cmd mkdir -p` runs before the python3 call (not inside a `DRY_RUN` guard)

- [ ] **Step 4: Smoke test `--status` manually**

```bash
./powershell-config.sh --status
```

Expected: prints header, reports on pwsh, profile, and VS Code. No errors.

- [ ] **Step 5: Commit**

```bash
git add powershell-config.sh
git commit -m "feat: add powershell-config.sh installer"
```

---

## Task 4: Wire `test.sh` + update `HANDBOOK.md`

**Files:**
- Modify: `test.sh:184` — add syntax check after `font-config.sh` line
- Modify: `test.sh:263` — add PowerShell Config section before summary
- Modify: `HANDBOOK.md:564` — add PS7 section after Nerd Font section

- [ ] **Step 1: Add syntax check to `test.sh`**

In `test.sh`, find the line (around line 184):
```bash
syntax_check font-config.sh
```

Add immediately after it:
```bash
syntax_check powershell-config.sh
```

- [ ] **Step 2: Add PowerShell Config test section to `test.sh`**

In `test.sh`, find the Font Config section (around line 254):
```bash
# ════════════════════════════════════════════════
section "Font Config — test-font-config.sh"
# ════════════════════════════════════════════════

if bash "$SCRIPT_DIR/test-font-config.sh" >/dev/null 2>&1; then
  pass "test-font-config.sh passed"
else
  fail "test-font-config.sh — one or more checks failed (run ./test-font-config.sh for details)"
fi
```

Add immediately after that block (before the summary `echo ""`):
```bash
# ════════════════════════════════════════════════
section "PowerShell Config — test-powershell-config.sh"
# ════════════════════════════════════════════════

if bash "$SCRIPT_DIR/test-powershell-config.sh" >/dev/null 2>&1; then
  pass "test-powershell-config.sh passed"
else
  fail "test-powershell-config.sh — one or more checks failed (run ./test-powershell-config.sh for details)"
fi
```

- [ ] **Step 3: Run `test.sh` to confirm the new sections pass**

```bash
bash test.sh 2>/dev/null | grep -E "PowerShell|powershell"
```

Expected: both lines pass (syntax check + test file section).

- [ ] **Step 4: Add PS7 section to `HANDBOOK.md`**

In `HANDBOOK.md`, find the Nerd Font section ending (around line 564):
```markdown
---

## Brewfile
```

Insert a new section between those lines:

```markdown
## PowerShell 7

`powershell-config.sh` installs the velvet oh-my-posh profile for PowerShell 7 and ensures the VS Code terminal font is configured.

### Prerequisites

1. **Install pwsh:** `brew install --cask powershell`
2. **Install the velvet profile:** run `./choose-profile.sh` first — this installs `~/oh-my-posh/velvet.omp.json` which the PS7 profile references

### Install

```bash
./powershell-config.sh            # install profile + configure VS Code font
./powershell-config.sh --status   # check current state, no changes
./powershell-config.sh --dry-run  # preview what would be done
```

The profile is installed to `~/.config/powershell/Microsoft.PowerShell_profile.ps1`. Any existing file is backed up before overwriting.

### VS Code terminal font

`powershell-config.sh` sets `terminal.integrated.fontFamily` to `FiraCode Nerd Font` in VS Code's `settings.json`. If your settings file contains `//` comments (JSONC), the auto-edit is skipped and you're shown the exact line to add manually:

```json
"terminal.integrated.fontFamily": "FiraCode Nerd Font"
```

---
```

- [ ] **Step 5: Run the full test suite to confirm nothing broke**

```bash
bash test.sh
```

Expected: all tests pass (or pre-existing warns only — no new failures).

- [ ] **Step 6: Commit**

```bash
git add test.sh HANDBOOK.md
git commit -m "chore: wire powershell-config.sh into test.sh and HANDBOOK.md"
```
