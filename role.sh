#!/usr/bin/env bash
# ============================================================================
# role.sh — role management CLI
#
# Usage:
#   ./role.sh apply  <work|personal|server>   append role to ~/.zshrc
#   ./role.sh remove <work|personal|server>   remove role from ~/.zshrc
#   ./role.sh list                             show available roles
#   ./role.sh status                           show which roles are active
# ============================================================================
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# ── Colors ───────────────────────────────────────────────────────────────────
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

# ── Known roles ──────────────────────────────────────────────────────────────
declare -a KNOWN_ROLES=(work personal server)

# ── Role descriptions ─────────────────────────────────────────────────────────
role_description() {
  case "$1" in
    work)     echo "corporate proxy stubs, work identity reminder" ;;
    personal) echo "project navigation shortcuts, daily note helper" ;;
    server)   echo "GUI tool fallbacks, larger history, ASCII prompt option" ;;
  esac
}

# ── Helpers ───────────────────────────────────────────────────────────────────
validate_role() {
  local role="$1"
  for known in "${KNOWN_ROLES[@]}"; do
    [ "$role" = "$known" ] && return 0
  done
  error "Unknown role: ${role}"
  error "Available roles: ${KNOWN_ROLES[*]}"
  exit 1
}

is_applied() {
  local role="$1"
  grep -qF "# <<< role:${role} >>>" "$HOME/.zshrc" 2>/dev/null
}

backup_zshrc() {
  local zshrc="$HOME/.zshrc"
  local backup="${zshrc}.backup.$(date +%Y%m%d_%H%M%S)"
  cp "$zshrc" "$backup"
  info "backed up ~/.zshrc → $backup"
}

# ── apply ─────────────────────────────────────────────────────────────────────
cmd_apply() {
  local role="${1:-}"
  if [ -z "$role" ]; then
    error "apply requires a role name"
    show_usage
    exit 1
  fi

  validate_role "$role"

  if is_applied "$role"; then
    warn "Role '${role}' is already applied — skipping."
    exit 0
  fi

  local zshrc="$HOME/.zshrc"
  touch "$zshrc"
  backup_zshrc

  {
    printf '\n# <<< role:%s >>>\n' "$role"
    cat "$SCRIPT_DIR/roles/${role}.zsh"
    printf '# <<< /role:%s >>>\n' "$role"
  } >> "$zshrc"

  success "Role '${role}' applied."
  info "run: source ~/.zshrc"
}

# ── remove ────────────────────────────────────────────────────────────────────
cmd_remove() {
  local role="${1:-}"
  if [ -z "$role" ]; then
    error "remove requires a role name"
    show_usage
    exit 1
  fi

  validate_role "$role"

  if ! is_applied "$role"; then
    warn "Role '${role}' is not currently applied — nothing to remove."
    exit 0
  fi

  backup_zshrc

  local tmp; tmp="$(mktemp)"

  # Pass 1: strip the role block
  awk -v role="$role" '
    $0 == "# <<< role:" role " >>>" { inside=1; next }
    $0 == "# <<< /role:" role " >>>" { inside=0; next }
    inside == 0 { print }
  ' "$HOME/.zshrc" > "$tmp"

  # Pass 2: collapse consecutive blank lines into one
  awk 'NF>0 || prev_blank==0 { print; prev_blank=(NF==0) }' "$tmp" > "$HOME/.zshrc"

  rm -f "$tmp"

  success "Role '${role}' removed."
  info "run: source ~/.zshrc"
}

# ── list ──────────────────────────────────────────────────────────────────────
cmd_list() {
  header "Available roles"
  echo ""
  for role in "${KNOWN_ROLES[@]}"; do
    local desc; desc="$(role_description "$role")"
    echo -e "  ${BOLD}${LAVENDER}${role}${RESET}"
    echo -e "    ${DIM}${desc}${RESET}"
    echo ""
  done
}

# ── status ────────────────────────────────────────────────────────────────────
cmd_status() {
  header "Role status"
  echo ""
  for role in "${KNOWN_ROLES[@]}"; do
    if is_applied "$role"; then
      echo -e "  ${GREEN}●${RESET}  ${role}"
    else
      echo -e "  ${DIM}○${RESET}  ${role}"
    fi
  done
  echo ""
}

# ── usage ─────────────────────────────────────────────────────────────────────
show_usage() {
  echo ""
  echo -e "${BOLD}${PURPLE}role.sh${RESET} — role management CLI"
  echo ""
  echo "  Usage:"
  echo "    ./role.sh apply  <work|personal|server>   append role to ~/.zshrc"
  echo "    ./role.sh remove <work|personal|server>   remove role from ~/.zshrc"
  echo "    ./role.sh list                             show available roles"
  echo "    ./role.sh status                           show which roles are active"
  echo ""
}

# ── Dispatch ──────────────────────────────────────────────────────────────────
case "${1:-}" in
  apply)  cmd_apply  "${2:-}" ;;
  remove) cmd_remove "${2:-}" ;;
  list)   cmd_list ;;
  status) cmd_status ;;
  *)      show_usage ;;
esac
