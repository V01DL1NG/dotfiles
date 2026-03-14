# dotfiles

Dotfiles and setup scripts for macOS terminal environment. Each config has an idempotent setup script that installs dependencies via Homebrew, backs up existing configs, and copies files into place.

## Quick Start

```bash
# Clone and install everything at once
git clone https://github.com/V01DL1NG/dotfiles.git ~/code/dotfiles
cd ~/code/dotfiles
./install-all.sh

# Or run individual setup scripts
./setup.sh          # oh-my-posh prompt
./eza-config.sh     # eza (modern ls)
./tools-config.sh   # fzf, bat, lazygit, btop, zsh plugins + smart tools
./git-config.sh     # gitconfig + delta
./tmux-config.sh    # tmux + now-playing
./nvim-config.sh    # neovim + LSP servers
./zshrc-config.sh   # zsh config
./iterm-config.sh   # iTerm2 velvet theme
./ssh-config.sh     # SSH config
```

## What's Included

### Zsh (`zshrc` / `zshrc-config.sh`)

| Feature | Details |
|---------|---------|
| Vi mode | `Esc` for normal mode, cursor changes shape |
| History | 50k lines, deduplicated, shared across sessions |
| History search | `Up/Down` matches anywhere in command; `Ctrl-R` opens atuin TUI |
| Completion | Arrow-key menu, case-insensitive, cached dump (fast starts) |
| Navigation | `autocd`, `autopushd`, zoxide smart jump (`z <partial>`) |
| fzf | `Ctrl-T` file picker (fd-powered, bat preview), `Alt-C` dir picker |
| Autosuggestions | Ghost text from history as you type |
| Syntax highlighting | Commands colored in velvet theme palette |
| direnv | Auto-loads/unloads `.envrc` on `cd` |

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
| LSP | Mason auto-installs lua_ls, pyright, ts_ls with nvim-cmp completion |
| Keybinding help | which-key popup on `<Space>` |
| Auto-pairs | Auto-close brackets, quotes, parentheses |
| Motion | Leap.nvim (`s{char}{char}`) |
| Git | Fugitive + Gitsigns (hunk staging, blame, diff in-buffer) |
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
| `]c` / `[c` | Next/previous git hunk |
| `<Space>hs` | Stage hunk |
| `<Space>hr` | Reset hunk |
| `<Space>hb` | Blame line |
| `<Space>hd` | Diff this file |

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
| `Ctrl+a Ctrl+s` | Save session (resurrect) |
| `Ctrl+a Ctrl+r` | Restore session (resurrect) |

**Plugins:** tmux-resurrect (session persistence) + tmux-continuum (auto-save every 15min). TPM auto-bootstraps on first load.

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
| **fzf** | Fuzzy finder (`Ctrl-T` files, `Alt-C` dirs) |
| **fd** | Fast, gitignore-aware find — powers fzf file search |
| **bat** | Syntax-highlighted `cat` replacement |
| **lazygit** | Terminal UI for git |
| **btop** | System monitor |
| **zoxide** | Smart `cd` — learns your most-visited dirs (`z <partial>`) |
| **atuin** | Shell history database — `Ctrl-R` with timestamps, exit codes, directory context |
| **direnv** | Auto-loads `.envrc` per directory |
| **zsh-autosuggestions** | Ghost text from history |
| **zsh-syntax-highlighting** | Command coloring (velvet theme) |
| **zsh-history-substring-search** | Up/Down matches anywhere in command, not just prefix |

### iTerm2 (`velvet.iterm2profile.json` / `iterm-config.sh`)

Two dynamic profiles installed automatically:

| Profile | Description |
|---------|-------------|
| **Velvet** | Solid background, full velvet/sakura palette, FiraCode Nerd Font |
| **Velvet Glass** | Same colors with 20% transparency and background blur |

To activate a profile: Preferences > Profiles > select profile > Other Actions > Set as Default.

### Prompt (`velvet.omp.json` / `setup.sh`)

oh-my-posh with a custom velvet theme. The `zshrc` auto-downloads `velvet.omp.json` from this repo on first run if the file is missing — no manual setup needed.

Segments: OS icon → path → git branch/status/stash → execution time → exit status. Right side shows active language runtime versions (Python, Go, Node, Ruby, Java).

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

## File Structure

```
dotfiles/
├── install-all.sh                  # one-command full setup
├── setup.sh                        # oh-my-posh prompt setup
├── eza-config.sh                   # eza aliases setup
├── tools-config.sh                 # all terminal tools
├── git-config.sh                   # git setup
├── gitconfig                       # git config source
├── tmux-config.sh                  # tmux setup
├── tmux.conf                       # tmux config source
├── now-playing.sh                  # now-playing script for tmux status bar
├── nvim-config.sh                  # neovim setup
├── init.lua                        # neovim config source
├── zshrc-config.sh                 # zsh setup
├── zshrc                           # zsh config source
├── iterm-config.sh                 # iTerm2 setup
├── velvet.iterm2profile.json       # iTerm2 Velvet + Velvet Glass profiles
├── velvet.omp.json                 # oh-my-posh velvet theme
├── ssh-config.sh                   # SSH setup
├── ssh_config                      # SSH config source
├── Brewfile                        # all Homebrew packages
├── HANDBOOK.md                     # practical usage guide for every tool
└── README.md
```
