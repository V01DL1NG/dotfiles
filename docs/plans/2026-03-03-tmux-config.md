# Tmux Configuration Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Add a `tmux.conf` and `tmux-config.sh` setup script to the shell-config repo that installs a minimal, functional tmux config on macOS.

**Architecture:** A flat `tmux.conf` (no plugin manager) is committed to the repo. A `tmux-config.sh` script installs tmux via Homebrew if missing, backs up any existing config, and copies `tmux.conf` to `~/.tmux.conf`. Follows the same idempotent setup-script pattern as `setup.sh` and `eza-config.sh`.

**Tech Stack:** Bash, tmux, Homebrew, macOS pbcopy/pbpaste

---

### Task 1: Create `tmux.conf`

**Files:**
- Create: `tmux.conf`

**Step 1: Create the file**

Create `/Users/kaufmada/code/shell-config/tmux.conf` with the following content:

```bash
# =============================================================================
# Prefix
# =============================================================================
unbind C-b
set -g prefix C-Space
bind C-Space send-prefix

# =============================================================================
# General
# =============================================================================
set -g default-terminal "screen-256color"
set -s escape-time 0           # no delay on Escape (vim-friendly)
set -g history-limit 10000     # scrollback buffer
set -g base-index 1            # 1-indexed windows
setw -g pane-base-index 1      # 1-indexed panes
set -g renumber-windows on     # renumber on close

# =============================================================================
# Mouse
# =============================================================================
set -g mouse on

# =============================================================================
# Status bar (minimal)
# =============================================================================
set -g status-style "bg=default,fg=white"
set -g status-left "#[bold]#S "
set -g status-left-length 20
set -g status-right "%H:%M"
set -g status-right-length 10
set -g status-justify left
setw -g window-status-current-style "bold,fg=cyan"

# =============================================================================
# Pane borders
# =============================================================================
set -g pane-border-style "fg=colour238"
set -g pane-active-border-style "fg=cyan"
set -g pane-border-lines rounded

# =============================================================================
# Split panes (intuitive keys)
# =============================================================================
unbind '"'
unbind %
bind | split-window -h -c "#{pane_current_path}"
bind - split-window -v -c "#{pane_current_path}"

# =============================================================================
# Pane navigation (vim-style)
# =============================================================================
bind h select-pane -L
bind j select-pane -D
bind k select-pane -U
bind l select-pane -R

# =============================================================================
# Reload config
# =============================================================================
bind r source-file ~/.tmux.conf \; display "Config reloaded!"

# =============================================================================
# Copy mode (vi keys + pbcopy)
# =============================================================================
setw -g mode-keys vi
bind [ copy-mode
bind -T copy-mode-vi v send -X begin-selection
bind -T copy-mode-vi y send -X copy-pipe-and-cancel "pbcopy"
bind -T copy-mode-vi MouseDragEnd1Pane send -X copy-pipe-and-cancel "pbcopy"
```

**Step 2: Verify the file exists and looks right**

```bash
cat /Users/kaufmada/code/shell-config/tmux.conf
```

Expected: file prints cleanly with all sections present.

---

### Task 2: Create `tmux-config.sh`

**Files:**
- Create: `tmux-config.sh`

**Step 1: Create the script**

Create `/Users/kaufmada/code/shell-config/tmux-config.sh` with the following content:

```bash
#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TMUX_CONF="$HOME/.tmux.conf"
BACKUP="$TMUX_CONF.backup.$(date +%Y%m%d%H%M%S)"

# Install tmux via Homebrew if missing
if ! command -v tmux >/dev/null 2>&1; then
  if command -v brew >/dev/null 2>&1; then
    echo "Installing tmux via Homebrew..."
    brew install tmux
  else
    echo "Error: Homebrew not found. Please install tmux manually." >&2
    exit 1
  fi
else
  echo "tmux already installed: $(tmux -V)"
fi

# Back up existing config
if [ -f "$TMUX_CONF" ]; then
  echo "Backing up $TMUX_CONF to $BACKUP"
  cp "$TMUX_CONF" "$BACKUP"
fi

# Copy config into place
echo "Installing tmux.conf to $TMUX_CONF"
cp "$SCRIPT_DIR/tmux.conf" "$TMUX_CONF"

echo ""
echo "Done. To apply:"
echo "  - In a running tmux session: press Ctrl+Space then r"
echo "  - Or start a fresh tmux session: tmux"
```

**Step 2: Make it executable**

```bash
chmod +x /Users/kaufmada/code/shell-config/tmux-config.sh
```

**Step 3: Verify the script is executable**

```bash
ls -l /Users/kaufmada/code/shell-config/tmux-config.sh
```

Expected: `-rwxr-xr-x` permissions.

---

### Task 3: Smoke-test the setup script

**Step 1: Do a dry-run check — confirm tmux is installed (or would be)**

```bash
command -v tmux && tmux -V
```

Expected: prints tmux version, e.g. `tmux 3.x`

**Step 2: Run the setup script**

```bash
bash /Users/kaufmada/code/shell-config/tmux-config.sh
```

Expected output (approximately):
```
tmux already installed: tmux 3.x
Installing tmux.conf to /Users/kaufmada/.tmux.conf
Done. To apply: ...
```

**Step 3: Verify config landed in the right place**

```bash
cat ~/.tmux.conf | head -5
```

Expected: prints `# Prefix` section header.

**Step 4: Verify config loads without errors in tmux**

```bash
tmux new-session -d -s test-config 2>&1 && \
  tmux send-keys -t test-config "tmux source ~/.tmux.conf && echo OK" Enter && \
  sleep 1 && \
  tmux capture-pane -t test-config -p && \
  tmux kill-session -t test-config
```

Expected: output contains `OK` with no error messages.

---

### Task 4: Initialize git and commit

**Step 1: Initialize git repo**

```bash
cd /Users/kaufmada/code/shell-config && git init
```

**Step 2: Add all files and make initial commit**

```bash
git add setup.sh eza-config.sh tmux.conf tmux-config.sh docs/
git commit -m "feat: add tmux config with clipboard, borders, and pane navigation"
```

Expected: commit succeeds, lists all files.
