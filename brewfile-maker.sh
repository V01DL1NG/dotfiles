#!/usr/bin/env bash
# ============================================================================
# brewfile-maker.sh — Interactive curated Brewfile builder
#
# Parses the master Brewfile, lets you pick exactly what you want via fzf
# multi-select, and writes a named Brewfile preset to Brewfile.d/<name>.
#
# Usage:
#   ./brewfile-maker.sh                    interactive — pick name + packages
#   ./brewfile-maker.sh <name>             start with a blank slate, save as <name>
#   ./brewfile-maker.sh <name> --from <preset>  start pre-checked from a preset
#   ./brewfile-maker.sh --list             list saved presets
#   ./brewfile-maker.sh --install <name>   run brew bundle for a preset
#   ./brewfile-maker.sh --show <name>      print a preset's contents
#   ./brewfile-maker.sh --diff <a> <b>     diff two presets
#
# Presets are stored as Brewfile.d/<name> — tracked in git.
# The master Brewfile stays untouched (full catalog / personal machine dump).
# ============================================================================
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
MASTER="$SCRIPT_DIR/Brewfile"
PRESET_DIR="$SCRIPT_DIR/Brewfile.d"

# ── Colors ────────────────────────────────────────────────────────────────────
BOLD='\033[1m'
DIM='\033[2m'
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

# ── Require fzf ───────────────────────────────────────────────────────────────
if ! command -v fzf >/dev/null 2>&1; then
  echo "fzf is required for interactive mode. Install: brew install fzf" >&2
  exit 1
fi

mkdir -p "$PRESET_DIR"

# ── Parse master Brewfile into categorised display lines ─────────────────────
#
# Each line fed to fzf has the form:
#   [TYPE] entry  |  description
#
# We auto-categorise based on known keywords so the list is scannable.

categorise() {
  local type="$1" entry="$2"

  case "$type" in
    tap)
      echo "tap"
      return
      ;;
    brew)
      case "$entry" in
        bat|eza|fd|fzf|btop|lazygit|zoxide|atuin|direnv|git-delta|neofetch|xplr|nushell)
          echo "terminal" ;;
        git|git-gui|gh|hub|git-lfs)
          echo "git" ;;
        neovim|lua-language-server|tree-sitter)
          echo "editor" ;;
        tmux|nowplaying-cli|pam-reattach)
          echo "tmux" ;;
        oh-my-posh|starship|powerlevel10k)
          echo "prompt" ;;
        ollama|gemini-cli)
          echo "ai" ;;
        gnupg|pam-reattach|socat|telnet|dockutil)
          echo "system" ;;
        nmap|masscan|gobuster|hydra|john-jumbo|katana|sherlock|shodan|theharvester|falco|ghidra)
          echo "security" ;;
        azure-cli|docker-compose|dry|exiftool)
          echo "devops" ;;
        *)
          echo "other" ;;
      esac
      ;;
    cask)
      case "$entry" in
        iterm2|kitty|ghostty|warp|wezterm|alacritty)
          echo "terminal-app" ;;
        visual-studio-code|neovide|zed|cursor)
          echo "editor-app" ;;
        docker-desktop|postman|github|android-studio|temurin)
          echo "dev-app" ;;
        brave-browser|firefox|google-chrome|arc)
          echo "browser" ;;
        notion|obsidian|rectangle|keka|karabiner-elements|suspicious-package|teamviewer)
          echo "utility" ;;
        caido|wireshark-app|maltego|powershell)
          echo "security-app" ;;
        claude|claude-code)
          echo "ai-app" ;;
        *)
          echo "other-app" ;;
      esac
      ;;
    vscode)
      case "$entry" in
        ms-python.*|ms-toolsai.*) echo "vscode-python" ;;
        ms-vscode.cpp*|ms-vscode.cmake*) echo "vscode-cpp" ;;
        vscjava.*|oracle.*|redhat.java) echo "vscode-java" ;;
        github.*) echo "vscode-github" ;;
        anthropic.*) echo "vscode-ai" ;;
        dracula*|pkief.*|josemurilloc.*|github.github*) echo "vscode-theme" ;;
        *shellcheck*|*shell-format*|foxundermoon.*) echo "vscode-shell" ;;
        *) echo "vscode-other" ;;
      esac
      ;;
    *)
      echo "other"
      ;;
  esac
}

