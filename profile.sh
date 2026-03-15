#!/usr/bin/env bash
# ============================================================================
# profile.sh — profile container manager
#
# Commands:
#   export [--name NAME] [--desc DESC] [-o FILE]  snapshot live configs
#   pack   <profile-name> [--name NAME] [-o FILE] pack a profiles/ dir
#   import <container.sh>                         install a container
#   info   <container.sh>                         show container metadata
#   list                                          list built-in profiles
#
# Container format:
#   A self-contained .profile.sh script with base64-embedded files.
#   Recipients can install with: bash the-file.profile.sh
#   No dependency on this repo needed to install.
# ============================================================================
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROFILES_DIR="$SCRIPT_DIR/profiles"

# ── Colors ───────────────────────────────────────────────────────────────────
BOLD='\033[1m'; DIM='\033[2m'
PURPLE='\033[38;2;105;48;122m'; LAVENDER='\033[38;2;239;220;249m'
GREEN='\033[0;32m'; YELLOW='\033[0;33m'; RED='\033[0;31m'; RESET='\033[0m'

info()    { echo -e "  ${LAVENDER}${1}${RESET}"; }
success() { echo -e "  ${GREEN}✓${RESET}  ${1}"; }
warn()    { echo -e "  ${YELLOW}!${RESET}  ${1}"; }
error()   { echo -e "  ${RED}✗${RESET}  ${1}" >&2; }
header()  { echo -e "\n${BOLD}${PURPLE}${1}${RESET}"; }

usage() {
  echo ""
  echo -e "${BOLD}profile.sh${RESET} — profile container manager"
  echo ""
  echo "  Commands:"
  printf "    %-45s %s\n" "export [--name NAME] [--desc DESC] [-o FILE]" "snapshot live ~/.zshrc + theme files"
  printf "    %-45s %s\n" "pack <profile-name> [--name NAME] [-o FILE]"  "pack a profiles/ dir into a container"
  printf "    %-45s %s\n" "import <container.sh>"                         "install a container (copies files locally)"
  printf "    %-45s %s\n" "info <container.sh>"                           "show container metadata without installing"
  printf "    %-45s %s\n" "list"                                          "list built-in profiles"
  echo ""
  echo "  Examples:"
  echo "    ./profile.sh export --name 'My Setup' -o my-setup.profile.sh"
  echo "    ./profile.sh pack p10k-velvet -o velvet.profile.sh"
  echo "    ./profile.sh import velvet.profile.sh"
  echo "    ./profile.sh info velvet.profile.sh"
  echo ""
}

# ── Helpers ───────────────────────────────────────────────────────────────────

# Detect prompt engine from a zshrc file
detect_engine() {
  local zshrc="$1"
  if grep -q 'powerlevel10k' "$zshrc" 2>/dev/null; then
    echo "powerlevel10k"
  elif grep -q 'oh-my-posh' "$zshrc" 2>/dev/null; then
    echo "oh-my-posh"
  else
    echo "unknown"
  fi
}

# Encode a file as single-line base64
b64_file() {
  base64 < "$1" | tr -d '\n'
}

# Slugify a string for use as a filename
slugify() {
  echo "$1" \
    | tr '[:upper:]' '[:lower:]' \
    | sed 's/[^a-z0-9]/-/g' \
    | sed 's/--*/-/g' \
    | sed 's/^-//; s/-$//'
}

