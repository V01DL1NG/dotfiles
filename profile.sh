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
# shellcheck source=platform.sh
. "$SCRIPT_DIR/platform.sh"
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
  printf "    %-45s %s\n" "export [--name NAME] [--desc DESC] [-o FILE]"  "snapshot live ~/.zshrc + theme files"
  printf "    %-45s %s\n" "pack <profile-name> [--name NAME] [-o FILE]"   "pack a profiles/ dir into a container"
  printf "    %-45s %s\n" "patch <profile-name> [--files KEYS] [-o FILE]" "pack only specific files (zshrc,p10k,ghostty…)"
  printf "    %-45s %s\n" "import <container.sh>"                          "install a container (copies files locally)"
  printf "    %-45s %s\n" "info <container.sh>"                            "show container metadata without installing"
  printf "    %-45s %s\n" "diff <container.sh> [other.sh]"                 "diff container vs live files (or vs another)"
  printf "    %-45s %s\n" "rollback [--list]"                              "restore the most recent backup set"
  printf "    %-45s %s\n" "push <container.sh> [--private]"                "upload to a GitHub Gist (needs gh CLI)"
  printf "    %-45s %s\n" "fetch <gist-url>"                               "download + preview + install from a Gist URL"
  printf "    %-45s %s\n" "list"                                            "list built-in profiles"
  echo ""
  echo "  Examples:"
  echo "    ./profile.sh export --name 'My Setup' -o my-setup.profile.sh"
  echo "    ./profile.sh pack p10k-velvet -o velvet.profile.sh"
  echo "    ./profile.sh patch velvet --files ghostty,kitty -o terminal.profile.sh"
  echo "    ./profile.sh push velvet.profile.sh"
  echo "    ./profile.sh fetch https://gist.github.com/user/abc123"
  echo "    ./profile.sh diff velvet.profile.sh"
  echo "    ./profile.sh rollback"
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
        elif command -v apt-get >/dev/null 2>&1; then
          _error "powerlevel10k is not in apt repos — install manually or use the minimal profile"
          return 1
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
        elif command -v apt-get >/dev/null 2>&1 || command -v dnf >/dev/null 2>&1; then
          _info "Installing oh-my-posh via official script..."
          curl -s https://ohmyposh.dev/install.sh | bash -s -- -d ~/.local/bin
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

# ── Helper: parse _FILES entries from a container file ───────────────────────
# Prints one 'dest_expr|base64' line per embedded file (no execution)
container_entries() {
  local container="$1"
  local q="'"
  awk -v q="$q" '
    /^_FILES=\(/ { p=1; next }
    p && /^\)/   { p=0; next }
    p && NF {
      line = $0
      sub("^[[:space:]]*" q, "", line)
      sub(q "[[:space:]]*$", "", line)
      if (length(line) > 0) print line
    }
  ' "$container"
}

# Decode a container's embedded files into a flat directory
extract_to_dir() {
  local container="$1" dir="$2"
  local os; os="$(uname -s)"
  while IFS= read -r entry; do
    [ -z "$entry" ] && continue
    local dest_expr="${entry%%|*}" b64="${entry#*|}"
    local dest fname
    dest="$(eval "printf '%s' \"$dest_expr\"")"
    fname="$(basename "$dest")"
    if [ "$os" = "Darwin" ]; then
      printf '%s' "$b64" | base64 -D > "$dir/$fname"
    else
      printf '%s' "$b64" | base64 -d > "$dir/$fname"
    fi
  done < <(container_entries "$container")
}

# Copy the live installed files (by dest path) into a flat directory
extract_live_to_dir() {
  local container="$1" dir="$2"
  while IFS= read -r entry; do
    [ -z "$entry" ] && continue
    local dest_expr="${entry%%|*}"
    local dest fname
    dest="$(eval "printf '%s' \"$dest_expr\"")"
    fname="$(basename "$dest")"
    [ -f "$dest" ] && cp "$dest" "$dir/$fname"
  done < <(container_entries "$container")
}

