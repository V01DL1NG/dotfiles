# Shell Config Handbook

A practical guide to using every tool in your terminal setup.

---

## Zsh

### Vi Mode

You're always in one of two modes:

- **Insert mode** (beam cursor) — type normally
- **Normal mode** (block cursor) — press `Esc` to enter

Normal mode commands:

```
h/l         move left/right
b/w         jump back/forward one word
0/$         jump to start/end of line
x           delete character
dw          delete word
dd          clear entire line
ci"         change inside quotes
i/a         back to insert mode (at/after cursor)
I/A         insert at start / append at end
```

### History

```
Up/Down     search history matching anywhere in the command (not just prefix)
Ctrl-R      open atuin — full history TUI with timestamps, exit codes, directory
```

Prefix a command with a space to keep it out of history.

Inside atuin (`Ctrl-R`):

```
Type        filter results
Ctrl-R      toggle scope: global history vs current directory only
Ctrl-D      delete entry
Enter       run selected command
Esc         cancel
```

### Directory Navigation

```
..              go up one directory (autocd)
~/code          cd without typing cd (autocd)
cd -            toggle between last two directories
cd -2           jump to 2nd directory in stack (autopushd)
dirs -v         show full directory stack with indices
```

### zoxide (smart cd)

zoxide learns which directories you visit most often. After a few uses it lets you jump anywhere with a partial name:

```
z proj          cd to ~/code/projects (or wherever you go most)
z dot conf      jumps to the best match containing "dot" and "conf"
zi              interactive picker — fzf over your frecency list
```

After a few days you'll stop thinking about paths entirely.

### Autosuggestions

As you type, you'll see ghost text from your history. Press:

```
Right arrow     accept the full suggestion
Ctrl-E          accept the full suggestion (alternative)
```

### Syntax Highlighting

Commands are colored as you type:

- **Bold lavender** — valid command/alias
- **Violet underline** — unknown command (typo?)
- **Cyan** — quoted strings
- **Yellow** — globs (`*.txt`)

---

## zoxide (smart cd)

zoxide tracks how often and how recently you visit each directory (frecency). The more you use a directory, the easier it is to jump to:

```bash
z dotfiles          # jumps to ~/code/dotfiles
z code proj         # matches a dir containing both "code" and "proj"
zi                  # interactive: fzf picker over your history
```

You still use `cd` normally — zoxide learns from every directory change.

---

## direnv

Place a `.envrc` file in any project directory — it loads automatically on `cd` and unloads when you leave.

```bash
# .envrc example
export DATABASE_URL=postgres://localhost/mydb
export API_KEY=dev-key-123
export PATH="$PWD/bin:$PATH"
layout python3          # auto-activate a .venv virtualenv
```

```
direnv allow    permit the current .envrc (required on first use or after edits)
direnv deny     block the current .envrc
direnv edit     open .envrc in $EDITOR, then auto-allow on save
direnv status   show what is currently loaded
```

Never manually `source .env` again. When you `cd` out of the directory, the variables are unloaded automatically.

---

## fzf (Fuzzy Finder)

```
Ctrl-T      fuzzy find files (fd-powered, bat preview on the right)
Alt-C       fuzzy cd into a directory (Option+C on Mac)
```

`Ctrl-R` is now handled by **atuin** (see History above) for a richer experience.

Inside fzf:

```
Type        filter results as you type
Up/Down     navigate results
Enter       select
Esc         cancel
Tab         multi-select (where supported)
```

`Ctrl-T` uses `fd` under the hood — it respects `.gitignore` and is much faster than `find` on large repos.

---

## bat (cat replacement)

```
cat file.py         syntax-highlighted output
catp file.py        same but with a pager (for long files)
rawcat file.py      original cat (for piping to grep, wc, etc.)
man git             man pages are now colored via bat
```

bat auto-detects the language from the file extension. The theme matches gruvbox-dark.

---

## eza (ls replacement)

```
ls          file list with icons
ll          detailed list (permissions, size, dates)
lt          tree view (2 levels deep)
```

All commands show file type icons. `ll` shows git status per file.

---

## lazygit

Launch with `lg` in any git repo.

```
Panel navigation:
  1-5         switch panels (files, branches, commits, stash, status)
  h/l         switch panel sections
  j/k         navigate within a panel

Common actions:
  Space       stage/unstage a file
  c           commit staged changes
  p           push
  P           pull
  b           checkout branch
  n           new branch
  /           filter/search
  ?           show all keybindings
  q           quit
```

Stage individual lines: select a file, press `Enter` to see the diff, then `Space` on specific lines/hunks.

---

## btop (system monitor)

Launch with `top`.

```
Navigation:
  Up/Down     select process
  Left/Right  change sort column
  Enter       show process details
  Tab         cycle between CPU, memory, network, disk views

Actions:
  k           kill selected process
  f           filter processes
  /           search processes
  Esc         clear filter/search
  q           quit
```