# ── Container generator ───────────────────────────────────────────────────────
# Writes a self-contained, self-installing container script to $output.
# file_entries[] format: "destination_shell_expression|base64content"
# e.g.: '$HOME/.zshrc|dGVzdA=='
generate_container() {
  local name="$1"
  local desc="$2"
  local base="$3"
  local tools="$4"
  local output="$5"
  shift 5
  # Remaining args are file entries (may be zero)
  local -a file_entries=()
  while [[ $# -gt 0 ]]; do
    file_entries+=("$1")
    shift
  done

  local created
  created="$(date +%Y-%m-%d)"

  # Write the container file
  {
    # ── Shebang + header comment ─────────────────────────────────────────────
    printf '#!/usr/bin/env bash\n'
    printf '# ┌───────────────────────────────────────────────────────────────────────┐\n'
    printf '# │  Profile Container                                                    │\n'
    printf '# └───────────────────────────────────────────────────────────────────────┘\n'
    printf '# Name:     %s\n' "$name"
    printf '# Desc:     %s\n' "$desc"
    printf '# Base:     %s\n' "$base"
    printf '# Created:  %s\n' "$created"
    printf '# Tools:    %s\n' "$tools"
    printf '#\n'
    printf '# Usage:\n'
    printf '#   bash %s              — install (copies files locally, no symlinks)\n' "$(basename "$output")"
    printf '#   bash %s --info      — show metadata without installing\n' "$(basename "$output")"
    printf '\n'

    # ── Metadata variables ───────────────────────────────────────────────────
    printf '_PROFILE_NAME=%s\n' "$(printf '%q' "$name")"
    printf '_PROFILE_DESC=%s\n' "$(printf '%q' "$desc")"
    printf '_PROFILE_BASE=%s\n' "$(printf '%q' "$base")"
    printf '_PROFILE_CREATED=%s\n' "$(printf '%q' "$created")"
    printf '_PROFILE_TOOLS=%s\n' "$(printf '%q' "$tools")"
    printf '\n'

    # ── Embedded files ───────────────────────────────────────────────────────
    printf '# Files: destination (shell expression)|base64-encoded content\n'
    printf '_FILES=(\n'
    for entry in ${file_entries[@]+"${file_entries[@]}"}; do
      # Wrap in single quotes; base64 chars are safe (A-Za-z0-9+/=), no escaping needed
      printf "  '%s'\n" "$entry"
    done
    printf ')\n'
    printf '\n'

    # ── Embedded install logic ───────────────────────────────────────────────
    # Single-quoted heredoc — nothing inside is expanded at generation time.
    cat <<'____INSTALL_LOGIC'
set -euo pipefail

BOLD='\033[1m'; GREEN='\033[0;32m'; YELLOW='\033[0;33m'; RED='\033[0;31m'
LAVENDER='\033[38;2;239;220;249m'; RESET='\033[0m'
_info()    { echo -e "  ${LAVENDER}${1}${RESET}"; }
_success() { echo -e "  ${GREEN}✓${RESET}  ${1}"; }
_warn()    { echo -e "  ${YELLOW}!${RESET}  ${1}"; }
_error()   { echo -e "  ${RED}✗${RESET}  ${1}" >&2; }

# base64 decode — handles macOS (BSD) and Linux (GNU)
_b64d() {
  case "$(uname -s)" in
    Darwin) base64 -D ;;
    *)      base64 -d ;;
  esac
}

_show_info() {
  echo ""
  echo -e "${BOLD}Profile Container${RESET}"
  echo "  Name:    $_PROFILE_NAME"
  echo "  Desc:    $_PROFILE_DESC"
  echo "  Base:    $_PROFILE_BASE"
  echo "  Created: $_PROFILE_CREATED"
  echo "  Tools:   $_PROFILE_TOOLS"
  echo ""
  echo "  Files:"
  for _e in ${_FILES[@]+"${_FILES[@]}"}; do
    local _raw_dest="${_e%%|*}"
    local _dest
    _dest="$(eval "echo \"${_raw_dest}\"")"
    echo "    $_dest"
  done
  echo ""
}

_ensure_tool() {
  local tool="$1"
  case "$tool" in
    powerlevel10k)
      if ! { [ -f /opt/homebrew/share/powerlevel10k/powerlevel10k.zsh-theme ] || \
             [ -f /usr/share/powerlevel10k/powerlevel10k.zsh-theme ]; }; then
        _warn "powerlevel10k not installed"
        if command -v brew >/dev/null 2>&1; then
          _info "Installing powerlevel10k via Homebrew..."
          brew install powerlevel10k
        else
          _error "Install powerlevel10k first: brew install powerlevel10k"
          return 1
        fi
      fi
      ;;
    oh-my-posh)
      if ! command -v oh-my-posh >/dev/null 2>&1; then
        _warn "oh-my-posh not installed"
        if command -v brew >/dev/null 2>&1; then
          _info "Installing oh-my-posh via Homebrew..."
          brew install jandedobbeleer/oh-my-posh/oh-my-posh
        else
          _error "Install oh-my-posh first: brew install jandedobbeleer/oh-my-posh/oh-my-posh"
          return 1
        fi
      fi
      ;;
  esac
}

