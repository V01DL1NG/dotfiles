# Statusline Customizer Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build a `statusline-customize.sh` fzf TUI that generates a baked-in `~/.claude/statusline-command.sh` from a persistent `statusline-config.json`, enabling users to toggle segments, reorder them, and configure colors/thresholds.

**Architecture:** A python3-driven code assembler (`generate_statusline`) reads `statusline-config.json` and emits a standalone bash script with all values baked in. A three-stage fzf TUI (toggle → configure → preview/apply) updates the config and re-runs the assembler. The skeleton config in the repo provides defaults; the machine-local config is gitignored.

**Tech Stack:** bash, fzf, python3 (stdlib only), jq (already required by repo)

---

## File Map

| File | Change |
|---|---|
| `statusline-skeleton-config.json` | Create — default config |
| `statusline-customize.sh` | Create — TUI + assembler |
| `test-statusline-customize.sh` | Create — test suite |
| `test.sh` | Modify — add syntax check + test section |
| `.gitignore` | Modify — add `statusline-config.json` |

---

## Task 1: `statusline-skeleton-config.json` + `.gitignore`

**Files:**
- Create: `statusline-skeleton-config.json`
- Modify: `.gitignore`

- [ ] **Step 1: Create `statusline-skeleton-config.json`**

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

- [ ] **Step 2: Verify it is valid JSON**

```bash
python3 -c "import json; json.load(open('statusline-skeleton-config.json')); print('valid')"
```

Expected: `valid`

- [ ] **Step 3: Add `statusline-config.json` to `.gitignore`**

Append to `.gitignore`:
```
# Statusline local customization (machine-specific, generated from skeleton)
statusline-config.json
```

- [ ] **Step 4: Commit**

```bash
git add statusline-skeleton-config.json .gitignore
git commit -m "feat: add statusline skeleton config and gitignore entry"
```

---

## Task 2: `test-statusline-customize.sh` — all tests (red phase)

Write the full test file before implementing the script. Every test except the syntax check will fail until Task 3 is complete.

**Files:**
- Create: `test-statusline-customize.sh`

- [ ] **Step 1: Create `test-statusline-customize.sh`**

