#!/usr/bin/env bash
# test-font-config.sh — test suite for font-config.sh

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PASS=0; FAIL=0

pass() { echo "  ✓ $1"; PASS=$((PASS + 1)); }
fail() { echo "  ✗ $1"; FAIL=$((FAIL + 1)); }
section() { echo ""; echo "── $1"; }

# ── Syntax ────────────────────────────────────────────────────────────────────
section "Syntax"

if bash -n "$SCRIPT_DIR/font-config.sh" 2>/dev/null; then
  pass "bash -n font-config.sh"
else
  fail "bash -n font-config.sh — syntax error"
fi

# ── detect_terminal_font_status — Ghostty + Kitty ────────────────────────────
section "detect_terminal_font_status — Ghostty + Kitty"

FONT_CONFIG_SOURCE_ONLY=1 . "$SCRIPT_DIR/font-config.sh"

TMPDIR_TEST="$(mktemp -d)"
trap 'rm -rf "$TMPDIR_TEST"' EXIT

# Ghostty: override points to absent file → installed_not_configured
status="$(detect_terminal_font_status ghostty "$TMPDIR_TEST/no-such-file")"
[ "$status" = "installed_not_configured" ] \
  && pass "ghostty: absent config → installed_not_configured" \
  || fail "ghostty: absent config → got '$status'"

# Ghostty: config without font line → installed_not_configured
printf 'theme = dark\n' > "$TMPDIR_TEST/ghostty-no-font.conf"
status="$(detect_terminal_font_status ghostty "$TMPDIR_TEST/ghostty-no-font.conf")"
[ "$status" = "installed_not_configured" ] \
  && pass "ghostty: no font line → installed_not_configured" \
  || fail "ghostty: no font line → got '$status'"

# Ghostty: config with correct font line → installed_configured
printf 'font-family = FiraCode Nerd Font\nfont-size = 13\n' > "$TMPDIR_TEST/ghostty-ok.conf"
status="$(detect_terminal_font_status ghostty "$TMPDIR_TEST/ghostty-ok.conf")"
[ "$status" = "installed_configured" ] \
  && pass "ghostty: correct font → installed_configured" \
  || fail "ghostty: correct font → got '$status'"

# Kitty: config with correct font line → installed_configured
printf 'font_family      FiraCode Nerd Font\nfont_size 13.0\n' > "$TMPDIR_TEST/kitty-ok.conf"
status="$(detect_terminal_font_status kitty "$TMPDIR_TEST/kitty-ok.conf")"
[ "$status" = "installed_configured" ] \
  && pass "kitty: correct font → installed_configured" \
  || fail "kitty: correct font → got '$status'"

# Kitty: config without font line → installed_not_configured
printf 'font_size 13.0\n' > "$TMPDIR_TEST/kitty-no-font.conf"
status="$(detect_terminal_font_status kitty "$TMPDIR_TEST/kitty-no-font.conf")"
[ "$status" = "installed_not_configured" ] \
  && pass "kitty: no font line → installed_not_configured" \
  || fail "kitty: no font line → got '$status'"

# ── detect_terminal_font_status — VS Code ────────────────────────────────────
section "detect_terminal_font_status — VS Code"

# VS Code: override points to absent file → installed_not_configured
status="$(detect_terminal_font_status vscode "$TMPDIR_TEST/no-settings.json")"
[ "$status" = "installed_not_configured" ] \
  && pass "vscode: absent settings.json → installed_not_configured" \
  || fail "vscode: absent settings.json → got '$status'"

# VS Code: settings.json without font key → installed_not_configured
printf '{\n    "editor.fontSize": 14\n}\n' > "$TMPDIR_TEST/vscode-no-font.json"
status="$(detect_terminal_font_status vscode "$TMPDIR_TEST/vscode-no-font.json")"
[ "$status" = "installed_not_configured" ] \
  && pass "vscode: settings without font key → installed_not_configured" \
  || fail "vscode: settings without font key → got '$status'"

# VS Code: settings.json with font key set to FiraCode → installed_configured
printf '{\n    "terminal.integrated.fontFamily": "FiraCode Nerd Font"\n}\n' \
  > "$TMPDIR_TEST/vscode-ok.json"
status="$(detect_terminal_font_status vscode "$TMPDIR_TEST/vscode-ok.json")"
[ "$status" = "installed_configured" ] \
  && pass "vscode: fontFamily = FiraCode → installed_configured" \
  || fail "vscode: fontFamily = FiraCode → got '$status'"

# ── Summary ───────────────────────────────────────────────────────────────────
echo ""
echo "────────────────────────────────"
printf "  passed: %d  failed: %d\n" "$PASS" "$FAIL"
echo "────────────────────────────────"
[ "$FAIL" -eq 0 ]
