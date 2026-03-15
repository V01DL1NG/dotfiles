#!/usr/bin/env bash
# ============================================================================
# update.sh — non-destructive dotfiles update
#
# Pulls the latest repo changes and re-applies the installed profile.
# Skips files the user has personally modified; prompts on conflicts.
#
# Usage:
#   ./update.sh          # pull + smart re-apply
#   ./update.sh --check  # show what would change, no writes
# ============================================================================
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
STATE_FILE="$HOME/.config/dotfiles/state"
CHECK_ONLY=false

# ── Colors ───────────────────────────────────────────────────────────────────
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

# ── Parse args ────────────────────────────────────────────────────────────────
for arg in "$@"; do
  case "$arg" in
    --check|-n) CHECK_ONLY=true ;;
    -h|--help)
      echo ""
      echo -e "${BOLD}update.sh${RESET} — non-destructive dotfiles update"
      echo ""
      echo "  Usage:"
      echo "    ./update.sh          pull latest + smart re-apply"
      echo "    ./update.sh --check  preview what would change (no writes)"
      echo ""
      exit 0
      ;;
    *) error "Unknown option: $arg"; exit 1 ;;
  esac
done

# ── Read state file ───────────────────────────────────────────────────────────
read_state() {
  local key="$1"
  if [ ! -f "$STATE_FILE" ]; then
    echo ""
    return
  fi
  grep "^${key}=" "$STATE_FILE" 2>/dev/null | head -1 | cut -d= -f2-
}

# ── Hash helpers ──────────────────────────────────────────────────────────────
hash_file() {
  local path="$1"
  [ -f "$path" ] || { echo "missing"; return; }
  shasum -a 256 "$path" | awk '{print "sha256:"$1}'
}

# ── Pull latest changes ───────────────────────────────────────────────────────
header "Updating dotfiles repo"

if ! git -C "$SCRIPT_DIR" diff --quiet HEAD 2>/dev/null; then
  warn "Uncommitted changes in repo — skipping pull"
else
  if $CHECK_ONLY; then
    info "  [check mode] would run: git pull --rebase"
  else
    git -C "$SCRIPT_DIR" pull --rebase
    success "repo updated"
  fi
fi

# ── Determine installed profile ───────────────────────────────────────────────
PROFILE="$(read_state profile)"

if [ -z "$PROFILE" ]; then
  warn "No state file found at $STATE_FILE"
  warn "Run ./choose-profile.sh to install a profile first"
  exit 0
fi

info "Installed profile: ${BOLD}$PROFILE${RESET}"

PROFILE_DIR="$SCRIPT_DIR/profiles/$PROFILE"
if [ ! -d "$PROFILE_DIR" ]; then
  error "Profile directory not found: $PROFILE_DIR"
  exit 1
fi

# ── Build the file mapping for this profile ───────────────────────────────────
# Each entry: "source_path|dest_path|label"
declare -a FILE_MAP=()

case "$PROFILE" in
  velvet)
    FILE_MAP+=(
      "$PROFILE_DIR/zshrc|$HOME/.zshrc|zshrc"
      "$PROFILE_DIR/velvet.omp.json|$HOME/oh-my-posh/velvet.omp.json|velvet.omp.json"
    )
    ;;
  p10k-velvet)
    FILE_MAP+=(
      "$PROFILE_DIR/zshrc|$HOME/.zshrc|zshrc"
      "$PROFILE_DIR/.p10k.zsh|$HOME/.p10k.zsh|.p10k.zsh"
    )
    ;;
  catppuccin)
    FILE_MAP+=(
      "$PROFILE_DIR/zshrc|$HOME/.zshrc|zshrc"
      "$PROFILE_DIR/.p10k.zsh|$HOME/.p10k.zsh|.p10k.zsh"
    )
    ;;
  minimal)
    FILE_MAP+=(
      "$PROFILE_DIR/zshrc|$HOME/.zshrc|zshrc"
    )
    ;;
esac

# Terminal configs — include only if the terminal is present
if [ -d "/Applications/Ghostty.app" ] || command -v ghostty >/dev/null 2>&1; then
  FILE_MAP+=( "$PROFILE_DIR/ghostty.conf|$HOME/.config/ghostty/config|ghostty config" )
