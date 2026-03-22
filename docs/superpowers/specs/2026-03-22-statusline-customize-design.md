# Statusline Customizer — Design Spec

**Date:** 2026-03-22
**Status:** Draft

---

## Overview

Add a `statusline-customize.sh` fzf-based TUI that lets users configure which segments appear in the Claude Code status line, in what order, and with what colors/thresholds. The customizer generates `~/.claude/statusline-command.sh` (a fast, fully-baked bash script) from a persistent `statusline-config.json` that stores the user's choices.

**Problem:** The current `~/.claude/statusline-command.sh` has all segments, colors, and thresholds hardcoded. There is no way to toggle segments, reorder them, or adjust thresholds without manually editing the script.

**Goals:**
- Multi-stage fzf TUI: toggle/reorder segments → configure each segment → preview + apply
- Persistent `statusline-config.json` stores choices and serves as re-customization input
- Code assembler generates a baked-in `~/.claude/statusline-command.sh` (no runtime config reads)
- Velvet palette colors only
- macOS + Linux supported

**Non-goals:**
- Custom hex color input
- Custom shell-command segments
- Modifying Claude Code `settings.json` (already points to `~/.claude/statusline-command.sh`)

---

## Architecture

### Files

| File | Location | Tracked | Responsibility |
|---|---|---|---|
| `statusline-customize.sh` | dotfiles root | ✅ | fzf TUI + code assembler |
| `statusline-skeleton-config.json` | dotfiles root | ✅ | default config, used on first run |
| `statusline-config.json` | dotfiles root | ❌ gitignored | machine-local active config |
| `~/.claude/statusline-command.sh` | `~/.claude/` | ❌ outside repo | generated status line script |
| `test-statusline-customize.sh` | dotfiles root | ✅ | test suite |
| `test.sh` | dotfiles root | modify | add syntax check + test section |
| `.gitignore` | dotfiles root | modify | add `statusline-config.json` |

`settings.json` already references `bash /Users/v01d/.claude/statusline-command.sh` — no change needed.

### First-run vs re-run

- **First run** (no `statusline-config.json`): copy skeleton → TUI → generate
- **Re-run** (config exists): load existing config → TUI showing current state → regenerate on apply

---

## Segment Catalog

| Key | Display example | Configurable options | Data source |
|---|---|---|---|
| `path` | `~/code/dotfiles` | `max_depth` (1–5), `color` | `.workspace.current_dir` |
| `git` | ` main *3` | `show_changes` (on/off), `color` | `git` CLI |
| `vim_mode` | `INS` / `NRM` | `insert_color`, `normal_color` | `.vim.mode` |
| `model` | `claude-sonnet-4-6` | `color` | `.model.display_name` |
| `ctx` | `ctx:84%` | `warn_threshold` (%), `color`, `warn_color` | `.context_window.remaining_percentage` |
| `5h_pct` | `5h:42%` | `warn_threshold` (%), `color`, `warn_color` | `.rate_limits.five_hour.used_percentage` |
| `5h_tokens` | `5h:12k/40k` | `warn_threshold` (%), `color`, `warn_color` | `.rate_limits.five_hour.tokens_used` + `.tokens_limit` |
| `weekly` | `wk:3k/10k` | `warn_threshold` (%), `color`, `warn_color` | `.rate_limits.weekly.used_percentage` + tokens |
| `reset_5h` | `rst:14m` | `color` | `.rate_limits.five_hour.reset_at` |
| `reset_weekly` | `rst-wk:2d` | `color` | `.rate_limits.weekly.reset_at` |
| `cost` | `$0.42` | `warn_threshold` ($), `color`, `warn_color` | `.billing.session_cost` |
| `mode` | `plan` / `auto` / `normal` | `color` per mode value | `.mode` |

All JSON fields use `// empty` guards — absent fields are silently skipped (consistent with existing `statusline-command.sh`).