```bash
#!/usr/bin/env bash
# test-statusline-customize.sh — test suite for statusline-customize.sh

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PASS=0; FAIL=0

pass() { echo "  ✓ $1"; PASS=$((PASS + 1)); }
fail() { echo "  ✗ $1"; FAIL=$((FAIL + 1)); }
section() { echo ""; echo "── $1"; }

# ── Syntax ────────────────────────────────────────────────────────────────────
section "Syntax"

if bash -n "$SCRIPT_DIR/statusline-customize.sh" 2>/dev/null; then
  pass "bash -n statusline-customize.sh"
else
  fail "bash -n statusline-customize.sh — syntax error"
fi

if python3 -c "import json; json.load(open('$SCRIPT_DIR/statusline-skeleton-config.json'))" 2>/dev/null; then
  pass "statusline-skeleton-config.json valid JSON"
else
  fail "statusline-skeleton-config.json invalid JSON"
fi

# ── Assembler ─────────────────────────────────────────────────────────────────
section "Assembler"

STATUSLINE_CUSTOMIZE_SOURCE_ONLY=1 . "$SCRIPT_DIR/statusline-customize.sh"

TMPDIR_TEST="$(mktemp -d)"
trap 'rm -rf "$TMPDIR_TEST"' EXIT

# skeleton config → output passes bash -n
generate_statusline "$SCRIPT_DIR/statusline-skeleton-config.json" "$TMPDIR_TEST/out1.sh"
if bash -n "$TMPDIR_TEST/out1.sh" 2>/dev/null; then
  pass "assembler: skeleton config produces valid bash"
else
  fail "assembler: skeleton config output has syntax error"
fi

# ctx + warn_threshold 20 → output contains "20"
cat > "$TMPDIR_TEST/cfg_ctx.json" << 'EOF'
{
  "segments": ["ctx"],
  "segment_config": {
    "ctx": { "warn_threshold": 20, "color": "cyan", "warn_color": "red" }
  },
  "palette": {
    "fg": "#EFDCF9", "accent": "#69307A", "cyan": "#7FD5EA",
    "yellow": "#E4F34A", "dim": "#4c1f5e", "red": "#FF3C3C", "lavender": "#341948"
  }
}
EOF
generate_statusline "$TMPDIR_TEST/cfg_ctx.json" "$TMPDIR_TEST/out_ctx.sh"
if grep -q "20" "$TMPDIR_TEST/out_ctx.sh"; then
  pass "assembler: warn_threshold 20 baked into output"
else
  fail "assembler: warn_threshold 20 not found in output"
fi

# segments ["model","path"] → model code block before path code block
cat > "$TMPDIR_TEST/cfg_order.json" << 'EOF'
{
  "segments": ["model", "path"],
  "segment_config": {
    "model": { "color": "dim" },
    "path":  { "max_depth": 3, "color": "fg" }
  },
  "palette": {
    "fg": "#EFDCF9", "accent": "#69307A", "cyan": "#7FD5EA",
    "yellow": "#E4F34A", "dim": "#4c1f5e", "red": "#FF3C3C", "lavender": "#341948"
  }
}
EOF
generate_statusline "$TMPDIR_TEST/cfg_order.json" "$TMPDIR_TEST/out_order.sh"
model_line=$(grep -n "# model" "$TMPDIR_TEST/out_order.sh" | head -1 | cut -d: -f1)
path_line=$(grep -n "# path" "$TMPDIR_TEST/out_order.sh" | head -1 | cut -d: -f1)
if [ -n "$model_line" ] && [ -n "$path_line" ] && [ "$model_line" -lt "$path_line" ]; then
  pass "assembler: model appears before path when ordered [model, path]"
else
  fail "assembler: segment order not respected (model_line=$model_line path_line=$path_line)"
fi

# git disabled → no git code in output
cat > "$TMPDIR_TEST/cfg_nopath.json" << 'EOF'
{
  "segments": ["model"],
  "segment_config": {
    "model": { "color": "dim" }
  },
  "palette": {
    "fg": "#EFDCF9", "accent": "#69307A", "cyan": "#7FD5EA",
    "yellow": "#E4F34A", "dim": "#4c1f5e", "red": "#FF3C3C", "lavender": "#341948"
  }
}
EOF
generate_statusline "$TMPDIR_TEST/cfg_nopath.json" "$TMPDIR_TEST/out_nopath.sh"
if ! grep -q "# git" "$TMPDIR_TEST/out_nopath.sh" 2>/dev/null; then
  pass "assembler: git absent when not in segments"
else
  fail "assembler: git code found even though git not in segments"
fi

# ── Preview smoke test ────────────────────────────────────────────────────────
section "Preview smoke test"

MOCK_JSON='{"workspace":{"current_dir":"/Users/demo/code/dotfiles"},"model":{"display_name":"claude-sonnet-4-6"},"context_window":{"remaining_percentage":84},"rate_limits":{"five_hour":{"used_percentage":42}},"vim":{"mode":"INSERT"}}'
generate_statusline "$SCRIPT_DIR/statusline-skeleton-config.json" "$TMPDIR_TEST/preview.sh"
if echo "$MOCK_JSON" | bash "$TMPDIR_TEST/preview.sh" >/dev/null 2>&1; then
  pass "preview: skeleton config renders without error"
else
  fail "preview: skeleton config render failed"
fi

# ── First-run skeleton copy ───────────────────────────────────────────────────
section "First-run skeleton copy"

CUSTOM_CONFIG_PATH="$TMPDIR_TEST/statusline-config.json"
SKELETON_PATH="$SCRIPT_DIR/statusline-skeleton-config.json"

# ensure_config should copy skeleton when config absent
ensure_config "$CUSTOM_CONFIG_PATH" "$SKELETON_PATH"
if [ -f "$CUSTOM_CONFIG_PATH" ]; then
  if diff -q "$SKELETON_PATH" "$CUSTOM_CONFIG_PATH" >/dev/null 2>&1; then
    pass "first-run: config created from skeleton"
  else
    fail "first-run: config created but differs from skeleton"
  fi
else
  fail "first-run: config not created"
fi

# ensure_config should NOT overwrite existing config
echo '{"existing":true}' > "$CUSTOM_CONFIG_PATH"
ensure_config "$CUSTOM_CONFIG_PATH" "$SKELETON_PATH"
if grep -q '"existing"' "$CUSTOM_CONFIG_PATH"; then
  pass "first-run: existing config not overwritten"
else
  fail "first-run: existing config was overwritten"
fi

# ── Arg parsing ───────────────────────────────────────────────────────────────
section "Arg parsing"

# Use isolated config/output paths so tests never write to real files
STATUSLINE_CONFIG_PATH="$TMPDIR_TEST/arg-test-config.json" \
  bash "$SCRIPT_DIR/statusline-customize.sh" --status </dev/null >/dev/null 2>&1 \
  && pass "--status exits 0" \
  || fail "--status exits non-zero"

STATUSLINE_CONFIG_PATH="$TMPDIR_TEST/arg-test-config.json" \
STATUSLINE_OUTPUT_PATH="$TMPDIR_TEST/arg-test-output.sh" \
  bash "$SCRIPT_DIR/statusline-customize.sh" --generate </dev/null >/dev/null 2>&1 \
  && pass "--generate exits 0" \
  || fail "--generate exits non-zero"

bash "$SCRIPT_DIR/statusline-customize.sh" --badflag </dev/null >/dev/null 2>&1 \
  && fail "--badflag should exit non-zero" \
  || pass "--badflag exits non-zero"

# ── Summary ───────────────────────────────────────────────────────────────────
echo ""
echo "────────────────────────────────"
printf "  passed: %d  failed: %d\n" "$PASS" "$FAIL"
echo "────────────────────────────────"
[ "$FAIL" -eq 0 ]
```

