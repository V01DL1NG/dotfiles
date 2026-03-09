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

# python3 to py
alias py="python3"

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
