#!/usr/bin/env bash
# ============================================================================
# snapshot.sh — Capture environment state for incident recovery / diff
#
# Creates a timestamped snapshot of: tool versions, active roles, doctor
# output, macOS key defaults, and git config. Useful for before/after
# comparison when an update breaks something.
#
# Usage:
#   ./scripts/snapshot.sh                  write snapshot to ~/.dotfiles-snapshots/
#   ./scripts/snapshot.sh -o file.txt      write to specific file
#   ./scripts/snapshot.sh --diff           diff two snapshots (interactive picker)
# ============================================================================
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_DIR="$(dirname "$SCRIPT_DIR")"
SNAPSHOT_DIR="$HOME/.dotfiles-snapshots"

OUTPUT_FILE=""
DIFF_MODE=false

for arg in "$@"; do
  case "$arg" in
    -o) shift; OUTPUT_FILE="$1"; shift ;;
    --diff) DIFF_MODE=true ;;
    -h|--help)
      echo "Usage: ./scripts/snapshot.sh [-o file] [--diff]"
      exit 0 ;;
  esac
done

# ── Diff mode ─────────────────────────────────────────────────────────────────
if $DIFF_MODE; then
  if ! command -v fzf >/dev/null 2>&1; then
    echo "fzf required for --diff mode" >&2; exit 1
  fi
  snapshots=( "$SNAPSHOT_DIR"/*.txt )
  if [ "${#snapshots[@]}" -lt 2 ]; then
    echo "Need at least 2 snapshots to diff. Run snapshot.sh first." >&2; exit 1
  fi
  echo "Select BEFORE snapshot:"
  before="$(printf '%s\n' "${snapshots[@]}" | fzf --prompt='before> ')"
  echo "Select AFTER snapshot:"
  after="$(printf '%s\n' "${snapshots[@]}" | fzf --prompt='after> ')"
  diff --color=always -u "$before" "$after" | less -R
  exit 0
fi

# ── Build snapshot ────────────────────────────────────────────────────────────
mkdir -p "$SNAPSHOT_DIR"

TIMESTAMP="$(date +%Y%m%d_%H%M%S)"
if [ -z "$OUTPUT_FILE" ]; then
  OUTPUT_FILE="$SNAPSHOT_DIR/snapshot-${TIMESTAMP}.txt"
fi

{
  echo "# dotfiles snapshot — $TIMESTAMP"
  echo "# $(uname -srm)"
  echo ""

  echo "## Git repo"
  git -C "$REPO_DIR" log --oneline -3 2>/dev/null || echo "(not a git repo)"
  echo ""

  echo "## Active roles"
  bash "$REPO_DIR/role.sh" status 2>/dev/null | sed 's/\x1b\[[0-9;]*m//g' || echo "(role.sh not found)"
  echo ""

  echo "## Tool versions"
  for tool in zsh brew git nvim tmux fzf bat eza fd zoxide atuin delta lazygit btop direnv op gpg; do
    if command -v "$tool" >/dev/null 2>&1; then
      ver="$("$tool" --version 2>/dev/null | head -1 || echo '?')"
      printf "  %-12s %s\n" "$tool" "$ver"
    fi
  done
  echo ""

  echo "## Homebrew top-level formulae"
  brew leaves 2>/dev/null | sort || echo "(brew not available)"
  echo ""

  echo "## Installed casks"
  brew list --cask 2>/dev/null | sort || echo "(brew not available)"
  echo ""

  if [ "$(uname)" = "Darwin" ]; then
    echo "## macOS defaults (subset)"
    printf "  KeyRepeat:            %s\n" "$(defaults read NSGlobalDomain KeyRepeat 2>/dev/null || echo '?')"
    printf "  InitialKeyRepeat:     %s\n" "$(defaults read NSGlobalDomain InitialKeyRepeat 2>/dev/null || echo '?')"
    printf "  AppleShowAllFiles:    %s\n" "$(defaults read com.apple.finder AppleShowAllFiles 2>/dev/null || echo '?')"
    printf "  ScreenshotLocation:   %s\n" "$(defaults read com.apple.screencapture location 2>/dev/null || echo '?')"
    echo ""
  fi

  echo "## Git config (global)"
  git config --global --list 2>/dev/null | grep -v 'credential\|url\.' || echo "(none)"
  echo ""

  echo "## Doctor output"
  bash "$REPO_DIR/doctor.sh" 2>/dev/null | sed 's/\x1b\[[0-9;]*m//g' || echo "(doctor.sh not found)"

} > "$OUTPUT_FILE"

echo "✓ Snapshot written: $OUTPUT_FILE"