For a quick memory check without opening btop, use `meminfo`.

---

## Git

### Delta Diffs

Every `git diff`, `git show`, `git log -p` now shows side-by-side syntax-highlighted diffs automatically. Navigate with:

```
n/N         jump to next/previous file in diff
q           quit the pager
/pattern    search within the diff
```

### Aliases

```
git st          short status with branch info
git lg          pretty commit graph of all branches
git last        details of the last commit
git branches    branches sorted by most recently used
git amend       add staged changes to last commit (keep message)
git undo        undo last commit, keep all changes staged
```

### Workflow Tips

```bash
# Quick save
git add file.py
git commit -m "fix: resolve login bug"

# Oops, forgot a file
git add forgotten.py
git amend

# That commit was wrong, undo it
git undo

# See what happened recently
git lg

# Which branches have I been working on?
git branches
```

`git pull` rebases by default (no merge commits). `git push` auto-sets the upstream (no `-u origin branch` needed).

### Rerere

If you resolve a merge conflict, git remembers the resolution. Next time the same conflict appears, it's auto-resolved.

---

## Tmux

### Starting and Sessions

```bash
tmux                    start new session
tmux new -s work        start named session
tmux ls                 list sessions
tmux attach -t work     reattach to session
tmux kill-session -t work
```

All commands below use the prefix `Ctrl+a` (press Ctrl+a, release, then the key).

### Windows (tabs)

```
Ctrl+a c        create new window
Ctrl+a ,        rename current window
Ctrl+a n/p      next/previous window
Ctrl+a 1-9      go to window by number
Ctrl+a &        close window
```

### Panes (splits)

```
Ctrl+a |        split vertically (side by side)
Ctrl+a -        split horizontally (top/bottom)
Ctrl+a h/j/k/l  navigate panes (vim-style)
Ctrl+a x        close current pane
Ctrl+a z        toggle pane zoom (fullscreen a pane)
Ctrl+a Space    cycle pane layouts
```

### Copy Mode

```
Ctrl+a [        enter copy mode (scroll/select)
v               start selection (in copy mode)
y               copy selection to clipboard
q               exit copy mode
```

You can also select text with the mouse — it auto-copies to clipboard.

### Session Persistence

Sessions survive terminal crashes and reboots:

```
Ctrl+a Ctrl+s   save all sessions (resurrect)
Ctrl+a Ctrl+r   restore sessions (resurrect)
```

Continuum auto-saves every 15 minutes and auto-restores when tmux starts.

### Reload Config

```
Ctrl+a r        reload tmux.conf (see changes immediately)
```

---

## Neovim

### Getting Around

```
Leader key = Space

Space ff        find files (fuzzy)
Space fg        live grep across project
Space fb        switch between open buffers
Space fh        search help docs
Space n         toggle file explorer (nvim-tree)
Space           (hold) which-key popup shows all bindings
```

### File Explorer (nvim-tree)

```
Space n         toggle sidebar
Enter           open file
a               create new file/directory
d               delete
r               rename
c/p             copy/paste
R               refresh
```

### LSP (code intelligence)

These work when an LSP server is active (Lua, Python, TypeScript):

```
gd              go to definition
gr              find all references
K               hover docs (show type/signature)
Space rn        rename symbol across project
Space ca        code action (quick fixes, refactors)
[d / ]d         previous/next diagnostic (error/warning)
```

### Completion

Completion pops up automatically. Navigate with:

```
Ctrl-Space      trigger completion manually
Ctrl-N/Ctrl-P   next/previous suggestion
Enter           accept suggestion
Ctrl-E          dismiss
Ctrl-B/Ctrl-F   scroll docs in completion popup
```

### Editing

```
Space w         save file
Space q         quit
Space Q         force quit (discard changes)
Space /         toggle comment (works in visual mode too)
< / >           indent/dedent in visual mode (stays selected)

Leap (quick jump):
s{char}{char}   jump to any two-character match on screen
```

### Auto-pairs

Brackets and quotes auto-close:

```
Type (          get ()  with cursor inside
Type "          get ""  with cursor inside
Type {          get {}  with cursor inside
Backspace       deletes both if empty pair
```

### Git Hunks (gitsigns)

Change indicators appear in the gutter (`+` added, `~` changed, `-` deleted). Navigate and act on them without leaving the file:

```
]c              next hunk
[c              previous hunk
Space hs        stage hunk under cursor
Space hr        reset hunk (discard changes)
Space hb        inline git blame for current line
Space hd        diff this file against HEAD
```

Tip: use `Space hs` to stage individual hunks, then commit — a cleaner alternative to `git add -p` without leaving nvim.

### Mason (LSP manager)

```
:Mason          open Mason UI
                i = install, u = update, X = uninstall
```