# ── Command: diff ─────────────────────────────────────────────────────────────
cmd_diff() {
  if [[ $# -eq 0 ]]; then
    error "Usage: profile.sh diff <container.sh> [<other-container.sh>]"
    exit 1
  fi

  local left="$1" right="${2:-}"
  [ -f "$left" ] || { error "Not found: $left"; exit 1; }
  [ -n "$right" ] && { [ -f "$right" ] || { error "Not found: $right"; exit 1; }; }

  local tmpA tmpB
  tmpA="$(mktemp -d)"; tmpB="$(mktemp -d)"
  trap "rm -rf '$tmpA' '$tmpB'" EXIT

  extract_to_dir "$left" "$tmpA"

  if [ -n "$right" ]; then
    extract_to_dir "$right" "$tmpB"
    header "Diff: $(basename "$left")  vs  $(basename "$right")"
  else
    extract_live_to_dir "$left" "$tmpB"
    header "Diff: $(basename "$left")  vs  live files"
  fi

  echo ""
  local found_diff=false

  for f in "$tmpA"/*; do
    [ -f "$f" ] || continue
    local fname; fname="$(basename "$f")"
    local other="$tmpB/$fname"
    if [ ! -f "$other" ]; then
      warn "$fname — not present on the right side"
      found_diff=true
    elif diff -q "$f" "$other" >/dev/null 2>&1; then
      success "$fname — identical"
    else
      found_diff=true
      echo -e "\n${BOLD}--- $fname${RESET}"
      diff --color=always -u "$other" "$f" || true
    fi
  done

  for f in "$tmpB"/*; do
    [ -f "$f" ] || continue
    local fname; fname="$(basename "$f")"
    [ -f "$tmpA/$fname" ] || { warn "$fname — only on right side"; found_diff=true; }
  done

  echo ""
  $found_diff || success "No differences found"
}

# ── Command: rollback ─────────────────────────────────────────────────────────
cmd_rollback() {
  local list_only=false
  for arg in "$@"; do
    case "$arg" in
      --list|-l) list_only=true ;;
      *) error "Unknown option: $arg"; exit 1 ;;
    esac
  done

  header "Rollback — restore a previous backup set"

  local -a scan_dirs=("$HOME" "$HOME/oh-my-posh" "$HOME/.config/ghostty" "$HOME/.config/kitty")
  local iterm_dp="$HOME/Library/Application Support/iTerm2/DynamicProfiles"
  [ -d "$iterm_dp" ] && scan_dirs+=("$iterm_dp")

  local -a bak_files=()
  while IFS= read -r f; do
    bak_files+=("$f")
  done < <(
    for d in "${scan_dirs[@]}"; do
      [ -d "$d" ] && find "$d" -maxdepth 1 -name "*.backup.*" 2>/dev/null
    done | sort
  )

  if [ ${#bak_files[@]} -eq 0 ]; then
    warn "No backup files found"
    return
  fi

  # Collect unique timestamps (everything after the last .backup.)
  local -a timestamps=()
  for f in "${bak_files[@]}"; do
    local ts="${f##*.backup.}"
    local seen=false
    for t in ${timestamps[@]+"${timestamps[@]}"}; do
      [ "$t" = "$ts" ] && seen=true && break
    done
    $seen || timestamps+=("$ts")
  done
  IFS=$'\n' timestamps=($(printf '%s\n' "${timestamps[@]}" | sort -r)); unset IFS

  if $list_only; then
    echo ""
    echo "  Available backup sets:"
    echo ""
    for ts in "${timestamps[@]}"; do
      local count=0
      for f in "${bak_files[@]}"; do [[ "$f" == *".backup.$ts" ]] && (( count++ )) || true; done
      printf "    %s  (%d file(s))\n" "$ts" "$count"
    done
    echo ""
    return
  fi

  echo ""
  echo "  Backup sets (most recent first):"
  echo ""
  local i=1
  for ts in "${timestamps[@]}"; do
    local count=0
    for f in "${bak_files[@]}"; do [[ "$f" == *".backup.$ts" ]] && (( count++ )) || true; done
    printf "  ${BOLD}%d)${RESET}  %s  (%d file(s))\n" "$i" "$ts" "$count"
    (( i++ ))
  done
  echo ""
  echo -e "  ${BOLD}q)${RESET} Cancel"
  echo ""

  local choice
  read -r -p "  Choose a set to restore [1]: " choice
  choice="${choice:-1}"
  case "$choice" in
    q|Q) info "Aborted."; return ;;
    *)
      if ! [[ "$choice" =~ ^[0-9]+$ ]] || (( choice < 1 || choice > ${#timestamps[@]} )); then
        error "Invalid choice"; exit 1
      fi
      ;;
  esac

  local selected_ts="${timestamps[$((choice - 1))]}"
  local -a to_restore=()
  for f in "${bak_files[@]}"; do
    [[ "$f" == *".backup.$selected_ts" ]] && to_restore+=("$f")
  done

  echo ""
  info "Files to restore:"
  echo ""
  for bak in "${to_restore[@]}"; do
    local orig="${bak%.backup.$selected_ts}"
    printf "    %s\n    → %s\n\n" "$bak" "$orig"
  done

  read -r -p "  Proceed? [y/N] " confirm
  case "$confirm" in
    y|Y)
      for bak in "${to_restore[@]}"; do
        local orig="${bak%.backup.$selected_ts}"
        cp "$bak" "$orig"
        success "restored $(basename "$orig")"
      done
      echo ""
      success "Rollback complete — source ~/.zshrc or open a new terminal"
      ;;
    *) info "Aborted." ;;
  esac
}

# ── Command: push ─────────────────────────────────────────────────────────────
cmd_push() {
  local container="${1:-}"
  local public_flag="--public"
  shift || true
  while [[ $# -gt 0 ]]; do
    case "$1" in
      --private) public_flag=""; shift ;;
      --public)  public_flag="--public"; shift ;;
      *) error "Unknown option: $1"; exit 1 ;;
    esac
  done

  if [ -z "$container" ] || [ ! -f "$container" ]; then
    error "Usage: profile.sh push <container.sh> [--private]"
    exit 1
  fi

  if ! command -v gh >/dev/null 2>&1; then
    error "gh CLI not found"
    info "Install: brew install gh"
    info "Auth:    gh auth login"
    exit 1
  fi

  header "Pushing $(basename "$container") to GitHub Gist"

  local url
  # shellcheck disable=SC2086
  url="$(gh gist create $public_flag --filename "$(basename "$container")" "$container")"

  echo ""
  success "Published → $url"
  info "Others can install with:"
  echo ""
  echo "    ./profile.sh fetch $url"
  echo ""
}

# ── Command: fetch ────────────────────────────────────────────────────────────
cmd_fetch() {
  local url="${1:-}"
  if [ -z "$url" ]; then
    error "Usage: profile.sh fetch <gist-url>"
    exit 1
  fi

  header "Fetching profile"

  local tmpfile
  tmpfile="$(mktemp /tmp/profile-XXXXXX.profile.sh)"
  trap "rm -f '$tmpfile'" EXIT

  if [[ "$url" =~ gist\.github\.com ]]; then
    command -v gh >/dev/null 2>&1 || { error "gh CLI required for Gist URLs — install with: brew install gh"; exit 1; }
    local gist_id="${url##*/}"
    gh gist view "$gist_id" --raw > "$tmpfile"
  else
    command -v curl >/dev/null 2>&1 || { error "curl not found"; exit 1; }
    curl -fsSL "$url" -o "$tmpfile"
  fi

  chmod +x "$tmpfile"
  success "Downloaded"

  bash "$tmpfile" --info

  echo ""
  read -r -p "  Install this profile? [y/N] " choice
  case "$choice" in
    y|Y) bash "$tmpfile" install ;;
    *)   info "Aborted." ;;
  esac
}

