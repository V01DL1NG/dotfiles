# shell-config

Dotfiles and setup scripts for macOS terminal environment. Each config has an idempotent setup script that installs dependencies via Homebrew, backs up existing configs, and copies files into place.

## Quick Start

```bash
# Clone and run any setup script
git clone <repo-url> ~/code/shell-config
cd ~/code/shell-config

./setup.sh          # oh-my-posh prompt
./eza-config.sh     # eza (modern ls)
./tmux-config.sh    # tmux + now-playing
./zshrc-config.sh   # zsh config
./nvim-config.sh    # neovim + LSP servers
./tools-config.sh   # fzf, bat, lazygit, btop
./git-config.sh     # gitconfig + delta
```

## What's Included

### Zsh (`zshrc` / `zshrc-config.sh`)

| Feature | Details |
|---------|---------|
| Vi mode | `Esc` for normal mode, cursor changes shape |
| History | 50k lines, deduplicated, shared across sessions |
| Completion | Arrow-key menu, case-insensitive |
| Navigation | `autocd`, `autopushd` with directory stack |
| fzf | `Ctrl-R` history search, `Ctrl-T` file picker with preview |

**Aliases:**

| Alias | Command |
|-------|---------|
| `ls` / `ll` / `lt` | `eza` with icons, tree view |
| `cat` / `catp` | `bat` with syntax highlighting |
| `rawcat` | Original `cat` (no highlighting) |
| `lg` | `lazygit` |
| `top` | `btop` |
| `py` | `python3` |
| `cls` | `clear` |
| `whatsmyip` | Show public IP |

**Functions:**

| Function | Description |
|----------|-------------|
| `meminfo` | Memory usage via native macOS `vm_stat` |
| `jamflogs` | Tail last 100 lines of Jamf log |
| `copy` | Pipe stdout to clipboard (`pbcopy`) |

### Neovim (`init.lua` / `nvim-config.sh`)

Plugin manager: **lazy.nvim** (auto-bootstraps on first launch)

| Category | Plugins |
|----------|---------|
| Theme | Gruvbox (dark) |
| Status bar | Lualine with git, diagnostics, word count |
| File explorer | nvim-tree |
| Fuzzy finder | Telescope (`<Space>ff`, `<Space>fg`, `<Space>fb`) |
| Syntax | Treesitter (auto-install) |
| LSP | lua_ls, pyright, ts_ls with nvim-cmp completion |
| Motion | Leap.nvim |
| Git | Fugitive + Gitsigns |
| Editing | vim-commentary, vim-surround, vim-repeat |
| Visual | indent-blankline, vim-illuminate |

**Key mappings (leader = Space):**

| Key | Action |
|-----|--------|
| `<Space>w` | Save |
| `<Space>q` | Quit |
| `<Space>n` | Toggle file explorer |
| `<Space>ff` | Find files |
| `<Space>fg` | Live grep |
| `<Space>fb` | Switch buffer |
| `gd` | Go to definition (LSP) |
| `gr` | Find references (LSP) |
| `K` | Hover docs (LSP) |
| `<Space>rn` | Rename symbol (LSP) |
| `<Space>ca` | Code action (LSP) |
| `[d` / `]d` | Previous/next diagnostic |

### Tmux (`tmux.conf` / `tmux-config.sh`)

Themed to match the **velvet** oh-my-posh prompt (purple/violet/lavender).

| Setting | Value |
|---------|-------|
| Prefix | `Ctrl+a` |
| Mouse | Enabled |
| Copy mode | Vi keys, `y` copies to clipboard |
| Scrollback | 10,000 lines |
| Status bar | Powerline segments, now-playing + clock |
| Pane borders | Double-line, violet active, labeled |

**Keybindings:**

| Key | Action |
|-----|--------|
| `Ctrl+a \|` | Split vertical |
| `Ctrl+a -` | Split horizontal |
| `Ctrl+a h/j/k/l` | Navigate panes (vim-style) |
| `Ctrl+a [` | Enter copy mode |
| `Ctrl+a r` | Reload config |

### Git (`gitconfig` / `git-config.sh`)

| Feature | Details |
|---------|---------|
| Diff pager | Delta with side-by-side, syntax highlighting, gruvbox theme |
| Pull strategy | Rebase (cleaner history) |
| Push | Auto-sets upstream remote |
| Fetch | Auto-prunes stale branches |
| Rerere | Remembers conflict resolutions |
| Diff algorithm | Histogram |
| Conflict style | zdiff3 |

**Aliases:**

| Alias | Command |
|-------|---------|
| `git lg` | Pretty log graph |
| `git st` | Short status |
| `git amend` | Amend last commit (keep message) |
| `git undo` | Undo last commit (keep changes) |
| `git branches` | Branches sorted by recent activity |
| `git last` | Show last commit with stats |

### Tools (`tools-config.sh`)

Installs via Homebrew:

| Tool | Purpose |
|------|---------|
| **fzf** | Fuzzy finder (history, files, directories) |
| **bat** | Syntax-highlighted `cat` replacement |
| **lazygit** | Terminal UI for git |
| **btop** | System monitor |

### Theme

All configs use a consistent **velvet/sakura** color palette:

| Color | Hex | Usage |
|-------|-----|-------|
| Near black | `#0E050F` | iTerm background |
| Deep purple | `#170B3B` | Tmux status bar bg |
| Dark violet | `#341948` | Tmux borders, accents |
| Purple | `#4c1f5e` | Active elements |
| Bright violet | `#69307A` | Active borders, highlights |
| Lavender | `#EFDCF9` | Foreground text |

**Recommended iTerm colors:** Background `#0E050F`, Foreground `#EFDCF9`, Cursor `#69307A`, Selection `#341948`

## File Structure

```
shell-config/
├── setup.sh          # oh-my-posh prompt setup
├── eza-config.sh     # eza aliases setup
├── tmux-config.sh    # tmux setup
├── tmux.conf         # tmux config source
├── now-playing.sh    # now-playing script for tmux status bar
├── zshrc-config.sh   # zsh setup
├── zshrc             # zsh config source
├── nvim-config.sh    # neovim setup
├── init.lua          # neovim config source
├── tools-config.sh   # fzf, bat, lazygit, btop setup
├── git-config.sh     # git setup
├── gitconfig         # git config source
└── README.md
```
