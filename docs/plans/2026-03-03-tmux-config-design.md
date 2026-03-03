# Tmux Configuration Design

**Date:** 2026-03-03
**Status:** Approved

## Overview

Add a tmux configuration to the shell-config repo, packaged as a setup script consistent with the existing `setup.sh` and `eza-config.sh` patterns.

## Goals

- Scrollable panes (mouse + keyboard)
- Bordered panes (rounded Unicode)
- Functional clipboard integration (pbcopy/pbpaste)
- Intuitive split pane navigation
- Minimal, clean status bar

## Files

```
shell-config/
  tmux-config.sh    — setup script: installs tmux, copies config into place
  tmux.conf         — the tmux config file, committed to repo
  docs/plans/       — design docs
```

## tmux.conf Contents

### Prefix & Basics
- Prefix: `Ctrl+Space`
- 1-indexed windows and panes (easier keyboard reach)
- Zero escape-key delay (vim-friendly)

### Pane Borders
- Rounded Unicode borders on active pane, dimmed on inactive
- Minimal status bar: session name (left) | clock (right)

### Scrolling & Copy Mode
- Mouse enabled: trackpad scroll, click to focus panes
- `prefix + [` enters copy mode with vi keys
- `v` to begin selection, `y` to copy → pipes to `pbcopy`

### Split Pane Shortcuts
- `prefix + |` → vertical split
- `prefix + -` → horizontal split
- `prefix + h/j/k/l` → navigate panes (vim-style)

### Quality of Life
- `prefix + r` → reload config in place
- 10,000 line scrollback buffer
- `screen-256color` terminal for full color support

## Setup Script Behavior (`tmux-config.sh`)

1. Install tmux via Homebrew if not already installed
2. Back up existing `~/.tmux.conf` if present
3. Copy `tmux.conf` from repo to `~/.tmux.conf`
4. Print instructions to source/reload

Idempotent — safe to run multiple times.

## Out of Scope

- Plugin manager (TPM) — not needed for these features
- Session persistence (tmux-resurrect) — not requested
- Git branch in status bar — covered by oh-my-posh prompt
