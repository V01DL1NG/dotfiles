#!/usr/bin/env bash
# ============================================================================
# tmux-layout.sh — Launch named tmux workspace layouts
#
# Usage:
#   ./tmux-layout.sh <layout>            create layout in current session
#   ./tmux-layout.sh <layout> -s <name>  create in a new named session
#   ./tmux-layout.sh list                show available layouts
#
# Layouts:
#   dev      editor (left 60%) + git-log (top-right) + shell (bottom-right)
#   monitor  btop (top) + logs (bottom-left) + shell (bottom-right)
#   split2   two equal vertical panes
#   split3   three equal vertical panes
# ============================================================================
set -euo pipefail

BOLD='\033[1m'
PURPLE='\033[38;2;105;48;122m'
LAVENDER='\033[38;2;239;220;249m'
GREEN='\033[0;32m'
RESET='\033[0m'

info()    { echo -e "  ${LAVENDER}${1}${RESET}"; }
success() { echo -e "  ${GREEN}✓${RESET}  ${1}"; }
header()  { echo -e "\n${BOLD}${PURPLE}${1}${RESET}"; }

# ── Require tmux ──────────────────────────────────────────────────────────────
if ! command -v tmux >/dev/null 2>&1; then
  echo "tmux not found" >&2; exit 1
fi

# ── Parse args ────────────────────────────────────────────────────────────────
LAYOUT="${1:-}"
SESSION_NAME=""
shift || true

while [ $# -gt 0 ]; do
  case "$1" in
    -s|--session) SESSION_NAME="${2:?-s requires a session name}"; shift 2 ;;
    *) echo "Unknown option: $1" >&2; exit 1 ;;
  esac
done

# ── Helpers ───────────────────────────────────────────────────────────────────

# Run tmux in the target (new session or current)
t() { tmux "$@"; }

new_session() {
  local name="$1"
  if tmux has-session -t "$name" 2>/dev/null; then
    echo "Session '$name' already exists — attaching"
    tmux attach-session -t "$name"
    exit 0
  fi
  tmux new-session -d -s "$name"
}

send() {
  local pane="${1}"; shift
  tmux send-keys -t "$pane" "$*" Enter
}

# ── Layouts ───────────────────────────────────────────────────────────────────

layout_dev() {
  local sess="${SESSION_NAME:-dev}"
  new_session "$sess"

  # Window 0: editor layout
  tmux rename-window -t "${sess}:0" "edit"
  send "${sess}:0" "nvim ."

  # Split right 40% for git + shell
  tmux split-window -h -p 40 -t "${sess}:0"
  send "${sess}:0.1" "git log --oneline -15"

  # Split the right pane horizontally
  tmux split-window -v -t "${sess}:0.1"
  # bottom-right is a plain shell

  # Window 1: scratch terminal
  tmux new-window -t "$sess" -n "term"

  tmux select-window -t "${sess}:0"
  tmux select-pane -t "${sess}:0.0"
  tmux attach-session -t "$sess"
}

layout_monitor() {
  local sess="${SESSION_NAME:-monitor}"
  new_session "$sess"

  tmux rename-window -t "${sess}:0" "monitor"
  send "${sess}:0" "btop"

  tmux split-window -v -p 40 -t "${sess}:0"
  tmux split-window -h -t "${sess}:0.1"

  # bottom-left: follow system log
  if [ -f /var/log/system.log ]; then
    send "${sess}:0.1" "tail -f /var/log/system.log"
  elif [ -f /var/log/syslog ]; then
    send "${sess}:0.1" "tail -f /var/log/syslog"
  fi
  # bottom-right: plain shell

  tmux select-pane -t "${sess}:0.0"
  tmux attach-session -t "$sess"
}

layout_split2() {
  local sess="${SESSION_NAME:-$(tmux display-message -p '#S' 2>/dev/null || echo main)}"
  if [ -n "$SESSION_NAME" ]; then
    new_session "$sess"
    tmux split-window -h -t "${sess}:0"
    tmux attach-session -t "$sess"
  else
    tmux split-window -h
  fi
}

layout_split3() {
  local sess="${SESSION_NAME:-$(tmux display-message -p '#S' 2>/dev/null || echo main)}"
  if [ -n "$SESSION_NAME" ]; then
    new_session "$sess"
    tmux split-window -h -p 66 -t "${sess}:0"
    tmux split-window -h -p 50 -t "${sess}:0.1"
    tmux attach-session -t "$sess"
  else
    tmux split-window -h -p 66
    tmux split-window -h -p 50
  fi
}

# ── list ──────────────────────────────────────────────────────────────────────
cmd_list() {
  header "Available layouts"
  echo ""
  echo -e "  ${BOLD}${LAVENDER}dev${RESET}"
  echo -e "    ${RESET}nvim (left 60%) + git log (top-right) + shell (bottom-right)${RESET}"
  echo ""
  echo -e "  ${BOLD}${LAVENDER}monitor${RESET}"
  echo -e "    btop (top) + system log (bottom-left) + shell (bottom-right)"
  echo ""
  echo -e "  ${BOLD}${LAVENDER}split2${RESET}"
  echo -e "    two equal vertical panes"
  echo ""
  echo -e "  ${BOLD}${LAVENDER}split3${RESET}"
  echo -e "    three equal vertical panes"
  echo ""
}

# ── Dispatch ──────────────────────────────────────────────────────────────────
case "$LAYOUT" in
  dev)     layout_dev ;;
  monitor) layout_monitor ;;
  split2)  layout_split2 ;;
  split3)  layout_split3 ;;
  list|"")
    cmd_list
    if [ -z "$LAYOUT" ]; then
      echo "Usage: ./scripts/tmux-layout.sh <layout> [-s session-name]" >&2
      exit 1
    fi
    ;;
  *)
    echo "Unknown layout: $LAYOUT" >&2
    cmd_list
    exit 1
    ;;
esac
