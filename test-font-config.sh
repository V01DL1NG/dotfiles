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

# ── detect_terminal_font_status — iTerm2 (macOS only) ────────────────────────
section "detect_terminal_font_status — iTerm2"

if [ "$(uname -s)" != "Darwin" ]; then
  echo "  ! iTerm2 tests skipped (macOS only)"
else
  FONT_CONFIG_SOURCE_ONLY=1 . "$SCRIPT_DIR/font-config.sh"

  ITERM_MOCK_DIR="$TMPDIR_TEST/DynamicProfiles"
  mkdir -p "$ITERM_MOCK_DIR"

  # iTerm2: profile with "Normal Font" containing FiraCode → installed_configured
  printf '{"Profiles": [{"Normal Font": "FiraCodeNFM-Reg 13", "Name": "Velvet"}]}\n' \
    > "$ITERM_MOCK_DIR/velvet.json"
  status="$(detect_terminal_font_status iterm2 "$ITERM_MOCK_DIR")"
  [ "$status" = "installed_configured" ] \
    && pass "iterm2: profile with FiraCode Normal Font → installed_configured" \
    || fail "iterm2: profile with FiraCode Normal Font → got '$status'"

  # iTerm2: profile without "Normal Font" key → installed_not_configured
  rm "$ITERM_MOCK_DIR/velvet.json"
  printf '{"Profiles": [{"Name": "Plain"}]}\n' \
    > "$ITERM_MOCK_DIR/plain.json"
  status="$(detect_terminal_font_status iterm2 "$ITERM_MOCK_DIR")"
  [ "$status" = "installed_not_configured" ] \
    && pass "iterm2: profile without FiraCode → installed_not_configured" \
    || fail "iterm2: profile without FiraCode → got '$status'"

  # iTerm2: empty DynamicProfiles dir → installed_not_configured
  rm -f "$ITERM_MOCK_DIR"/*.json
  status="$(detect_terminal_font_status iterm2 "$ITERM_MOCK_DIR")"
  [ "$status" = "installed_not_configured" ] \
    && pass "iterm2: empty DynamicProfiles → installed_not_configured" \
    || fail "iterm2: empty DynamicProfiles → got '$status'"
fi

# ── Arg parsing ───────────────────────────────────────────────────────────────
section "Arg parsing"

# --status exits 0
bash "$SCRIPT_DIR/font-config.sh" --status </dev/null >/dev/null 2>&1 \
  && pass "--status exits 0" \
  || fail "--status exits non-zero"

# --dry-run exits 0
bash "$SCRIPT_DIR/font-config.sh" --dry-run </dev/null >/dev/null 2>&1 \
  && pass "--dry-run exits 0" \
  || fail "--dry-run exits non-zero"

# unknown flag exits non-zero
bash "$SCRIPT_DIR/font-config.sh" --badflag </dev/null >/dev/null 2>&1 \
  && fail "--badflag should exit non-zero" \
  || pass "--badflag exits non-zero"

# ── Summary ───────────────────────────────────────────────────────────────────
echo ""
echo "────────────────────────────────"
printf "  passed: %d  failed: %d\n" "$PASS" "$FAIL"
echo "────────────────────────────────"
[ "$FAIL" -eq 0 ]