- [ ] **Step 2: Run tests — confirm failures**

```bash
bash test-statusline-customize.sh
```

Expected: syntax check passes (skeleton JSON valid), everything else fails (`statusline-customize.sh` doesn't exist yet).

- [ ] **Step 3: Commit the test file**

```bash
git add test-statusline-customize.sh
git commit -m "test: add test-statusline-customize.sh (red phase)"
```

---

## Task 3: `statusline-customize.sh` — full implementation

**Files:**
- Create: `statusline-customize.sh`

- [ ] **Step 1: Create `statusline-customize.sh`**

```bash
#!/usr/bin/env bash
# statusline-customize.sh — Claude Code status line configurator
#
# Usage:
#   ./statusline-customize.sh            # interactive TUI
#   ./statusline-customize.sh --generate # regenerate from config, no TUI
#   ./statusline-customize.sh --status   # print config summary
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CONFIG_PATH="${STATUSLINE_CONFIG_PATH:-$SCRIPT_DIR/statusline-config.json}"
SKELETON_PATH="$SCRIPT_DIR/statusline-skeleton-config.json"
OUTPUT_PATH="${STATUSLINE_OUTPUT_PATH:-$HOME/.claude/statusline-command.sh}"

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

# ── ensure_config ─────────────────────────────────────────────────────────────
# Usage: ensure_config CONFIG_PATH SKELETON_PATH
ensure_config() {
  local cfg="$1" skel="$2"
  if [ ! -f "$cfg" ]; then
    cp "$skel" "$cfg"
    info "Created $(basename "$cfg") from skeleton"
  fi
}

# ── generate_statusline ───────────────────────────────────────────────────────
# Usage: generate_statusline CONFIG_PATH OUTPUT_PATH
generate_statusline() {
  local cfg="$1" out="$2"
  mkdir -p "$(dirname "$out")"
  python3 - "$cfg" "$out" << 'PYEOF'
import json, sys

cfg_path, out_path = sys.argv[1], sys.argv[2]
with open(cfg_path) as f:
    cfg = json.load(f)

palette  = cfg["palette"]
seg_cfg  = cfg.get("segment_config", {})
segments = cfg["segments"]

def ansi(name):
    h = palette[name].lstrip('#')
    r, g, b = int(h[0:2],16), int(h[2:4],16), int(h[4:6],16)
    return f"\\033[38;2;{r};{g};{b}m"

def cv(name):
    return f"C_{name.upper()}"

lines = [
    '#!/usr/bin/env bash',
    '# Generated by statusline-customize.sh — edit with: ./statusline-customize.sh',
    'input=$(cat)',
    '',
    'RESET="\\033[0m"',
]

for name, hexval in palette.items():
    h = hexval.lstrip('#')
    r, g, b = int(h[0:2],16), int(h[2:4],16), int(h[4:6],16)
    lines.append(f'C_{name.upper()}="\\033[38;2;{r};{g};{b}m"')

lines += ['', 'parts_out=()', '']

for seg in segments:
    sc = seg_cfg.get(seg, {})

    if seg == 'path':
        d  = int(sc.get('max_depth', 3))
        c  = cv(sc.get('color', 'fg'))
        lines += [
            '# path',
            'cwd=$(echo "$input" | jq -r \'.workspace.current_dir // .cwd // empty\')',
            'if [ -n "$cwd" ]; then',
            '  display_path="${cwd/#$HOME/~}"',
            '  IFS=\'/\' read -ra _pp <<< "$display_path"',
            f'  if [ "${{#_pp[@]}}" -gt {d + 1} ]; then',
            f'    display_path="${{_pp[0]}}/${{_pp[1]}}/.../${{_pp[-2]}}/${{_pp[-1]}}"',
            '  fi',
            f'  parts_out+=("$(printf "${{{c}}} %s${{RESET}}" "$display_path")")',
            'fi',
            '',
        ]

    elif seg == 'git':
        show = sc.get('show_changes', True)
        c    = cv(sc.get('color', 'accent'))
        block = [
            '# git',
            '_git_info=""',
            'if _gbr=$(git -C "${cwd:-$PWD}" symbolic-ref --short HEAD 2>/dev/null); then',
        ]
        if show:
            block += [
                '  _wt=$(git -C "${cwd:-$PWD}" status --porcelain 2>/dev/null | wc -l | tr -d \' \')',
                '  _git_info="$_gbr"',
                '  [ "$_wt" -gt 0 ] && _git_info="$_git_info *$_wt"',
            ]
        else:
            block.append('  _git_info="$_gbr"')
        block += [
            'fi',
            'if [ -n "$_git_info" ]; then',
            f'  parts_out+=("$(printf "${{{c}}}$(printf \'\\\\ue0b3\')${{RESET}} ${{C_FG}}%s${{RESET}}" "$_git_info")")',
            'fi',
            '',
        ]
        lines += block

    elif seg == 'vim_mode':
        ic = cv(sc.get('insert_color', 'cyan'))
        nc = cv(sc.get('normal_color', 'yellow'))
        lines += [
            '# vim_mode',
            '_vim=$(echo "$input" | jq -r \'.vim.mode // empty\')',
            'if [ -n "$_vim" ]; then',
            f'  if [ "$_vim" = "NORMAL" ]; then',
            f'    parts_out+=("$(printf "${{{nc}}}NRM${{RESET}}")")',
            f'  else',
            f'    parts_out+=("$(printf "${{{ic}}}INS${{RESET}}")")',
            '  fi',
            'fi',
            '',
        ]

    elif seg == 'model':
        c = cv(sc.get('color', 'dim'))
        lines += [
            '# model',
            '_model=$(echo "$input" | jq -r \'.model.display_name // empty\')',
            'if [ -n "$_model" ]; then',
            f'  parts_out+=("$(printf "${{{c}}}$(printf \'\\\\ue0b3\')${{RESET}} ${{C_FG}}%s${{RESET}}" "$_model")")',
            'fi',
            '',
        ]

    elif seg == 'ctx':
        thr = int(sc.get('warn_threshold', 20))
        c   = cv(sc.get('color', 'cyan'))
        wc  = cv(sc.get('warn_color', 'red'))
        lines += [
            '# ctx',
            '_ctx=$(echo "$input" | jq -r \'.context_window.remaining_percentage // empty\')',
            'if [ -n "$_ctx" ]; then',
            '  _ctx_i=$(printf "%.0f" "$_ctx")',
            f'  if [ "$_ctx_i" -le {thr} ]; then _cc="${{{wc}}}"; else _cc="${{{c}}}"; fi',
            '  parts_out+=("$(printf "$_cc ctx:%s%%${{RESET}}" "$_ctx_i")")',
            'fi',
            '',
        ]

    elif seg == '5h_pct':
        thr = int(sc.get('warn_threshold', 80))
        c   = cv(sc.get('color', 'yellow'))
        wc  = cv(sc.get('warn_color', 'red'))
        lines += [
            '# 5h_pct',
            '_5h=$(echo "$input" | jq -r \'.rate_limits.five_hour.used_percentage // empty\')',
            'if [ -n "$_5h" ]; then',
            '  _5h_i=$(printf "%.0f" "$_5h")',
            f'  if [ "$_5h_i" -ge {thr} ]; then _5hc="${{{wc}}}"; else _5hc="${{{c}}}"; fi',
            '  parts_out+=("$(printf "$_5hc 5h:%s%%${{RESET}}" "$_5h_i")")',
            'fi',
            '',
        ]

    elif seg == '5h_tokens':
        thr = int(sc.get('warn_threshold', 80))
        c   = cv(sc.get('color', 'yellow'))
        wc  = cv(sc.get('warn_color', 'red'))
        lines += [
            '# 5h_tokens',
            '_5hu=$(echo "$input" | jq -r \'.rate_limits.five_hour.tokens_used // empty\')',
            '_5hl=$(echo "$input" | jq -r \'.rate_limits.five_hour.tokens_limit // empty\')',
            'if [ -n "$_5hu" ] && [ -n "$_5hl" ] && [ "$_5hl" -gt 0 ]; then',
            '  _5hu_k=$(( _5hu / 1000 ))',
            '  _5hl_k=$(( _5hl / 1000 ))',
            '  _5h_tok_pct=$(( _5hu * 100 / _5hl ))',
            f'  if [ "$_5h_tok_pct" -ge {thr} ]; then _5htc="${{{wc}}}"; else _5htc="${{{c}}}"; fi',
            '  parts_out+=("$(printf "$_5htc 5h:%sk/%sk${{RESET}}" "$_5hu_k" "$_5hl_k")")',
            'fi',
            '',
        ]

    elif seg == 'weekly':
        thr = int(sc.get('warn_threshold', 80))
        c   = cv(sc.get('color', 'yellow'))
        wc  = cv(sc.get('warn_color', 'red'))
        lines += [
            '# weekly',
            '_wku=$(echo "$input" | jq -r \'.rate_limits.weekly.tokens_used // empty\')',
            '_wkl=$(echo "$input" | jq -r \'.rate_limits.weekly.tokens_limit // empty\')',
            '_wkp=$(echo "$input" | jq -r \'.rate_limits.weekly.used_percentage // empty\')',
            'if [ -n "$_wku" ] && [ -n "$_wkl" ] && [ "$_wkl" -gt 0 ]; then',
            '  _wku_k=$(( _wku / 1000 ))',
            '  _wkl_k=$(( _wkl / 1000 ))',
            '  _wkp_i=$(printf "%.0f" "${_wkp:-0}")',
            f'  if [ "$_wkp_i" -ge {thr} ]; then _wkc="${{{wc}}}"; else _wkc="${{{c}}}"; fi',
            '  parts_out+=("$(printf "$_wkc wk:%sk/%sk${{RESET}}" "$_wku_k" "$_wkl_k")")',
            'fi',
            '',
        ]

    elif seg == 'reset_5h':
        c = cv(sc.get('color', 'dim'))
        lines += [
            '# reset_5h',
            '_rst5=$(echo "$input" | jq -r \'.rate_limits.five_hour.reset_at // empty\')',
            'if [ -n "$_rst5" ]; then',
            '  _rst5_fmt=$(python3 -c "',
            'import datetime,sys',
            't=datetime.datetime.fromisoformat(sys.argv[1].replace(\"Z\",\"+00:00\"))',
            'now=datetime.datetime.now(datetime.timezone.utc)',
            'd=int((t-now).total_seconds()/60)',
            'print(str(d)+\"m\" if d>0 else \"now\")',
            '" "$_rst5" 2>/dev/null || echo "$_rst5")',
            f'  parts_out+=("$(printf "${{{c}}} rst:%s${{RESET}}" "$_rst5_fmt")")',
            'fi',
            '',
        ]

    elif seg == 'reset_weekly':
        c = cv(sc.get('color', 'dim'))
        lines += [
            '# reset_weekly',
            '_rstwk=$(echo "$input" | jq -r \'.rate_limits.weekly.reset_at // empty\')',
            'if [ -n "$_rstwk" ]; then',
            '  _rstwk_fmt=$(python3 -c "',
            'import datetime,sys',
            't=datetime.datetime.fromisoformat(sys.argv[1].replace(\"Z\",\"+00:00\"))',
            'now=datetime.datetime.now(datetime.timezone.utc)',
            'd=int((t-now).total_seconds()/86400)',
            'print(str(d)+\"d\" if d>0 else \"today\")',
            '" "$_rstwk" 2>/dev/null || echo "$_rstwk")',
            f'  parts_out+=("$(printf "${{{c}}} rst-wk:%s${{RESET}}" "$_rstwk_fmt")")',
            'fi',
            '',
        ]

    elif seg == 'cost':
        thr = float(sc.get('warn_threshold', 5.0))
        c   = cv(sc.get('color', 'fg'))
        wc  = cv(sc.get('warn_color', 'red'))
        lines += [
            '# cost',
            '_cost=$(echo "$input" | jq -r \'.billing.session_cost // empty\')',
            'if [ -n "$_cost" ]; then',
            f'  _cost_warn=$(python3 -c "print(1 if float(\'$_cost\') >= {thr} else 0)" 2>/dev/null || echo 0)',
            f'  if [ "$_cost_warn" = "1" ]; then _costc="${{{wc}}}"; else _costc="${{{c}}}"; fi',
            r'  parts_out+=("$(printf "$_costc \$%.2f${RESET}" "$_cost")")',
            'fi',
            '',
        ]

    elif seg == 'mode':
        pc = cv(sc.get('plan_color',   'cyan'))
        ac = cv(sc.get('auto_color',   'yellow'))
        nc = cv(sc.get('normal_color', 'dim'))
        lines += [
            '# mode',
            '_mode=$(echo "$input" | jq -r \'.mode // empty\')',
            'if [ -n "$_mode" ]; then',
            '  case "$_mode" in',
            f'    plan) _modec="${{{pc}}}" ;;',
            f'    auto) _modec="${{{ac}}}" ;;',
            f'    *)    _modec="${{{nc}}}" ;;',
            '  esac',
            '  parts_out+=("$(printf "$_modec %s${{RESET}}" "$_mode")")',
            'fi',
            '',
        ]

lines += [
    'printf "%b" "$(IFS=\' \'; echo "${parts_out[*]}")"',
    'printf "\\n"',
]

with open(out_path, 'w') as f:
    f.write('\n'.join(lines) + '\n')
PYEOF
}

# ── cmd_status ────────────────────────────────────────────────────────────────
cmd_status() {
  header "Statusline Configuration"
  if [ ! -f "$CONFIG_PATH" ]; then
    warn "No config found at $CONFIG_PATH — run ./statusline-customize.sh to create one"
    return 0
  fi
  local segs
  segs=$(python3 -c "import json; c=json.load(open('$CONFIG_PATH')); print(', '.join(c['segments']))")
  success "Active segments: $segs"
  info "Config: $CONFIG_PATH"
  info "Output: $OUTPUT_PATH"
}

# ── tui_stage1_toggle ─────────────────────────────────────────────────────────
tui_stage1_toggle() {
  local config="$1"
  local all_segs="path git vim_mode model ctx 5h_pct 5h_tokens weekly reset_5h reset_weekly cost mode"
  local enabled
  enabled=$(python3 -c "import json; c=json.load(open('$config')); print('\n'.join(c['segments']))")

  local choices=""
  for seg in $all_segs; do
    if echo "$enabled" | grep -qx "$seg"; then
      choices+="[on]  $seg\n"
    else
      choices+="[off] $seg\n"
    fi
  done

  local selected
  selected=$(printf "%b" "$choices" | fzf --multi \
    --header="Space=toggle  Enter=confirm  Esc=keep current" \
    --prompt="Segments > " \
    --bind="tab:toggle") || { info "Segment selection cancelled — keeping current"; return 1; }

  if [ -z "$selected" ]; then
    info "No segments selected — keeping current"
    return 1
  fi

  # Extract names from selections
  local new_segs=()
  while IFS= read -r line; do
    local name="${line#\[on\]  }"
    name="${name#\[off\] }"
    name="${name## }"
    new_segs+=("$name")
  done <<< "$selected"

  # Reorder loop — pick next segment in desired order
  local ordered=()
  local remaining=("${new_segs[@]}")
  local total="${#remaining[@]}"
  local i=1
  while [ "${#remaining[@]}" -gt 0 ]; do
    local pick
    pick=$(printf '%s\n' "${remaining[@]}" | fzf \
      --header="Pick segment $i of $total (in display order)" \
      --prompt="Order > ") || { info "Reorder cancelled — using toggle order"; ordered=("${new_segs[@]}"); break; }
    ordered+=("$pick")
    # Remove picked item from remaining
    local new_remaining=()
    for s in "${remaining[@]}"; do
      [ "$s" != "$pick" ] && new_remaining+=("$s")
    done
    remaining=("${new_remaining[@]}")
    (( i++ )) || true
  done

  # Update segments array in config
  python3 - "$config" "${ordered[@]}" << 'PYEOF'
import json, sys
cfg_path = sys.argv[1]
new_segs = sys.argv[2:]
with open(cfg_path) as f:
    cfg = json.load(f)
cfg["segments"] = new_segs
with open(cfg_path, 'w') as f:
    json.dump(cfg, f, indent=2)
PYEOF
}

# ── tui_stage2_config ─────────────────────────────────────────────────────────
tui_stage2_config() {
  local config="$1"
  local palette_names="fg accent cyan yellow dim red lavender"
  local preset_thresholds="10 15 20 25 30 50 80"

  local segments
  segments=$(python3 -c "import json; c=json.load(open('$config')); print('\n'.join(c['segments']))")

  while IFS= read -r seg; do
    local options=()
    case "$seg" in
      path)     options=("max_depth" "color") ;;
      git)      options=("show_changes" "color") ;;
      vim_mode) options=("insert_color" "normal_color") ;;
      model)    options=("color") ;;
      ctx)      options=("warn_threshold" "color" "warn_color") ;;
      5h_pct)   options=("warn_threshold" "color" "warn_color") ;;
      5h_tokens) options=("warn_threshold" "color" "warn_color") ;;
      weekly)   options=("warn_threshold" "color" "warn_color") ;;
      reset_5h|reset_weekly) options=("color") ;;
      cost)     options=("warn_threshold" "color" "warn_color") ;;
      mode)     options=("plan_color" "auto_color" "normal_color") ;;
    esac

    # Inner loop: keep showing option menu until user presses Escape
    while true; do
      # Build option menu with current values
      local menu=""
      for opt in "${options[@]}"; do
        local cur
        cur=$(python3 -c "import json; c=json.load(open('$config')); print(c.get('segment_config',{}).get('$seg',{}).get('$opt','—'))" 2>/dev/null || echo "—")
        menu+="$opt    [current: $cur]\n"
      done

      local chosen_opt
      chosen_opt=$(printf "%b" "$menu" | fzf \
        --header="Configure: $seg  (Esc=done with this segment)" \
        --prompt="Option > ") || break  # Escape exits inner loop, moves to next segment

      local opt_name="${chosen_opt%%    *}"

      # Pick new value
      local new_val
      case "$opt_name" in
        *color*)
          new_val=$(printf '%s\n' $palette_names | fzf \
            --header="Pick color for $seg.$opt_name" \
            --prompt="Color > ") || continue
          ;;
        warn_threshold|max_depth)
          new_val=$(printf '%s\n' $preset_thresholds | fzf \
            --print-query \
            --header="Pick threshold (or type custom value)" \
            --prompt="Value > " | tail -1) || continue
          ;;
        show_changes)
          new_val=$(printf 'true\nfalse\n' | fzf \
            --header="Show change count?" \
            --prompt="> ") || continue
          ;;
      esac

      # Write new value to config
      python3 - "$config" "$seg" "$opt_name" "$new_val" << 'PYEOF'
import json, sys
cfg_path, seg, opt, val = sys.argv[1], sys.argv[2], sys.argv[3], sys.argv[4]
with open(cfg_path) as f:
    cfg = json.load(f)
if "segment_config" not in cfg:
    cfg["segment_config"] = {}
if seg not in cfg["segment_config"]:
    cfg["segment_config"][seg] = {}
# Type coercion
if val in ("true", "false"):
    val = val == "true"
elif val.lstrip('-').isdigit():
    val = int(val)
elif '.' in val:
    try:
        val = float(val)
    except ValueError:
        pass
cfg["segment_config"][seg][opt] = val
with open(cfg_path, 'w') as f:
    json.dump(cfg, f, indent=2)
PYEOF
      info "$seg.$opt_name → $new_val"
    done  # end inner while loop for this segment
  done <<< "$segments"
}

# ── tui_stage3_preview ────────────────────────────────────────────────────────
tui_stage3_preview() {
  local config="$1"
  local tmp_script
  tmp_script=$(mktemp /tmp/statusline-preview-XXXXXX.sh)
  trap 'rm -f "$tmp_script"' RETURN

  generate_statusline "$config" "$tmp_script"

  local mock_json='{"workspace":{"current_dir":"/Users/demo/code/dotfiles"},"model":{"display_name":"claude-sonnet-4-6"},"context_window":{"remaining_percentage":84},"rate_limits":{"five_hour":{"used_percentage":42,"tokens_used":12000,"tokens_limit":40000}},"vim":{"mode":"INSERT"},"mode":"normal"}'
  echo ""
  header "Preview"
  echo "$mock_json" | bash "$tmp_script" || warn "Preview render failed"
  echo ""

  local confirm
  confirm=$(printf 'Apply\nCancel\n' | fzf \
    --header="Apply this configuration?" \
    --prompt="> ") || return 1

  [ "$confirm" = "Apply" ]
}

# ── main ──────────────────────────────────────────────────────────────────────
main() {
  command -v fzf >/dev/null 2>&1 || { error "fzf not found — install with: brew install fzf"; exit 1; }

  ensure_config "$CONFIG_PATH" "$SKELETON_PATH"

  header "Statusline Customizer"
  info "Config: $CONFIG_PATH"

  # Stage 1: toggle + reorder
  echo ""
  info "Stage 1: Toggle and order segments"
  tui_stage1_toggle "$CONFIG_PATH" || true

  # Stage 2: per-segment config
  echo ""
  info "Stage 2: Configure each segment"
  tui_stage2_config "$CONFIG_PATH"

  # Stage 3: preview + apply
  if tui_stage3_preview "$CONFIG_PATH"; then
    mkdir -p "$(dirname "$OUTPUT_PATH")"
    generate_statusline "$CONFIG_PATH" "$OUTPUT_PATH"
    success "Written to $OUTPUT_PATH"
    success "Done. Status line updated — takes effect immediately."
  else
    info "Cancelled — no changes applied."
    info "Config edits saved to $CONFIG_PATH (run again to apply)"
  fi
}

# ── Source-only guard (place after ALL function definitions) ──────────────────
[ "${STATUSLINE_CUSTOMIZE_SOURCE_ONLY:-}" = "1" ] && return 0

# ── Dispatch ──────────────────────────────────────────────────────────────────
if [ $# -gt 1 ]; then
  echo "Usage: statusline-customize.sh [--generate|--status]" >&2; exit 1
fi
case "${1:-}" in
  --status)   cmd_status; exit 0 ;;
  --generate)
    ensure_config "$CONFIG_PATH" "$SKELETON_PATH"
    mkdir -p "$(dirname "$OUTPUT_PATH")"
    generate_statusline "$CONFIG_PATH" "$OUTPUT_PATH"
    success "Generated $OUTPUT_PATH"
    ;;
  "") main ;;
  *)  echo "Usage: statusline-customize.sh [--generate|--status]" >&2; exit 1 ;;
esac
```

- [ ] **Step 2: Make executable**

```bash
chmod +x statusline-customize.sh
```

- [ ] **Step 3: Run all tests — all should pass**

```bash
bash test-statusline-customize.sh
```

Expected output:
```
── Syntax
  ✓ bash -n statusline-customize.sh
  ✓ statusline-skeleton-config.json valid JSON

── Assembler
  ✓ assembler: skeleton config produces valid bash
  ✓ assembler: warn_threshold 20 baked into output
  ✓ assembler: model appears before path when ordered [model, path]
  ✓ assembler: git absent when not in segments

── Preview smoke test
  ✓ preview: skeleton config renders without error

── First-run skeleton copy
  ✓ first-run: config created from skeleton
  ✓ first-run: existing config not overwritten

── Arg parsing
  ✓ --status exits 0
  ✓ --generate exits 0
  ✓ --badflag exits non-zero

────────────────────────────────
  passed: 13  failed: 0
────────────────────────────────
```

If tests fail, the most common issues are:
- **`generate_statusline` segment ordering:** the python3 f-string `f"${{{cv}}}"` must produce `${C_FOO}` — verify the `cv()` function returns `C_NAME` and the f-string wraps it in `${...}`
- **`ensure_config` test fails:** check the function signature matches `ensure_config CONFIG_PATH SKELETON_PATH` (two args, not using global vars)
- **bash -n fails on generated output:** check the vim_mode block — the `if/else` on one line may need semicolons fixed

- [ ] **Step 4: Smoke test `--generate` manually**

```bash
./statusline-customize.sh --generate
cat ~/.claude/statusline-command.sh | head -20
```

Expected: generated script with shebang, color vars, and segment blocks.

- [ ] **Step 5: Smoke test `--status`**

```bash
./statusline-customize.sh --status
```

Expected: prints active segments from skeleton config (path, git, ctx, 5h_pct, model).

- [ ] **Step 6: Commit**

```bash
git add statusline-customize.sh
git commit -m "feat: add statusline-customize.sh with fzf TUI and code assembler"
```

---

## Task 4: Wire `test.sh`

**Files:**
- Modify: `test.sh:184` — add syntax check
- Modify: `test.sh:262` — add test section

- [ ] **Step 1: Add syntax check to `test.sh`**

Find (around line 184):
```bash
syntax_check powershell-config.sh
```

Add immediately after:
```bash
syntax_check statusline-customize.sh
```

- [ ] **Step 2: Add Statusline Customize test section to `test.sh`**

Find (around line 262, the last test section before the summary):
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

Add immediately after:
```bash
# ════════════════════════════════════════════════
section "Statusline Customize — test-statusline-customize.sh"
# ════════════════════════════════════════════════

if bash "$SCRIPT_DIR/test-statusline-customize.sh" >/dev/null 2>&1; then
  pass "test-statusline-customize.sh passed"
else
  fail "test-statusline-customize.sh — one or more checks failed (run ./test-statusline-customize.sh for details)"
fi
```

- [ ] **Step 3: Run `test.sh` to confirm no regressions**

```bash
bash test.sh 2>/dev/null | grep -E "statusline|Statusline"
```

Expected: both lines pass.

- [ ] **Step 4: Commit**

```bash
git add test.sh
git commit -m "chore: wire statusline-customize.sh into test.sh"
```