**Skeleton default segments:** `path`, `git`, `ctx`, `5h_pct`, `model` (in that order).

---

## Velvet Palette

Color names available in the TUI:

| Name | Hex |
|---|---|
| `fg` | `#EFDCF9` |
| `accent` | `#69307A` |
| `cyan` | `#7FD5EA` |
| `yellow` | `#E4F34A` |
| `dim` | `#4c1f5e` |
| `red` | `#FF3C3C` |
| `lavender` | `#341948` |

---

## `statusline-config.json` Schema

```json
{
  "segments": ["path", "git", "ctx", "5h_pct", "model"],
  "segment_config": {
    "path": {
      "max_depth": 3,
      "color": "fg"
    },
    "git": {
      "show_changes": true,
      "color": "accent"
    },
    "vim_mode": {
      "insert_color": "cyan",
      "normal_color": "yellow"
    },
    "model": {
      "color": "dim"
    },
    "ctx": {
      "warn_threshold": 20,
      "color": "cyan",
      "warn_color": "red"
    },
    "5h_pct": {
      "warn_threshold": 80,
      "color": "yellow",
      "warn_color": "red"
    },
    "5h_tokens": {
      "warn_threshold": 80,
      "color": "yellow",
      "warn_color": "red"
    },
    "weekly": {
      "warn_threshold": 80,
      "color": "yellow",
      "warn_color": "red"
    },
    "reset_5h": {
      "color": "dim"
    },
    "reset_weekly": {
      "color": "dim"
    },
    "cost": {
      "warn_threshold": 5.0,
      "color": "fg",
      "warn_color": "red"
    },
    "mode": {
      "plan_color": "cyan",
      "auto_color": "yellow",
      "normal_color": "dim"
    }
  },
  "palette": {
    "fg":       "#EFDCF9",
    "accent":   "#69307A",
    "cyan":     "#7FD5EA",
    "yellow":   "#E4F34A",
    "dim":      "#4c1f5e",
    "red":      "#FF3C3C",
    "lavender": "#341948"
  }
}
```

`segments` array defines both which segments are enabled and their display order.

---

## `statusline-customize.sh`

### Pattern

Follows repo conventions:
- `set -euo pipefail`
- `SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"`
- `STATUSLINE_CUSTOMIZE_SOURCE_ONLY=1` source guard placed **after all function definitions**
- Color helpers: `info`, `success`, `warn`, `error`, `header`
- Cross-platform: macOS + Linux; no top-level OS guard

### Arg Parsing

```
./statusline-customize.sh            # full TUI flow
./statusline-customize.sh --generate # regenerate from existing config, no TUI
./statusline-customize.sh --status   # print current config summary, no changes
```

Unknown flags exit non-zero with usage. Combining multiple flags exits non-zero.

### TUI Flow (3 stages)

**Stage 1 — Segment toggle + order**

Two fzf passes:

1. `fzf --multi` — all 12 segments listed with `[✓]` / `[ ]` prefix showing current enabled state. Space toggles, Enter confirms selection.
2. **Ordered selection loop** — fzf does not support positional drag-to-reorder. Instead: run a loop of `N` fzf passes where `N` = number of enabled segments. Each pass shows the remaining (unordered) segments and asks "pick next in order". Each selection is appended to the ordered list and removed from the remaining pool. A header shows progress: `"Pick segment 2 of 5"`. Pressing Escape on any pass cancels reordering and keeps the previous order.

**Stage 2 — Per-segment config**

For each enabled segment (in order), a `fzf` menu lists its options with current values:

```
threshold (warn %)    [current: 20]
color (normal)        [current: cyan]
color (warn)          [current: red]
```

Select an option → sub-picker:
- **Color options:** fzf list of 7 palette names
- **Numeric thresholds:** fzf list of preset values (`10 15 20 25 30 50 80`) with `--print-query` to allow free-text entry
- **On/off toggles:** two-item fzf (`yes` / `no`)

