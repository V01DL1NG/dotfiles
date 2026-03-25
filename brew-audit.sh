#!/usr/bin/env bash
# ============================================================================
# brew-audit.sh — Detect drift between installed Homebrew packages and Brewfile
#
# Usage:
#   ./brew-audit.sh               show packages missing from Brewfile + not installed
#   ./brew-audit.sh --fix         add all untracked installed packages to Brewfile
#   ./brew-audit.sh --install     install all Brewfile packages not yet installed
# ============================================================================
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BREWFILE="$SCRIPT_DIR/Brewfile"

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
fail()    { echo -e "  ${RED}✗${RESET}  ${1}"; }
header()  { echo -e "\n${BOLD}${PURPLE}${1}${RESET}\n"; }

if ! command -v brew >/dev/null 2>&1; then
  echo "brew not found — this script is macOS/Homebrew only" >&2
  exit 1
fi

FIX=false
INSTALL=false
MAKE_PRESET=false
for arg in "$@"; do
  case "$arg" in
    --fix)          FIX=true ;;
    --install)      INSTALL=true ;;
    --make-preset)  MAKE_PRESET=true ;;
    -h|--help)
      echo "Usage: ./brew-audit.sh [--fix] [--install] [--make-preset]"
      echo "  (no flags)     show drift report"
      echo "  --fix          append untracked formulae to Brewfile"
      echo "  --install      install Brewfile packages not yet present"
      echo "  --make-preset  launch brewfile-maker.sh to build a curated preset"
      exit 0 ;;
    *) echo "Unknown option: $arg" >&2; exit 1 ;;
  esac
done

header "Brew Audit"

# ── Gather data ───────────────────────────────────────────────────────────────
# Installed formulae (leaves = top-level, not pulled in as deps)
installed_leaves="$(brew leaves 2>/dev/null | sort)"

# Declared formulae in Brewfile
declared_formulae="$(grep '^brew ' "$BREWFILE" 2>/dev/null \
  | sed 's/^brew "\([^"]*\)".*/\1/' \
  | sed 's|.*/||' \
  | sort)"

# Declared casks
declared_casks="$(grep '^cask ' "$BREWFILE" 2>/dev/null \
  | sed 's/^cask "\([^"]*\)".*/\1/' \
  | sort)"

# Installed casks
installed_casks="$(brew list --cask 2>/dev/null | sort)"

# ── Formulae: in Brewfile but not installed ────────────────────────────────────
not_installed="$(comm -23 \
  <(echo "$declared_formulae") \
  <(brew list --formula 2>/dev/null | sort))"

# Formulae: installed (as leaf) but not in Brewfile
untracked="$(comm -23 \
  <(echo "$installed_leaves") \
  <(echo "$declared_formulae"))"

# Casks: declared but not installed
casks_missing="$(comm -23 \
  <(echo "$declared_casks") \
  <(echo "$installed_casks"))"

# Casks: installed but not in Brewfile
casks_untracked="$(comm -23 \
  <(echo "$installed_casks") \
  <(echo "$declared_casks"))"

# ── Report ────────────────────────────────────────────────────────────────────
has_issues=false

if [ -n "$not_installed" ]; then
  has_issues=true
  warn "Formulae in Brewfile but NOT installed:"
  while IFS= read -r pkg; do
    fail "$pkg"
  done <<< "$not_installed"
  echo ""
fi

if [ -n "$untracked" ]; then
  has_issues=true
  warn "Installed formulae (leaves) NOT in Brewfile:"
  while IFS= read -r pkg; do
    warn "$pkg"
  done <<< "$untracked"
  echo ""
fi

if [ -n "$casks_missing" ]; then
  has_issues=true
  warn "Casks in Brewfile but NOT installed:"
  while IFS= read -r pkg; do
    fail "$pkg (cask)"
  done <<< "$casks_missing"
  echo ""
fi

if [ -n "$casks_untracked" ]; then
  has_issues=true
  warn "Installed casks NOT in Brewfile:"
  while IFS= read -r pkg; do
    warn "$pkg (cask)"
  done <<< "$casks_untracked"
  echo ""
fi

if [ "$has_issues" = false ]; then
  success "Brewfile is in sync with installed packages"
fi

# ── --fix: append untracked to Brewfile ───────────────────────────────────────
if $FIX; then
  echo ""
  if [ -z "$untracked" ] && [ -z "$casks_untracked" ]; then
    info "Nothing to add — Brewfile already covers all installed packages"
  else
    if [ -n "$untracked" ]; then
      echo "" >> "$BREWFILE"
      echo "# Added by brew-audit.sh $(date +%Y-%m-%d)" >> "$BREWFILE"
      while IFS= read -r pkg; do
        echo "brew \"$pkg\"" >> "$BREWFILE"
        success "Added to Brewfile: $pkg"
      done <<< "$untracked"
    fi
    if [ -n "$casks_untracked" ]; then
      echo "" >> "$BREWFILE"
      echo "# Casks added by brew-audit.sh $(date +%Y-%m-%d)" >> "$BREWFILE"
      while IFS= read -r pkg; do
        echo "cask \"$pkg\"" >> "$BREWFILE"
        success "Added to Brewfile (cask): $pkg"
      done <<< "$casks_untracked"
    fi
  fi
fi

# ── --install: install missing Brewfile packages ──────────────────────────────
if $INSTALL; then
  echo ""
  if [ -z "$not_installed" ] && [ -z "$casks_missing" ]; then
    info "All Brewfile packages are already installed"
  else
    info "Installing missing packages from Brewfile..."
    brew bundle install --file="$BREWFILE" --no-upgrade
    success "Done"
  fi
fi

# ── --make-preset: launch brewfile-maker to build a curated subset ────────────
if $MAKE_PRESET; then
  if [ -f "$SCRIPT_DIR/brewfile-maker.sh" ]; then
    exec bash "$SCRIPT_DIR/brewfile-maker.sh"
  else
    error "brewfile-maker.sh not found in $SCRIPT_DIR"
    exit 1
  fi
fi

echo ""