_do_install() {
  local _ts
  _ts="$(date +%Y%m%d_%H%M%S)"

  echo ""
  echo -e "${BOLD}Installing: $_PROFILE_NAME${RESET}"
  echo ""

  # Ensure required tools are present
  for _tool in $_PROFILE_TOOLS; do
    _ensure_tool "$_tool" || exit 1
  done

  # Decode and place each file
  for _e in ${_FILES[@]+"${_FILES[@]}"}; do
    local _raw_dest="${_e%%|*}"
    local _b64="${_e#*|}"
    local _dest
    _dest="$(eval "echo \"${_raw_dest}\"")"

    # Skip iTerm2 profiles if iTerm2 isn't installed
    if [[ "$_dest" == *"iTerm2"* ]] && \
       ! [ -d "$HOME/Library/Application Support/iTerm2" ]; then
      _warn "iTerm2 not found — skipping $(basename "$_dest")"
      continue
    fi

    # Skip Ghostty config if Ghostty isn't installed
    if [[ "$_dest" == *"ghostty"* ]] && \
       ! { [ -d "/Applications/Ghostty.app" ] || command -v ghostty >/dev/null 2>&1; }; then
      _warn "Ghostty not found — skipping $(basename "$_dest")"
      continue
    fi

    # Skip Kitty config if Kitty isn't installed
    if [[ "$_dest" == *"kitty"* ]] && \
       ! { [ -d "/Applications/kitty.app" ] || command -v kitty >/dev/null 2>&1; }; then
      _warn "Kitty not found — skipping $(basename "$_dest")"
      continue
    fi

    # Backup anything already at the destination
    if [ -e "$_dest" ] || [ -L "$_dest" ]; then
      local _bak="${_dest}.backup.${_ts}"
      mv "$_dest" "$_bak"
      _warn "backed up $(basename "$_dest") → $_bak"
    fi

    mkdir -p "$(dirname "$_dest")"
    printf '%s' "$_b64" | _b64d > "$_dest"
    _success "installed $(basename "$_dest")"
  done

  echo ""
  echo -e "${GREEN}Done.${RESET} '$_PROFILE_NAME' installed — all files are local copies."
  echo ""
  echo "  Next steps:"
  echo "    source ~/.zshrc   (or open a new terminal)"
  if printf '%s' "$_PROFILE_TOOLS" | grep -q powerlevel10k; then
    echo "    p10k configure    — interactive prompt tweaker (optional)"
  fi
  if [ -d "$HOME/Library/Application Support/iTerm2" ]; then
    echo "    In iTerm2 → Preferences → Profiles — set your new profile as default"
  fi
  echo ""
}

case "${1:-install}" in
  --info|-i|info) _show_info ;;
  install|*)      _do_install ;;
esac
____INSTALL_LOGIC

  } > "$output"

  chmod +x "$output"
}

