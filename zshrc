# ===========================================================================
# ZSH OPTIONS
# ===========================================================================

# Directory navigation
setopt autocd              # type directory name to cd into it
setopt autopushd           # cd pushes to directory stack
setopt pushdignoredups     # no duplicates in directory stack
setopt pushdsilent         # don't print stack after pushd/popd

# History
HISTFILE=~/.zsh_history
HISTSIZE=50000
SAVEHIST=50000
setopt hist_ignore_all_dups  # remove older duplicates
setopt hist_ignore_space     # don't save commands starting with space
setopt hist_reduce_blanks    # trim unnecessary blanks
setopt share_history         # share history across sessions
setopt append_history        # append instead of overwrite

# Completion
autoload -Uz compinit && compinit
zstyle ':completion:*' menu select                    # arrow-key completion menu
zstyle ':completion:*' matcher-list 'm:{a-z}={A-Z}'  # case-insensitive completion
zstyle ':completion:*' list-colors "${(s.:.)LS_COLORS}" # colored completion

# Line editing
bindkey -v                 # vi keybindings (esc to enter normal mode)
KEYTIMEOUT=1               # near-instant esc response (10ms)
bindkey '^[[A' history-search-backward  # up arrow searches history
bindkey '^[[B' history-search-forward   # down arrow searches history

# cursor shape changes with vi mode (beam=insert, block=normal)
zle-keymap-select() {
	if [[ $KEYMAP == vicmd ]]; then
		echo -ne '\e[2 q'  # block cursor
	else
		echo -ne '\e[6 q'  # beam cursor
	fi
}
zle-line-init() { echo -ne '\e[6 q' }  # start in beam cursor
zle -N zle-keymap-select
zle -N zle-line-init

# ===========================================================================
# PROMPT
# ===========================================================================

eval "$(oh-my-posh init zsh --config '~/oh-my-posh/velvet.omp.json')"

# ===========================================================================
# ALIASES
# ===========================================================================

# shell utils
alias cls='clear'
alias whatsmyip='printf "%s\n" "$(curl -s http://ifconfig.me/ip)"'

# copy stdout to clipboard
copy() {
	pbcopy 2>/dev/null
}

# file listing
alias ll='eza -la --icons'
alias lt='eza --tree --icons --level=2'
alias ls='eza --icons'

# bat (syntax-highlighted cat)
alias cat='bat --paging=never'
alias catp='bat'                # bat with pager (for long files)
alias rawcat='command cat'      # original cat (no syntax highlighting)
export BAT_THEME="gruvbox-dark"
export MANPAGER="sh -c 'col -bx | bat -l man -p'"  # colored man pages

# lazygit
alias lg='lazygit'

# btop replaces top
alias top='btop'

# python3 to py
alias py="python3"

# ===========================================================================
# FZF
# ===========================================================================

if command -v fzf >/dev/null 2>&1; then
  source <(fzf --zsh)
  export FZF_DEFAULT_OPTS="
    --height=40% --layout=reverse --border=rounded
    --color=bg+:#341948,bg:#0E050F,spinner:#69307A,hl:#EFDCF9
    --color=fg:#EFDCF9,header:#4c1f5e,info:#69307A,pointer:#EFDCF9
    --color=marker:#69307A,fg+:#EFDCF9,prompt:#69307A,hl+:#EFDCF9
    --preview-window=right:50%:wrap
  "
  # ctrl-t: file picker with bat preview
  export FZF_CTRL_T_OPTS="--preview 'bat --color=always --style=numbers --line-range=:200 {} 2>/dev/null || echo {}'"
  # ctrl-r: history search (already works, just styling)
  export FZF_CTRL_R_OPTS="--layout=reverse"
fi

# ===========================================================================
# ZSH PLUGINS
# ===========================================================================

# Autosuggestions (ghost text from history)
if [ -f /opt/homebrew/share/zsh-autosuggestions/zsh-autosuggestions.zsh ]; then
  source /opt/homebrew/share/zsh-autosuggestions/zsh-autosuggestions.zsh
  ZSH_AUTOSUGGEST_HIGHLIGHT_STYLE="fg=#4c1f5e"
  ZSH_AUTOSUGGEST_STRATEGY=(history completion)
fi

# Syntax highlighting (velvet theme colors)
if [ -f /opt/homebrew/share/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh ]; then
  source /opt/homebrew/share/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh
  ZSH_HIGHLIGHT_STYLES[command]="fg=#EFDCF9,bold"
  ZSH_HIGHLIGHT_STYLES[builtin]="fg=#EFDCF9,bold"
  ZSH_HIGHLIGHT_STYLES[alias]="fg=#EFDCF9,bold"
  ZSH_HIGHLIGHT_STYLES[function]="fg=#EFDCF9,bold"
  ZSH_HIGHLIGHT_STYLES[unknown-token]="fg=#69307A,underline"
  ZSH_HIGHLIGHT_STYLES[path]="fg=#EFDCF9,underline"
  ZSH_HIGHLIGHT_STYLES[single-quoted-argument]="fg=#7FD5EA"
  ZSH_HIGHLIGHT_STYLES[double-quoted-argument]="fg=#7FD5EA"
  ZSH_HIGHLIGHT_STYLES[dollar-quoted-argument]="fg=#7FD5EA"
  ZSH_HIGHLIGHT_STYLES[commandseparator]="fg=#69307A"
  ZSH_HIGHLIGHT_STYLES[redirection]="fg=#69307A"
  ZSH_HIGHLIGHT_STYLES[globbing]="fg=#E4F34A"
  ZSH_HIGHLIGHT_STYLES[comment]="fg=#341948"
fi

# ===========================================================================
# FUNCTIONS
# ===========================================================================

# memory usage (macOS native)
meminfo() {
	local pages_free pages_active pages_inactive pages_speculative pages_wired page_size
	local total used pct

	page_size=$(sysctl -n hw.pagesize)
	total=$(sysctl -n hw.memsize)

	pages_free=$(vm_stat | awk '/Pages free/ {gsub(/\./,"",$3); print $3}')
	pages_active=$(vm_stat | awk '/Pages active/ {gsub(/\./,"",$3); print $3}')
	pages_inactive=$(vm_stat | awk '/Pages inactive/ {gsub(/\./,"",$3); print $3}')
	pages_speculative=$(vm_stat | awk '/Pages speculative/ {gsub(/\./,"",$3); print $3}')
	pages_wired=$(vm_stat | awk '/Pages wired/ {gsub(/\./,"",$3); print $3}')

	used=$(( (pages_active + pages_wired + pages_speculative) * page_size ))
	pct=$(( used * 100 / total ))

	printf "memory: %dmb / %dmb (%d%%)\n" \
		$((used / 1024 / 1024)) \
		$((total / 1024 / 1024)) \
		$pct
}

# jamf fetch logs
jamflogs() {
	tail -n 100 /var/log/jamf.log | less
}