# ── Command: patch ────────────────────────────────────────────────────────────
cmd_patch() {
  if [[ $# -eq 0 ]]; then
    error "Usage: profile.sh patch <profile-name> [--files KEYS] [-o FILE]"
    echo ""
    echo "  File keys (comma-separated): zshrc, p10k, theme, ghostty, kitty, iterm"
    echo "  Example:  ./profile.sh patch velvet --files ghostty,kitty -o terminal.profile.sh"
    echo ""
    exit 1
  fi

  local profile_name="$1"; shift
  local files_arg="" output="" name=""

  while [[ $# -gt 0 ]]; do
    case "$1" in
      --files|-f) files_arg="$2"; shift 2 ;;
      -o|--output) output="$2";  shift 2 ;;
      --name|-n)   name="$2";    shift 2 ;;
      *) error "Unknown option: $1"; exit 1 ;;
    esac
  done

  local profile_dir="$PROFILES_DIR/$profile_name"
  [ -d "$profile_dir" ] || {
    error "Profile not found: $profile_name"
    error "Available: $(ls "$PROFILES_DIR" | tr '\n' ' ')"
    exit 1
  }

  # Key → src_path|dest_expr
  local -A key_map=(
    [zshrc]="$profile_dir/zshrc|\$HOME/.zshrc"
    [p10k]="$profile_dir/.p10k.zsh|\$HOME/.p10k.zsh"
    [theme]="$profile_dir/velvet.omp.json|\$HOME/oh-my-posh/velvet.omp.json"
    [ghostty]="$profile_dir/ghostty.conf|\$HOME/.config/ghostty/config"
    [kitty]="$profile_dir/kitty.conf|\$HOME/.config/kitty/kitty.conf"
    [iterm]="$profile_dir/iterm.json|\$HOME/Library/Application Support/iTerm2/DynamicProfiles/${profile_name}.json"
  )
  local valid_keys="zshrc, p10k, theme, ghostty, kitty, iterm"

  # Interactive picker if --files not given
  if [ -z "$files_arg" ]; then
    echo ""
    echo "  Available files in '${profile_name}':"
    echo ""
    for key in zshrc p10k theme ghostty kitty iterm; do
      local src="${key_map[$key]%%|*}"
      [ -f "$src" ] && echo "    $key"
    done
    echo ""
    read -r -p "  Files to include (comma-separated): " files_arg
    [ -z "$files_arg" ] && { info "Aborted."; exit 0; }
  fi

  [ -z "$name" ]   && name="${profile_name}-patch"
  [ -z "$output" ] && output="${profile_name}-patch.profile.sh"

  header "Creating patch '${profile_name}' [${files_arg}] → ${output}"

  local -a entries=()
  IFS=',' read -ra keys_arr <<< "$files_arg"
  for raw_key in "${keys_arr[@]}"; do
    local key="${raw_key// /}"
    if [[ -v "key_map[$key]" ]]; then
      local mapping="${key_map[$key]}"
      local src="${mapping%%|*}" dst_expr="${mapping#*|}"
      if [ -f "$src" ]; then
        entries+=( "${dst_expr}|$(b64_file "$src")" )
        success "packed $key"
      else
        warn "$key — not found in $profile_name, skipping"
      fi
    else
      warn "Unknown key: $key  (valid: $valid_keys)"
    fi
  done

  if [ ${#entries[@]} -eq 0 ]; then
    error "No files to pack — aborting"
    exit 1
  fi

  local tools=""
  case "$profile_name" in
    velvet)                tools="oh-my-posh"    ;;
    p10k-velvet|catppuccin) tools="powerlevel10k" ;;
  esac

  generate_container "$name" "Patch for $profile_name — files: ${files_arg}" \
    "$profile_name" "$tools" "$output" \
    ${entries[@]+"${entries[@]}"}

  echo ""
  success "Saved → ${output}"
  info "Installs only: ${files_arg}"
  echo ""
}

# ── Main dispatch ─────────────────────────────────────────────────────────────
case "${1:-}" in
  export)   shift; cmd_export   "$@" ;;
  pack)     shift; cmd_pack     "$@" ;;
  patch)    shift; cmd_patch    "$@" ;;
  import)   shift; cmd_import   "$@" ;;
  info)     shift; cmd_info     "$@" ;;
  diff)     shift; cmd_diff     "$@" ;;
  rollback) shift; cmd_rollback "$@" ;;
  push)     shift; cmd_push     "$@" ;;
  fetch)    shift; cmd_fetch    "$@" ;;
  list)           cmd_list ;;
  -h|--help|help|"") usage ;;
  *) error "Unknown command: $1"; usage; exit 1 ;;
esac