Mason auto-installs lua_ls, pyright, and ts_ls on first launch.

---

## SSH

### Connection Multiplexing

Your first SSH to a host opens a connection. Subsequent SSH/SCP/Git operations to the same host reuse it — instant connections with no re-authentication.

```bash
ssh user@host           first connection (normal)
ssh user@host           instant (reuses connection)
scp file user@host:~    instant (reuses connection)
```

Connections persist for 10 minutes after the last use.

### Keychain

SSH key passphrases are stored in macOS Keychain. You enter the passphrase once, then never again (even across reboots).

### Host Aliases

Add shortcuts in `~/.ssh/config`:

```
Host myserver
    HostName 192.168.1.100
    User admin
    Port 2222
```

Then just `ssh myserver` instead of `ssh -p 2222 admin@192.168.1.100`.

---

## iTerm2

Two dynamic profiles are installed:

**Velvet** — solid deep-purple background, full velvet/sakura palette, FiraCode Nerd Font.

**Velvet Glass** — same colors, 20% transparent background with blur. Good for referencing docs behind the window.

To activate a profile:
1. Preferences > Profiles
2. Select the profile
3. Other Actions > Set as Default

Both profiles inherit their colors from Velvet, so changing a color in Velvet automatically updates Velvet Glass.

---

## Brewfile

Recreate your full tool setup on a new Mac:

```bash
brew bundle install --file=~/code/dotfiles/Brewfile
```

Update the Brewfile after installing new packages:

```bash
brew bundle dump --file=~/code/dotfiles/Brewfile --force
```

---

## Profiles

### Choosing a profile

Run from the repo root and pick interactively, or pass the name directly:

```bash
./choose-profile.sh              # interactive menu
./choose-profile.sh velvet       # oh-my-posh, original velvet theme
./choose-profile.sh p10k-velvet  # Powerlevel10k, same velvet colors
```

Files are **copied** to your home directory — not symlinked. Edit them freely; your repo copy stays untouched.

| Profile | Prompt | Theme file |
|---------|--------|------------|
| `velvet` | oh-my-posh | `~/oh-my-posh/velvet.omp.json` |
| `p10k-velvet` | Powerlevel10k | `~/.p10k.zsh` |

After switching profiles, run `source ~/.zshrc` or open a new terminal.

**p10k-velvet tip:** run `p10k configure` at any time to interactively tweak the prompt — it rewrites `~/.p10k.zsh` in place.

---

## Profile Containers

A container is a single portable `.profile.sh` file with your config files embedded. Send it to a teammate and they can rebuild your exact setup with one command.

### Creating containers

```bash
# Pack a built-in profile
./profile.sh pack velvet -o velvet.profile.sh
./profile.sh pack p10k-velvet --name "Team Default" -o team.profile.sh

# Export your own live config (captures your edits too)
./profile.sh export --name "My Setup" --desc "Personal tweaks" -o mine.profile.sh

# List available built-in profiles
./profile.sh list
```

### Installing a container

The recipient doesn't need this repo at all:

```bash
bash team.profile.sh             # install
bash team.profile.sh --info      # preview: show what it contains without installing
```

The container will:
1. Check for the required prompt engine (oh-my-posh or Powerlevel10k) and `brew install` it if missing
2. Back up any existing configs with a timestamp before overwriting
3. Copy files locally — no symlinks
4. Skip iTerm2 profiles gracefully if iTerm2 isn't installed

### What gets captured

| File | When included |
|------|--------------|
| `~/.zshrc` | Always |
| `~/.p10k.zsh` | p10k profiles |
| `~/oh-my-posh/<theme>.omp.json` | oh-my-posh profiles |
| `~/Library/…/iTerm2/DynamicProfiles/*.json` | When iTerm2 is installed |

---

## Quick Reference Card

| Task | Command |
|------|---------|
| Switch shell profile | `./choose-profile.sh` |
| Share your config | `./profile.sh export -o mine.profile.sh` |
| Install someone's container | `bash their-setup.profile.sh` |
| Jump to a recent directory | `z <partial-name>` |
| Find a past command | `Ctrl-R` (atuin) |
| Find a file | `Ctrl-T` or `Space ff` (in nvim) |
| Search file contents | `Space fg` (in nvim) |
| Load project env vars | `direnv allow` (once per `.envrc`) |
| Git status | `git st` or `lg` (lazygit) |
| Stage a single hunk | `Space hs` (in nvim) |
| Blame current line | `Space hb` (in nvim) |
| System resources | `top` (btop) or `meminfo` |
| Split terminal | `Ctrl+a \|` or `Ctrl+a -` |
| Save tmux session | `Ctrl+a Ctrl+s` |
| Jump to definition | `gd` (in nvim) |
| Rename symbol | `Space rn` (in nvim) |
| See keybindings | Hold `Space` (in nvim) |