# ── Command: export ───────────────────────────────────────────────────────────
cmd_export() {
  local name="Exported Profile"
  local desc="Live config snapshot"
  local output=""

  while [[ $# -gt 0 ]]; do
    case "$1" in
      --name|-n) name="$2";   shift 2 ;;
      --desc|-d) desc="$2";   shift 2 ;;
      -o|--output) output="$2"; shift 2 ;;
      *) error "Unknown option: $1"; usage; exit 1 ;;
    esac
  done

  [ -z "$output" ] && output="$(slugify "$name").profile.sh"

  header "Exporting live config → ${output}"

  local zshrc="$HOME/.zshrc"
  if [ ! -f "$zshrc" ]; then
    error "~/.zshrc not found — nothing to export"
    exit 1
  fi

  local engine
  engine="$(detect_engine "$zshrc")"
  info "Detected prompt engine: $engine"

  local base tools
  case "$engine" in
    powerlevel10k) base="p10k-velvet"; tools="powerlevel10k" ;;
    oh-my-posh)    base="velvet";      tools="oh-my-posh"    ;;
    plain)         base="minimal";     tools=""               ;;
    *)             base="unknown";     tools=""               ;;
  esac

  local -a entries=()

  # ~/.zshrc
  entries+=( "\$HOME/.zshrc|$(b64_file "$zshrc")" )
  success "captured ~/.zshrc"

  # Prompt theme file
  case "$engine" in
    powerlevel10k)
      if [ -f "$HOME/.p10k.zsh" ]; then
        entries+=( "\$HOME/.p10k.zsh|$(b64_file "$HOME/.p10k.zsh")" )
        success "captured ~/.p10k.zsh"
      fi
      ;;
    oh-my-posh)
      # Extract the theme path referenced in zshrc
      local omp_theme=""
      omp_theme="$(grep -E 'OMP_THEME=' "$zshrc" \
        | sed 's/.*OMP_THEME=//' \
        | tr -d '"'"'" \
        | head -1)" || true
      omp_theme="$(eval echo "$omp_theme" 2>/dev/null || true)"
      if [ -n "$omp_theme" ] && [ -f "$omp_theme" ]; then
        local rel
        rel="$(echo "$omp_theme" | sed "s|$HOME|\\\$HOME|g")"
        entries+=( "${rel}|$(b64_file "$omp_theme")" )
        success "captured $(basename "$omp_theme")"
      fi
      ;;
  esac

  # iTerm2 DynamicProfiles
  local iterm_dp="$HOME/Library/Application Support/iTerm2/DynamicProfiles"
  if [ -d "$iterm_dp" ]; then
    for f in "$iterm_dp"/*.json; do
      [ -f "$f" ] || continue
      local rel="\$HOME/Library/Application Support/iTerm2/DynamicProfiles/$(basename "$f")"
      entries+=( "${rel}|$(b64_file "$f")" )
      success "captured iTerm2/$(basename "$f")"
    done
  fi

  generate_container "$name" "$desc" "$base" "$tools" "$output" \
    ${entries[@]+"${entries[@]}"}

  echo ""
  success "Saved → ${output}"
  info "Share and install with:  bash $(basename "$output")"
  echo ""
}

# ── Command: pack ─────────────────────────────────────────────────────────────
cmd_pack() {
  if [[ $# -eq 0 ]]; then
    error "Usage: profile.sh pack <profile-name> [--name NAME] [-o FILE]"
    echo ""
    echo "  Available profiles:"
    for d in "$PROFILES_DIR"/*/; do
      [ -d "$d" ] && echo "    $(basename "$d")"
    done
    echo ""
    exit 1
  fi

  local profile_name="$1"; shift
  local name=""
  local output=""

  while [[ $# -gt 0 ]]; do
    case "$1" in
      --name|-n)   name="$2";   shift 2 ;;
      -o|--output) output="$2"; shift 2 ;;
      *) error "Unknown option: $1"; exit 1 ;;
    esac
  done

  local profile_dir="$PROFILES_DIR/$profile_name"
  if [ ! -d "$profile_dir" ]; then
    error "Profile not found: $profile_name"
    error "Available: $(ls "$PROFILES_DIR" | tr '\n' ' ')"
    exit 1
  fi

  [ -z "$name" ]   && name="$profile_name"
  [ -z "$output" ] && output="${profile_name}.profile.sh"

  header "Packing '${profile_name}' → ${output}"

  # Per-profile metadata and file mappings
  local tools desc base
  local -a entries=()

  case "$profile_name" in
    velvet)
      tools="oh-my-posh"
      desc="Oh-My-Posh prompt with velvet/sakura color palette"
      base="velvet"

      entries+=( "\$HOME/.zshrc|$(b64_file "$profile_dir/zshrc")" )
      success "packed zshrc"

      entries+=( "\$HOME/oh-my-posh/velvet.omp.json|$(b64_file "$profile_dir/velvet.omp.json")" )
      success "packed velvet.omp.json"

      entries+=( "\$HOME/Library/Application Support/iTerm2/DynamicProfiles/velvet.json|$(b64_file "$profile_dir/iterm.json")" )
      success "packed iterm.json"

      if [ -f "$profile_dir/ghostty.conf" ]; then
        entries+=( "\$HOME/.config/ghostty/config|$(b64_file "$profile_dir/ghostty.conf")" )
        success "packed ghostty.conf"
      fi
      if [ -f "$profile_dir/kitty.conf" ]; then
        entries+=( "\$HOME/.config/kitty/kitty.conf|$(b64_file "$profile_dir/kitty.conf")" )
        success "packed kitty.conf"
      fi
      ;;

    p10k-velvet)
      tools="powerlevel10k"
      desc="Powerlevel10k prompt with velvet/sakura color palette blend"
      base="p10k-velvet"

      entries+=( "\$HOME/.zshrc|$(b64_file "$profile_dir/zshrc")" )
      success "packed zshrc"

      entries+=( "\$HOME/.p10k.zsh|$(b64_file "$profile_dir/.p10k.zsh")" )
      success "packed .p10k.zsh"

      entries+=( "\$HOME/Library/Application Support/iTerm2/DynamicProfiles/p10k-velvet.json|$(b64_file "$profile_dir/iterm.json")" )
      success "packed iterm.json"

      if [ -f "$profile_dir/ghostty.conf" ]; then
        entries+=( "\$HOME/.config/ghostty/config|$(b64_file "$profile_dir/ghostty.conf")" )
        success "packed ghostty.conf"
      fi
      if [ -f "$profile_dir/kitty.conf" ]; then
        entries+=( "\$HOME/.config/kitty/kitty.conf|$(b64_file "$profile_dir/kitty.conf")" )
        success "packed kitty.conf"
      fi
      ;;

    catppuccin)
      tools="powerlevel10k"
      desc="Powerlevel10k prompt with Catppuccin Mocha color palette"
      base="catppuccin"

      entries+=( "\$HOME/.zshrc|$(b64_file "$profile_dir/zshrc")" )
      success "packed zshrc"

      entries+=( "\$HOME/.p10k.zsh|$(b64_file "$profile_dir/.p10k.zsh")" )
      success "packed .p10k.zsh"

      entries+=( "\$HOME/Library/Application Support/iTerm2/DynamicProfiles/catppuccin.json|$(b64_file "$profile_dir/iterm.json")" )
      success "packed iterm.json"

      if [ -f "$profile_dir/ghostty.conf" ]; then
        entries+=( "\$HOME/.config/ghostty/config|$(b64_file "$profile_dir/ghostty.conf")" )
        success "packed ghostty.conf"
      fi
      if [ -f "$profile_dir/kitty.conf" ]; then
        entries+=( "\$HOME/.config/kitty/kitty.conf|$(b64_file "$profile_dir/kitty.conf")" )
        success "packed kitty.conf"
      fi
      ;;

    minimal)
      tools=""
      desc="Plain zsh prompt — no prompt engine required, full tools and aliases"
      base="minimal"

      entries+=( "\$HOME/.zshrc|$(b64_file "$profile_dir/zshrc")" )
      success "packed zshrc"

      if [ -f "$profile_dir/ghostty.conf" ]; then
        entries+=( "\$HOME/.config/ghostty/config|$(b64_file "$profile_dir/ghostty.conf")" )
        success "packed ghostty.conf"
      fi
      if [ -f "$profile_dir/kitty.conf" ]; then
        entries+=( "\$HOME/.config/kitty/kitty.conf|$(b64_file "$profile_dir/kitty.conf")" )
        success "packed kitty.conf"
      fi
      ;;

    *)
      # Generic fallback: pack all files into ~/.filename
      tools=""
      desc="Custom profile ($profile_name)"
      base="$profile_name"

      for f in "$profile_dir"/*; do
        [ -f "$f" ] || continue
        local fname
        fname="$(basename "$f")"
        entries+=( "\$HOME/.${fname}|$(b64_file "$f")" )
        success "packed $fname"
      done
      ;;
  esac

  generate_container "$name" "$desc" "$base" "$tools" "$output" \
    ${entries[@]+"${entries[@]}"}

  echo ""
  success "Saved → ${output}"
  info "Share and install with:  bash $(basename "$output")"
  echo ""
}

# ── Command: import ───────────────────────────────────────────────────────────
cmd_import() {
  local container="${1:-}"
  if [ -z "$container" ] || [ ! -f "$container" ]; then
    error "Usage: profile.sh import <container.sh>"
    exit 1
  fi
  bash "$container" install
}

# ── Command: info ─────────────────────────────────────────────────────────────
cmd_info() {
  local container="${1:-}"
  if [ -z "$container" ] || [ ! -f "$container" ]; then
    error "Usage: profile.sh info <container.sh>"
    exit 1
  fi
  bash "$container" --info
}

# ── Command: list ─────────────────────────────────────────────────────────────
cmd_list() {
  header "Built-in profiles"
  echo ""
  local -A descs=(
    [velvet]="Oh-My-Posh · velvet/sakura theme"
    [p10k-velvet]="Powerlevel10k · velvet color blend"
    [catppuccin]="Powerlevel10k · Catppuccin Mocha"
    [minimal]="plain zsh prompt · no engine"
  )
  for d in "$PROFILES_DIR"/*/; do
    [ -d "$d" ] || continue
    local pname
    pname="$(basename "$d")"
    local pdesc="${descs[$pname]:-custom profile}"
    printf "  ${BOLD}%-20s${RESET} ${DIM}%s${RESET}\n" "$pname" "$pdesc"
  done
  echo ""
  echo "  Pack one with:  ./profile.sh pack <name>"
  echo ""
}

# ── Main dispatch ─────────────────────────────────────────────────────────────
case "${1:-}" in
  export) shift; cmd_export "$@" ;;
  pack)   shift; cmd_pack   "$@" ;;
  import) shift; cmd_import "$@" ;;
  info)   shift; cmd_info   "$@" ;;
  list)         cmd_list ;;
  -h|--help|help|"") usage ;;
  *) error "Unknown command: $1"; usage; exit 1 ;;
esac
