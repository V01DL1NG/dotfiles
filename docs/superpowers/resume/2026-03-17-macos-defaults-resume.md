# Resume: macOS Defaults Implementation

**Created:** 2026-03-17
**Feature:** macOS system defaults script (`macos-defaults.sh`)
**Plan:** `docs/superpowers/plans/2026-03-17-macos-defaults.md`
**Spec:** `docs/superpowers/specs/2026-03-17-macos-defaults-design.md`
**Branch:** `master`

---

## Progress Summary

Using **subagent-driven-development**: fresh subagent per task, two-stage review (spec compliance → code quality) after each.

| Task | Description | Status | Commit |
|------|-------------|--------|--------|
| 1 | Scaffold, settings arrays, dry-run wrapper | ✅ Done (both reviews passed) | `f00e279` |
| 2 | `apply_one_setting()` + `test-macos-defaults.sh` | ⚠️ Implemented, reviews not yet run | `320f939` |
| 3 | `restart_services()`, `apply_list()`, fzf interaction | 🔲 Pending | — |
| 4 | `main()` dispatch and entry point | 🔲 Pending | — |
| 5 | Integrate into `install-all.sh` and `bootstrap.sh` | 🔲 Pending | — |
| 6 | `doctor.sh` checks for macOS defaults | 🔲 Pending | — |
| 7 | Add to `test.sh` + run full suite | 🔲 Pending | — |

---

## Resuming Task 2 — Spec Compliance Review

Task 2 was implemented (commit `320f939`) but the **spec compliance review and code quality review were NOT run** (rate limit hit mid-review dispatch).

### What was implemented in Task 2

Implementer appended to `macos-defaults.sh`:
- 5 category flag variables (`HAS_KEYBOARD`, `HAS_FINDER`, `HAS_DOCK`, `HAS_SYSTEM_OR_SAFARI`, `HAS_SAFARI`)
- `apply_one_setting()` with 32 case branches (all `defaults write` commands via `run_cmd()`)
- macOS 13+ version caveats for Safari and 24-hour clock
- A **temporary preset dispatch block** at the bottom (added to make dry-run tests pass before `main()` is wired in Task 4)

Also created `test-macos-defaults.sh` with 8 tests — all currently passing.

### What still needs to happen for Task 2

1. **Spec compliance review** — verify all 32 case branches are correct, HAS_* flags correct, macOS caveats present, test file correct
2. **Code quality review** — git range `f00e279..320f939`
3. Fix any issues found, mark Task 2 complete

### Key concern to check in spec review

The implementer added a **temporary preset dispatch block** at the bottom of `macos-defaults.sh` (not in the plan). It's needed now to make tests pass, and will be replaced by `main()` in Task 4. Spec reviewer should verify:
- It doesn't introduce bugs
- It will be cleanly replaced/absorbed by `main()` in Task 4

---

## Tasks 3–7: Full Task Text

All tasks are in the plan file. For convenience, here is a summary of what each task does:

### Task 3: `restart_services()`, `apply_list()`, fzf interaction
Append to `macos-defaults.sh`:
- `restart_services()` — conditional `killall` per `HAS_*` flags; early-return in dry-run; keyboard reminder
- `apply_list()` — iterates array and calls `apply_one_setting()` per entry
- `_fzf_pick()` — runs fzf with full 32 settings, accepts bind string
- `_fzf_minimal_bind()` — generates `start:first+select+down+select...` bind for N=9 items
- `pick_interactive()` — banner + `select` menu (Minimal/Opinionated/Custom) → calls `_pick_with_fzf`
- `_pick_with_fzf()` — dispatches to `_fzf_pick()` or `_fallback_no_fzf()` if fzf absent
- `_fallback_no_fzf()` — preset-only select menu when fzf not installed

Commit: `feat: restart_services(), apply_list(), and fzf interaction functions`