Pressing Escape on a segment's menu skips it (keeps current values). This is handled by absorbing fzf's non-zero exit with `|| true`.

**Stage 3 — Preview + apply**

1. Call `generate_statusline` to a temp file
2. Pipe mock JSON through it to render a preview:
   ```bash
   echo '{"workspace":{"current_dir":"/Users/demo/code/dotfiles"},"model":{"display_name":"claude-sonnet-4-6"},"context_window":{"remaining_percentage":84},"rate_limits":{"five_hour":{"used_percentage":42}},"vim":{"mode":"INSERT"}}' \
     | bash "$tmp_script"
   ```
3. Print rendered preview to terminal
4. Two-item fzf: `Apply` / `Cancel`
5. On Apply: write `statusline-config.json` + copy generated script to `~/.claude/statusline-command.sh`
6. On Cancel: exit 0 with no changes

### Code Assembler (`generate_statusline`)

```
generate_statusline CONFIG_PATH OUTPUT_PATH
```

Uses `python3` (already a repo dependency) to parse `CONFIG_PATH`. Assembles the output script by:

1. Emitting the preamble: shebang, `set -euo pipefail`, `input=$(cat)`, ANSI color vars (derived from `palette` in config — `\033[38;2;R;G;B;m` format from hex values)
2. Looping over `segments` array — for each, emitting the corresponding bash code block with config values substituted inline (no `{{}}` templates — values are directly interpolated by the python3 assembler)
3. Emitting the join + print footer: `printf "%b" "$(IFS=' '; echo "${parts_out[*]}")"` + newline

Each segment's bash code block is a string constant defined inside `statusline-customize.sh`. The assembler is a `generate_statusline()` bash function that uses an inline `python3` script to read the JSON and drive the assembly.

### `--generate` Mode

Runs `generate_statusline` from existing `statusline-config.json` → `~/.claude/statusline-command.sh`. If no config exists, copies skeleton first. Useful for re-applying after a dotfiles update.

### `--status` Mode

Prints current config summary (enabled segments, key settings) without launching fzf. Always exits 0.

---

## Testing (`test-statusline-customize.sh`)

No top-level OS guard. `test.sh` includes without macOS guard.

### Tests

**Syntax checks:**
- `bash -n statusline-customize.sh`
- `python3 -c "import json; json.load(open('statusline-skeleton-config.json'))"` — valid JSON

**Assembler output** (source `STATUSLINE_CUSTOMIZE_SOURCE_ONLY=1`):
- `generate_statusline` with skeleton config → output passes `bash -n`
- Generated script with `ctx` enabled + `warn_threshold: 20` → output contains `20`
- Config with `segments: ["model", "path"]` → `model` code block appears before `path` block in output
- Config with `git` disabled → output does not contain `git` code

**Preview smoke test:**
- `generate_statusline` → pipe mock JSON through output script → exits 0

**First-run skeleton copy:**
- Run `--generate` with no `statusline-config.json` in temp dir → assert config created from skeleton

**Arg parsing:**
- `--status` exits 0
- `--generate` exits 0 (uses skeleton if no config)
- `--badflag` exits non-zero

### Wire into `test.sh`

- `syntax_check statusline-customize.sh` added after `syntax_check powershell-config.sh`
- Statusline Customize section added after PowerShell Config section — no macOS guard

---

## Edge Cases

| Scenario | Behaviour |
|---|---|
| No `statusline-config.json` on first run | Copy skeleton → proceed with TUI |
| `~/.claude/` does not exist | `mkdir -p ~/.claude/` before writing generated script |
| fzf not installed | Error and exit 1 (fzf is already required by other dotfiles scripts) |
| User presses Escape at Stage 1 | Exit 0, no changes |
| User presses Escape at Stage 3 confirm | Exit 0, no changes |
| Segment JSON field absent at runtime | `// empty` guard in generated script silently skips segment output |
| `--generate` with no config | Copy skeleton, generate from it |