# Build fzf input: "CATEGORY | TYPE entry"
build_fzf_input() {
  local precheck_file="${1:-}"

  while IFS= read -r line; do
    # Skip blank lines and comments
    [[ -z "$line" || "$line" == \#* ]] && continue

    local type entry
    type="${line%% *}"
    entry="${line#* }"
    entry="${entry//\"/}"  # strip quotes
    entry="${entry%% *}"    # strip trailing options

    local cat
    cat="$(categorise "$type" "$entry")"

    # Prefix with marker if this entry is in the precheck file
    local marker="  "
    if [ -n "$precheck_file" ] && grep -qF "\"$entry\"" "$precheck_file" 2>/dev/null; then
      marker="*>"
    fi

    printf '%s [%-14s] %s %s\n' "$marker" "$cat" "$type" "$entry"
  done < "$MASTER"
}

# ── Interactive picker ────────────────────────────────────────────────────────
run_picker() {
  local precheck_file="${1:-}"

  build_fzf_input "$precheck_file" | fzf \
    --multi \
    --prompt="  Pick packages (Tab=toggle, Enter=confirm): " \
    --header="$(printf '%s\n%s' \
      "  Space/Tab: select │ Enter: confirm │ Ctrl-A: all │ Ctrl-D: none" \
      "  *> = already in preset │ sorted by category")" \
    --height=90% \
    --layout=reverse \
    --border=rounded \
    --color="bg+:#341948,bg:#0E050F,spinner:#69307A,hl:#EFDCF9" \
    --color="fg:#EFDCF9,header:#4c1f5e,info:#69307A,pointer:#EFDCF9" \
    --color="marker:#69307A,fg+:#EFDCF9,prompt:#69307A,hl+:#EFDCF9" \
    --bind "ctrl-a:select-all,ctrl-d:deselect-all" \
    --sort \
    | sed 's/^[* >]*//' \
    | awk '{print $2, $3}'  # type entry
}

# ── Write a Brewfile from selected lines ─────────────────────────────────────
write_preset() {
  local name="$1" selected="$2"
  local out="$PRESET_DIR/$name"

  {
    printf '# Brewfile preset: %s\n' "$name"
    printf '# Generated by brewfile-maker.sh — %s\n' "$(date +%Y-%m-%d)"
    printf '# Install: brew bundle install --file=Brewfile.d/%s\n\n' "$name"

    # Group by type, preserving relative order
    local last_type=""
    while IFS= read -r line; do
      [[ -z "$line" ]] && continue
      local type entry
      type="${line%% *}"
      entry="${line#* }"

      if [ "$type" != "$last_type" ]; then
        [ -n "$last_type" ] && printf '\n'
        printf '# %s\n' "$type"
        last_type="$type"
      fi

      # Carry over any tap declarations for selected brews
      if [ "$type" = "tap" ]; then
        printf 'tap "%s"\n' "$entry"
      else
        printf '%s "%s"\n' "$type" "$entry"
      fi
    done <<< "$selected"
  } > "$out"

  echo "$out"
}

# ── Sub-commands ──────────────────────────────────────────────────────────────

cmd_list() {
  header "Saved presets (Brewfile.d/)"
  echo ""
  if [ -z "$(ls -A "$PRESET_DIR" 2>/dev/null)" ]; then
    info "No presets yet. Run ./brewfile-maker.sh to create one."
    return
  fi
  for f in "$PRESET_DIR"/*; do
    local name; name="$(basename "$f")"
    local count; count="$(grep -c '^brew\|^cask\|^vscode' "$f" 2>/dev/null || echo 0)"
    local desc; desc="$(grep '^# Generated' "$f" 2>/dev/null | sed 's/# Generated by.*//' || true)"
    printf "  ${BOLD}${LAVENDER}%-20s${RESET}  ${DIM}%3d packages${RESET}\n" "$name" "$count"
  done
  echo ""
}

cmd_show() {
  local name="${1:?show requires a preset name}"
  local f="$PRESET_DIR/$name"
  [ -f "$f" ] || { error "Preset not found: $f"; exit 1; }
  if command -v bat >/dev/null 2>&1; then
    bat --language=ruby --style=numbers "$f"
  else
    cat "$f"
  fi
}

cmd_install() {
  local name="${1:?install requires a preset name}"
  local f="$PRESET_DIR/$name"
  [ -f "$f" ] || { error "Preset not found: $f"; exit 1; }
  header "Installing preset: $name"
  brew bundle install --file="$f"
  success "Done"
}

cmd_diff() {
  local a="${1:?diff requires two preset names}" b="${2:?diff requires two preset names}"
  local fa="$PRESET_DIR/$a" fb="$PRESET_DIR/$b"
  [ -f "$fa" ] || { error "Preset not found: $fa"; exit 1; }
  [ -f "$fb" ] || { error "Preset not found: $fb"; exit 1; }
  diff --color=always -u "$fa" "$fb" | less -R
}

cmd_make() {
  local name="${1:-}"
  local from_preset="${2:-}"

  # Prompt for name if not given
  if [ -z "$name" ]; then
    echo ""
    read -r -p "  Preset name (e.g. core, dev, work): " name
    name="${name// /-}"  # spaces → hyphens
  fi

  if [ -z "$name" ]; then
    error "Preset name is required"
    exit 1
  fi

  local precheck_file=""
  if [ -n "$from_preset" ]; then
    precheck_file="$PRESET_DIR/$from_preset"
    [ -f "$precheck_file" ] || { error "Source preset not found: $precheck_file"; exit 1; }
    info "Starting from preset: $from_preset (pre-checked entries marked *>)"
  elif [ -f "$PRESET_DIR/$name" ]; then
    precheck_file="$PRESET_DIR/$name"
    info "Editing existing preset: $name (current entries marked *>)"
  fi

  echo ""
  info "Opening package picker..."
  echo ""

  # Run picker
  local selected
  selected="$(run_picker "$precheck_file")" || {
    warn "Nothing selected or picker cancelled."
    exit 0
  }

  if [ -z "$selected" ]; then
    warn "No packages selected — preset not written."
    exit 0
  fi

  local count; count="$(echo "$selected" | grep -c 'brew\|cask\|vscode' || true)"
  local out
  out="$(write_preset "$name" "$selected")"

  echo ""
  success "Preset saved: $out  (${count} packages)"
  echo ""
  info "To install:"
  info "  brew bundle install --file=Brewfile.d/$name"
  info ""
  info "To share: send Brewfile.d/$name — it's a plain Brewfile."
}

# ── Dispatch ──────────────────────────────────────────────────────────────────
case "${1:-}" in
  --list|-l)       cmd_list ;;
  --show)          cmd_show "${2:-}" ;;
  --install)       cmd_install "${2:-}" ;;
  --diff)          cmd_diff "${2:-}" "${3:-}" ;;
  --help|-h)
    echo ""
    echo -e "${BOLD}${PURPLE}brewfile-maker.sh${RESET} — curated Brewfile builder"
    echo ""
    echo "  ./brewfile-maker.sh                    interactive builder"
    echo "  ./brewfile-maker.sh <name>             create/edit named preset"
    echo "  ./brewfile-maker.sh <name> --from <p>  start pre-checked from preset"
    echo "  ./brewfile-maker.sh --list             list saved presets"
    echo "  ./brewfile-maker.sh --show <name>      print preset contents"
    echo "  ./brewfile-maker.sh --install <name>   brew bundle install a preset"
    echo "  ./brewfile-maker.sh --diff <a> <b>     diff two presets"
    echo ""
    echo "  Presets are saved to Brewfile.d/<name> and tracked in git."
    echo "  The master Brewfile is never modified."
    echo ""
    ;;
  *)
    # Positional: name [--from preset]
    NAME="${1:-}"
    FROM=""
    shift || true
    while [ $# -gt 0 ]; do
      case "$1" in
        --from) FROM="${2:?--from requires a preset name}"; shift 2 ;;
        *) error "Unknown option: $1"; exit 1 ;;
      esac
    done
    cmd_make "$NAME" "$FROM"
    ;;
esac
