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