### Task 4: `main()` dispatch and entry point
Append to `macos-defaults.sh`:
- `main()` with preset vs interactive dispatch, dry-run banner, no-settings exit, restart call, done message
- `main` call at end of file
- Remove/replace the temporary preset dispatch block added in Task 2
- `chmod +x macos-defaults.sh`
- Run `bash test-macos-defaults.sh` — all pass
- Smoke test: `bash macos-defaults.sh minimal --dry-run`

Commit: `feat: main() dispatch — preset + interactive + dry-run modes complete`

### Task 5: Integrate into `install-all.sh` and `bootstrap.sh`
- `install-all.sh`: add macOS-gated `macos-defaults.sh` call immediately before the "Setup complete!" banner (lines ~70-74)
- `bootstrap.sh`: add `bash "$REPO_DIR/macos-defaults.sh" minimal` in `run_setup()` between `choose-profile.sh` and `install-all.sh`

Commit: `feat: integrate macos-defaults.sh into install-all.sh and bootstrap.sh`

### Task 6: `doctor.sh` checks
Add `section_macos_defaults()` after `section_iterm2()` (~line 306):
- macOS-only guard (`[ "$DOTFILES_OS" != "macos" ] && return`)
- Check 1: `~/Desktop/Screenshots` dir exists → pass/warn
- Check 2: `KeyRepeat` value < 6 → pass/warn
Call `section_macos_defaults` from `main()` after `section_iterm2`.

Commit: `feat: doctor.sh section_macos_defaults — Screenshots dir and KeyRepeat checks`

### Task 7: Add to `test.sh` + run full suite
- Add `syntax_check macos-defaults.sh` after `syntax_check bootstrap-server.sh` line (~179)
- Add `test-macos-defaults.sh` integration block after the `test-platform.sh` block (~line 185-189), with `uname -s != Darwin` guard
- Run `bash test.sh` — all pass
- Run `bash test-macos-defaults.sh` — all pass

Commit: `test: add macos-defaults.sh syntax check and test-macos-defaults.sh to test suite`

---

## Spec Reviewer Context (for spec compliance reviews)

**Spec file:** `docs/superpowers/specs/2026-03-17-macos-defaults-design.md`

Key spec points for reviewing Tasks 3–7:
- All `defaults write` and `mkdir` calls via `run_cmd()` (except `killall` in `restart_services`)
- `restart_services()`: early-return when `DRY_RUN=true`; all `killall` guarded with `|| true`; keyboard is a reminder only (no killall)
- fzf requires >= 0.30; `start:` event + `+` action chaining
- fzf fallback when not installed: `select` menu with Minimal/Opinionated/Skip
- `install-all.sh`: interactive call (no preset); `bootstrap.sh`: `minimal` preset
- `doctor.sh`: macOS-only section; `warn_count` helper (not `warn`) for failures
- `test.sh`: syntax check uses `bash -n`; integration block uses `uname -s` (not `$DOTFILES_OS`)

---

## TodoWrite IDs (for TaskUpdate when resuming)

These task IDs are active in the session. Use `TaskUpdate` to mark progress:

| Task | TodoWrite ID |
|------|-------------|
| Task 1 | #19 (completed) |
| Task 2 | #20 (in_progress) |
| Task 3 | #21 (pending) |
| Task 4 | #22 (pending) |
| Task 5 | #23 (pending) |
| Task 6 | #24 (pending) |
| Task 7 | #25 (pending) |

---

## Post-Implementation Checklist (run after Task 7)

- [ ] `bash -n macos-defaults.sh` — syntax clean
- [ ] `bash test-macos-defaults.sh` — all pass
- [ ] `bash test.sh` — all pass
- [ ] `bash macos-defaults.sh minimal --dry-run` — prints commands, exits 0
- [ ] `bash macos-defaults.sh opinionated --dry-run` — more commands, exits 0
- [ ] `bash macos-defaults.sh bogus 2>&1` — prints error, exits non-zero
- [ ] `bash doctor.sh` — shows "macOS System Defaults" section
- [ ] `grep -q 'macos-defaults.sh' install-all.sh` — integration present
- [ ] `grep -q 'macos-defaults.sh' bootstrap.sh` — integration present
