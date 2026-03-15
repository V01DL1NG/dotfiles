# dotfiles

Dotfiles and setup scripts for macOS terminal environment. Each config has an idempotent setup script that installs dependencies via Homebrew, backs up any existing config, and symlinks the file from this repo — so editing the live config is editing the repo directly.

## Quick Start

**New Mac — one command:**
```bash
curl -fsSL https://raw.githubusercontent.com/V01DL1NG/dotfiles/master/bootstrap.sh | bash
```

**Already have the repo:**
```bash
# Pick a shell profile — files are copied locally, no symlinks
./choose-profile.sh

# Install tools, git, tmux, nvim, ssh
./install-all.sh

# Check your setup health at any time
./doctor.sh
```

Or run individual setup scripts:

```bash
./setup.sh          # oh-my-posh prompt
./eza-config.sh     # eza (modern ls)
./tools-config.sh   # fzf, bat, lazygit, btop, zsh plugins + smart tools
./git-config.sh     # gitconfig + delta
./tmux-config.sh    # tmux + now-playing
./nvim-config.sh    # neovim + LSP servers
./zshrc-config.sh   # zsh config (symlinked)
./iterm-config.sh   # iTerm2 velvet theme
./ssh-config.sh     # SSH config
```

## Profiles

The shell prompt and zsh config come in two flavours. Each installs local file copies — no symlinks — so users can edit freely without touching the repo.

### Choosing a profile

```bash
./choose-profile.sh            # interactive picker
./choose-profile.sh velvet     # install directly
./choose-profile.sh p10k-velvet
```

| Profile | Prompt engine | Palette |
|---------|--------------|---------|
| **velvet** | oh-my-posh | velvet/sakura — deep purple to lavender |
| **p10k-velvet** | Powerlevel10k | same velvet palette, instant prompt, vi-mode `❯`/`❮` |
| **catppuccin** | Powerlevel10k | Catppuccin Mocha — mauve, blue, green accents |
| **minimal** | none (plain zsh) | velvet colors, no engine required, server-friendly |

All profiles share the same aliases, plugins, and smart tools. Only the prompt and colors differ.

### Machine roles

Roles are additive snippets that layer on top of any profile. Stack as many as you like:

```bash
./role.sh apply work      # add corp proxy stubs + git identity reminder
./role.sh apply personal  # add project shortcuts, daily note helper
./role.sh apply server    # add GUI tool fallbacks, larger history, ASCII prompt option
./role.sh status          # see which roles are active
./role.sh remove work     # cleanly remove a role from ~/.zshrc
```

Each role appends a clearly-marked block to `~/.zshrc` that can be removed without touching anything else.

### Profile containers

A profile container is a single self-executing `.profile.sh` file with all config files base64-embedded. Share one file and anyone can rebuild your exact setup — no repo required.

```bash
# Pack a built-in profile into a shareable container
./profile.sh pack velvet -o velvet.profile.sh
./profile.sh pack p10k-velvet --name "Team Setup" -o team.profile.sh

# Export your own live config (after personal edits)
./profile.sh export --name "My Setup" --desc "Personal tweaks" -o mine.profile.sh

# Inspect before installing
./profile.sh info team.profile.sh

# Install from a container (no repo needed — fully self-contained)
bash team.profile.sh
bash team.profile.sh --info   # preview only
```

What `profile.sh` captures in a container:

- `~/.zshrc`
- `~/.p10k.zsh` (p10k profiles) or the `.omp.json` theme (oh-my-posh profiles)
- All iTerm2 DynamicProfiles (skipped gracefully if iTerm2 isn't installed)

The container auto-installs missing tools (oh-my-posh or powerlevel10k via Homebrew) and backs up any existing configs with a timestamp before overwriting.

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

oh-my-posh with a custom velvet theme. `setup.sh` symlinks `velvet.omp.json` from the repo to `~/oh-my-posh/velvet.omp.json`. The `zshrc` also has a curl fallback that downloads it automatically if the file is missing when the shell starts.

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
├── bootstrap.sh                    # curl-installable new Mac setup
├── choose-profile.sh               # interactive profile picker (copies files locally)
├── profile.sh                      # profile container manager (export / pack / import)
├── role.sh                         # machine role manager (apply / remove / list / status)
├── doctor.sh                       # health check — tools, configs, git, fonts, roles
│
├── profiles/                       # built-in profiles (source of truth)
│   ├── velvet/                     # oh-my-posh + velvet/sakura theme
│   │   ├── zshrc
│   │   ├── velvet.omp.json
│   │   └── iterm.json              # Velvet + Velvet Glass iTerm2 profiles
│   ├── p10k-velvet/                # Powerlevel10k + velvet color blend
│   │   ├── zshrc
│   │   ├── .p10k.zsh
│   │   └── iterm.json              # P10k Velvet + P10k Velvet Glass iTerm2 profiles
│   ├── catppuccin/                 # Powerlevel10k + Catppuccin Mocha
│   │   ├── zshrc
│   │   ├── .p10k.zsh
│   │   └── iterm.json              # Catppuccin Mocha + Catppuccin Mocha Glass
│   └── minimal/                    # plain zsh prompt, no engine
│       └── zshrc
│
├── roles/                          # machine role snippets (appended to ~/.zshrc)
│   ├── work.zsh                    # corp proxy stubs, git identity reminder
│   ├── personal.zsh                # project shortcuts, daily note helper
│   └── server.zsh                  # GUI tool fallbacks, larger history
│
├── install-all.sh                  # one-command full setup (tools, git, tmux, nvim, ssh)
├── setup.sh                        # oh-my-posh prompt setup (legacy symlink path)
├── eza-config.sh                   # eza aliases setup
├── tools-config.sh                 # all terminal tools
├── git-config.sh                   # git setup
├── gitconfig                       # git config source
├── tmux-config.sh                  # tmux setup
├── tmux.conf                       # tmux config source
├── now-playing.sh                  # now-playing script for tmux status bar
├── nvim-config.sh                  # neovim setup
├── init.lua                        # neovim config source
├── zshrc-config.sh                 # zsh setup (symlink path)
├── zshrc                           # zsh config source (symlink path)
├── iterm-config.sh                 # iTerm2 setup (symlink path)
├── velvet.iterm2profile.json       # iTerm2 Velvet + Velvet Glass profiles (symlink path)
├── velvet.omp.json                 # oh-my-posh velvet theme (symlink path)
├── ssh-config.sh                   # SSH setup
├── ssh_config                      # SSH config source
├── Brewfile                        # all Homebrew packages
├── test.sh                         # test suite — verifies tools, symlinks, plugins
├── HANDBOOK.md                     # practical usage guide for every tool
└── README.md
```