fi
if [ -d "/Applications/kitty.app" ] || command -v kitty >/dev/null 2>&1; then
  FILE_MAP+=( "$PROFILE_DIR/kitty.conf|$HOME/.config/kitty/kitty.conf|kitty config" )
fi

# ── Per-file update logic ─────────────────────────────────────────────────────
header "Checking files"
echo ""

TIMESTAMP="$(date +%Y%m%d_%H%M%S)"
updated=0
skipped=0
conflicts=0

for entry in "${FILE_MAP[@]}"; do
  src="${entry%%|*}"
  rest="${entry#*|}"
  dst="${rest%%|*}"
  label="${rest#*|}"

  # Hashes
  repo_hash="$(hash_file "$src")"
  current_hash="$(hash_file "$dst")"
  stored_hash="$(read_state "$dst")"

  # No repo file — skip
  if [ "$repo_hash" = "missing" ]; then
    warn "$label — not in repo, skipping"
    continue
  fi

  # File not installed yet — just copy
  if [ "$current_hash" = "missing" ]; then
    if $CHECK_ONLY; then
      info "$label — not installed, would copy from repo"
    else
      mkdir -p "$(dirname "$dst")"
      cp "$src" "$dst"
      success "$label — installed (new)"
      (( updated++ )) || true
    fi
    continue
  fi

  # Already up to date
  if [ "$current_hash" = "$repo_hash" ]; then
    success "$label — already up to date"
    continue
  fi

  # Determine state
  if [ -n "$stored_hash" ] && [ "$current_hash" = "$stored_hash" ]; then
    # User hasn't touched it, repo has changed → auto-update
    if $CHECK_ONLY; then
      info "$label — repo updated, would apply automatically"
    else
      cp "$src" "$dst"
      success "$label — updated from repo"
      (( updated++ )) || true
    fi

  elif [ -n "$stored_hash" ] && [ "$repo_hash" = "$stored_hash" ]; then
    # User modified, repo unchanged → keep user's version
    warn "$label — you have local edits, repo unchanged — keeping yours"
    (( skipped++ )) || true

  else
    # Both user and repo changed → conflict
    (( conflicts++ )) || true
    echo ""
    warn "$label — CONFLICT: both you and the repo changed this file"
    echo ""
    diff --color=always -u "$dst" "$src" || true
    echo ""
    if $CHECK_ONLY; then
      warn "  [check mode] would prompt: overwrite with repo version? [y/N]"
    else
      read -r -p "  Overwrite with repo version? [y/N] " choice
      case "$choice" in
        y|Y)
          local bak="${dst}.backup.${TIMESTAMP}"
          cp "$dst" "$bak"
          warn "backed up → $bak"
          cp "$src" "$dst"
          success "$label — updated (your backup is safe)"
          (( updated++ )) || true
          ;;
        *)
          warn "$label — kept your version"
          (( skipped++ )) || true
          ;;
      esac
    fi
  fi
done

# ── Write updated state ───────────────────────────────────────────────────────
if ! $CHECK_ONLY && (( updated > 0 )); then
  state_dir="$HOME/.config/dotfiles"
  mkdir -p "$state_dir"
  {
    echo "profile=$PROFILE"
    echo "timestamp=$(date -u +%Y-%m-%dT%H:%M:%S)"
    for entry in "${FILE_MAP[@]}"; do
      dst="${entry#*|}"
      dst="${dst%%|*}"
      [ -f "$dst" ] && echo "$dst=$(hash_file "$dst")"
    done
  } > "$STATE_FILE"
fi

# ── Summary ───────────────────────────────────────────────────────────────────
echo ""
if $CHECK_ONLY; then
  header "Check complete (no changes made)"
else
  header "Update complete"
fi
echo ""
[ "$updated"   -gt 0 ] && success "$updated file(s) updated"
[ "$skipped"   -gt 0 ] && warn    "$skipped file(s) skipped (local edits preserved)"
[ "$conflicts" -gt 0 ] && warn    "$conflicts conflict(s) resolved"
echo ""
