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
declare -a KNOWN_ROLES=(work personal server secrets ai dev)

# ── Role descriptions ─────────────────────────────────────────────────────────
role_description() {
  case "$1" in
    work)     echo "corporate proxy stubs, work identity reminder" ;;
    personal) echo "project navigation shortcuts, daily note helper" ;;
    server)   echo "GUI tool fallbacks, larger history, ASCII prompt option" ;;
    secrets)  echo "secret() helper — 1Password CLI / GPG injection into env vars" ;;
    ai)       echo "ai-launcher shell integration — ai, ai-chat, ai-sanity aliases" ;;
    dev)      echo "proj-new and proj-clone scaffolding helpers" ;;
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
  local backup; backup="${zshrc}.backup.$(date +%Y%m%d_%H%M%S)"
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

  # Always apply Dock layout — runs even if zshrc role marker already exists
  if [ -f "$SCRIPT_DIR/dock-config.sh" ]; then
    bash "$SCRIPT_DIR/dock-config.sh" --apply "$role" || true
  fi

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

# ── create ────────────────────────────────────────────────────────────────────
cmd_create() {
  local role="${1:-}"
  if [ -z "$role" ]; then
    error "create requires a role name (alphanumeric, hyphens OK)"
    show_usage
    exit 1
  fi

  # Validate name — letters, digits, hyphens only
  if ! echo "$role" | grep -qE '^[a-zA-Z0-9-]+$'; then
    error "Role name must contain only letters, digits, and hyphens: '${role}'"
    exit 1
  fi

  local role_file="$SCRIPT_DIR/roles/${role}.zsh"
  if [ -f "$role_file" ]; then
    error "Role '${role}' already exists: $role_file"
    exit 1
  fi

  # Prompt for metadata
  echo ""
  echo -e "${BOLD}${PURPLE}Creating new role: ${role}${RESET}"
  echo ""
  read -r -p "  Description (one line): " desc
  read -r -p "  Env vars to export (comma-separated, or Enter to skip): " envvars
  read -r -p "  Aliases (e.g. alias foo='bar', or Enter to skip): " aliases
  echo ""

  # Write the role file
  {
    printf '# %s role\n' "$role"
    [ -n "$desc" ] && printf '# %s\n' "$desc"
    printf '\n'

    if [ -n "$envvars" ]; then
      printf '# Environment variables\n'
      IFS=',' read -ra _vars <<< "$envvars"
      for v in "${_vars[@]}"; do
        v="${v// /}"  # trim spaces
        [ -n "$v" ] && printf '# export %s=""\n' "$v"
      done
      printf '\n'
    fi

    if [ -n "$aliases" ]; then
      printf '# Aliases\n'
      printf '%s\n' "$aliases"
      printf '\n'
    fi

    printf '# Add your role content here\n'
  } > "$role_file"

  # Register in KNOWN_ROLES by patching role.sh itself
  local current_roles
  current_roles="$(grep '^declare -a KNOWN_ROLES=' "$SCRIPT_DIR/role.sh" | sed "s/.*=(\(.*\))/\1/")"
  sed -i.bak "s|^declare -a KNOWN_ROLES=.*|declare -a KNOWN_ROLES=(${current_roles} ${role})|" "$SCRIPT_DIR/role.sh"
  rm -f "$SCRIPT_DIR/role.sh.bak"

  # Add description stub
  sed -i.bak "s|^  esac|    ${role}) echo \"${desc}\" ;;\n  esac|" "$SCRIPT_DIR/role.sh"
  rm -f "$SCRIPT_DIR/role.sh.bak"

  success "Created: $role_file"
  info "Edit the file to add your content, then:"
  info "  ./role.sh apply ${role}"
}

# ── usage ─────────────────────────────────────────────────────────────────────
show_usage() {
  echo ""
  echo -e "${BOLD}${PURPLE}role.sh${RESET} — role management CLI"
  echo ""
  echo "  Usage:"
  echo "    ./role.sh apply  <role>   append role to ~/.zshrc"
  echo "    ./role.sh remove <role>   remove role from ~/.zshrc"
  echo "    ./role.sh create <name>   scaffold a new role interactively"
  echo "    ./role.sh list            show available roles"
  echo "    ./role.sh status          show which roles are active"
  echo ""
}

# ── Dispatch ──────────────────────────────────────────────────────────────────
case "${1:-}" in
  apply)  cmd_apply  "${2:-}" ;;
  remove) cmd_remove "${2:-}" ;;
  create) cmd_create "${2:-}" ;;
  list)   cmd_list ;;
  status) cmd_status ;;
  *)      show_usage ;;
esac
