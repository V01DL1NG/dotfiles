# Powerlevel10k config — velvet/sakura blend
# Colors mirror the oh-my-posh velvet theme for visual consistency.
#
# Palette:
#   #0E050F  near-black bg
#   #170B3B  deep purple  (dir)
#   #341948  dark violet  (git)
#   #4c1f5e  purple       (exec time, right segments)
#   #69307A  bright violet (status, prompt char)
#   #EFDCF9  lavender fg

# Nerd Font glyphs
typeset -g POWERLEVEL9K_MODE='nerdfont-complete'

# ─── Segment lists ──────────────────────────────────────────────────────────

typeset -g POWERLEVEL9K_LEFT_PROMPT_ELEMENTS=(
  os_icon                 #  macOS/linux icon
  dir                     #  current directory
  vcs                     #  git status
  command_execution_time  # ⏱ last command duration
  status                  # ✓/✗ exit code
  newline
  prompt_char             # ❯ / ❮ (vi mode aware)
)

typeset -g POWERLEVEL9K_RIGHT_PROMPT_ELEMENTS=(
  virtualenv              # active python venv name
  pyenv                   #  python version
  goenv                   #  go version
  nvm                     #  node version
  rbenv                   #  ruby version
  java_version            #  java version
  time                    #  clock
)

# ─── Separators (powerline style) ───────────────────────────────────────────

typeset -g POWERLEVEL9K_LEFT_SEGMENT_SEPARATOR='\uE0B0'
typeset -g POWERLEVEL9K_LEFT_SUBSEGMENT_SEPARATOR='\uE0B1'
typeset -g POWERLEVEL9K_RIGHT_SEGMENT_SEPARATOR='\uE0B2'
typeset -g POWERLEVEL9K_RIGHT_SUBSEGMENT_SEPARATOR='\uE0B3'
typeset -g POWERLEVEL9K_LEFT_PROMPT_LAST_SEGMENT_END_SYMBOL='\uE0B0'
typeset -g POWERLEVEL9K_RIGHT_PROMPT_FIRST_SEGMENT_START_SYMBOL='\uE0B6'

# Extra space padding between segments
typeset -g POWERLEVEL9K_LEFT_SEGMENT_END_SEPARATOR=' '

# ─── OS icon ────────────────────────────────────────────────────────────────

typeset -g POWERLEVEL9K_OS_ICON_BACKGROUND='#0E050F'
typeset -g POWERLEVEL9K_OS_ICON_FOREGROUND='#EFDCF9'

# ─── Directory ──────────────────────────────────────────────────────────────

typeset -g POWERLEVEL9K_DIR_BACKGROUND='#170B3B'
typeset -g POWERLEVEL9K_DIR_FOREGROUND='#EFDCF9'
typeset -g POWERLEVEL9K_DIR_SHORTENED_FOREGROUND='#EFDCF9'
typeset -g POWERLEVEL9K_DIR_ANCHOR_FOREGROUND='#EFDCF9'
typeset -g POWERLEVEL9K_DIR_ANCHOR_BOLD=true

typeset -g POWERLEVEL9K_SHORTEN_STRATEGY=truncate_to_unique
typeset -g POWERLEVEL9K_SHORTEN_DIR_LENGTH=3
typeset -g POWERLEVEL9K_DIR_MAX_LENGTH=30

# Home icon
typeset -g POWERLEVEL9K_HOME_ICON=''
typeset -g POWERLEVEL9K_HOME_SUB_ICON=''
typeset -g POWERLEVEL9K_FOLDER_ICON=''
typeset -g POWERLEVEL9K_ETC_ICON=''

# ─── VCS / Git ──────────────────────────────────────────────────────────────

typeset -g POWERLEVEL9K_VCS_BRANCH_ICON='\uF126 '

# clean repo
typeset -g POWERLEVEL9K_VCS_CLEAN_BACKGROUND='#341948'
typeset -g POWERLEVEL9K_VCS_CLEAN_FOREGROUND='#EFDCF9'

# untracked files
typeset -g POWERLEVEL9K_VCS_UNTRACKED_BACKGROUND='#341948'
typeset -g POWERLEVEL9K_VCS_UNTRACKED_FOREGROUND='#E4F34A'
typeset -g POWERLEVEL9K_VCS_UNTRACKED_ICON='?'

# modified/staged
typeset -g POWERLEVEL9K_VCS_MODIFIED_BACKGROUND='#341948'
typeset -g POWERLEVEL9K_VCS_MODIFIED_FOREGROUND='#FFA066'

# ahead/behind upstream
typeset -g POWERLEVEL9K_VCS_OUTGOING_CHANGES_ICON='⇡'
typeset -g POWERLEVEL9K_VCS_INCOMING_CHANGES_ICON='⇣'

typeset -g POWERLEVEL9K_VCS_GIT_HOOKS=(vcs-detect-changes git-untracked git-aheadbehind git-stash git-remotebranch git-tagname)
typeset -g POWERLEVEL9K_VCS_MAX_SYNC_LATENCY_SECONDS=0.5
typeset -g POWERLEVEL9K_VCS_STAGED_MAX_NUM=99
typeset -g POWERLEVEL9K_VCS_UNSTAGED_MAX_NUM=99

# ─── Command execution time ──────────────────────────────────────────────────

typeset -g POWERLEVEL9K_COMMAND_EXECUTION_TIME_BACKGROUND='#4c1f5e'
typeset -g POWERLEVEL9K_COMMAND_EXECUTION_TIME_FOREGROUND='#EFDCF9'
typeset -g POWERLEVEL9K_COMMAND_EXECUTION_TIME_THRESHOLD=0    # always show
typeset -g POWERLEVEL9K_COMMAND_EXECUTION_TIME_PRECISION=2
typeset -g POWERLEVEL9K_COMMAND_EXECUTION_TIME_FORMAT='duration'

# ─── Status (exit code) ──────────────────────────────────────────────────────

typeset -g POWERLEVEL9K_STATUS_EXTENDED_STATES=true
typeset -g POWERLEVEL9K_STATUS_OK=true
typeset -g POWERLEVEL9K_STATUS_OK_BACKGROUND='#69307A'
typeset -g POWERLEVEL9K_STATUS_OK_FOREGROUND='#EFDCF9'
typeset -g POWERLEVEL9K_STATUS_OK_VISUAL_IDENTIFIER_EXPANSION='\uF08A'      # ♥
typeset -g POWERLEVEL9K_STATUS_OK_PIPE=true
typeset -g POWERLEVEL9K_STATUS_OK_PIPE_BACKGROUND='#69307A'
typeset -g POWERLEVEL9K_STATUS_OK_PIPE_FOREGROUND='#EFDCF9'
typeset -g POWERLEVEL9K_STATUS_ERROR_BACKGROUND='#69307A'
typeset -g POWERLEVEL9K_STATUS_ERROR_FOREGROUND='#FF3C3C'
typeset -g POWERLEVEL9K_STATUS_ERROR_VISUAL_IDENTIFIER_EXPANSION='\uF08A'   # ♥
typeset -g POWERLEVEL9K_STATUS_ERROR_PIPE=true
typeset -g POWERLEVEL9K_STATUS_ERROR_PIPE_BACKGROUND='#69307A'
typeset -g POWERLEVEL9K_STATUS_ERROR_PIPE_FOREGROUND='#FF3C3C'

# ─── Prompt character ────────────────────────────────────────────────────────

# vi-insert mode → ❯ (bright violet), vi-normal mode → ❮ (lavender)
typeset -g POWERLEVEL9K_PROMPT_CHAR_OK_VIINS_CONTENT_EXPANSION='❯'
typeset -g POWERLEVEL9K_PROMPT_CHAR_OK_VICMD_CONTENT_EXPANSION='❮'
typeset -g POWERLEVEL9K_PROMPT_CHAR_OK_VIVIS_CONTENT_EXPANSION='V'
typeset -g POWERLEVEL9K_PROMPT_CHAR_ERROR_VIINS_CONTENT_EXPANSION='❯'
typeset -g POWERLEVEL9K_PROMPT_CHAR_ERROR_VICMD_CONTENT_EXPANSION='❮'

typeset -g POWERLEVEL9K_PROMPT_CHAR_OK_VIINS_FOREGROUND='#69307A'
typeset -g POWERLEVEL9K_PROMPT_CHAR_OK_VICMD_FOREGROUND='#EFDCF9'
typeset -g POWERLEVEL9K_PROMPT_CHAR_OK_VIVIS_FOREGROUND='#EFDCF9'
typeset -g POWERLEVEL9K_PROMPT_CHAR_ERROR_VIINS_FOREGROUND='#FF3C3C'
typeset -g POWERLEVEL9K_PROMPT_CHAR_ERROR_VICMD_FOREGROUND='#FF3C3C'
typeset -g POWERLEVEL9K_PROMPT_CHAR_OVERWRITE_STATE=false

# ─── Right — Python / pyenv ──────────────────────────────────────────────────

typeset -g POWERLEVEL9K_PYENV_BACKGROUND='#4c1f5e'
typeset -g POWERLEVEL9K_PYENV_FOREGROUND='#E4F34A'
typeset -g POWERLEVEL9K_PYENV_VISUAL_IDENTIFIER_EXPANSION='\uE235'   #
typeset -g POWERLEVEL9K_PYENV_PROMPT_ALWAYS_SHOW=false
typeset -g POWERLEVEL9K_PYENV_SHOW_SYSTEM=false

typeset -g POWERLEVEL9K_VIRTUALENV_BACKGROUND='#4c1f5e'
typeset -g POWERLEVEL9K_VIRTUALENV_FOREGROUND='#E4F34A'
typeset -g POWERLEVEL9K_VIRTUALENV_SHOW_PYTHON_VERSION=false

# ─── Right — Go / goenv ─────────────────────────────────────────────────────

typeset -g POWERLEVEL9K_GOENV_BACKGROUND='#4c1f5e'
typeset -g POWERLEVEL9K_GOENV_FOREGROUND='#7FD5EA'
typeset -g POWERLEVEL9K_GOENV_VISUAL_IDENTIFIER_EXPANSION='\uE626'   #
typeset -g POWERLEVEL9K_GOENV_PROMPT_ALWAYS_SHOW=false
typeset -g POWERLEVEL9K_GOENV_SHOW_SYSTEM=false

# ─── Right — Node / nvm ─────────────────────────────────────────────────────

typeset -g POWERLEVEL9K_NVM_BACKGROUND='#4c1f5e'
typeset -g POWERLEVEL9K_NVM_FOREGROUND='#42E66C'
typeset -g POWERLEVEL9K_NVM_VISUAL_IDENTIFIER_EXPANSION='\uE718'     #
typeset -g POWERLEVEL9K_NVM_PROMPT_ALWAYS_SHOW=false
typeset -g POWERLEVEL9K_NVM_SHOW_SYSTEM=false

# ─── Right — Ruby / rbenv ───────────────────────────────────────────────────

typeset -g POWERLEVEL9K_RBENV_BACKGROUND='#4c1f5e'
typeset -g POWERLEVEL9K_RBENV_FOREGROUND='#E64747'
typeset -g POWERLEVEL9K_RBENV_VISUAL_IDENTIFIER_EXPANSION='\uE791'   #
typeset -g POWERLEVEL9K_RBENV_PROMPT_ALWAYS_SHOW=false
typeset -g POWERLEVEL9K_RBENV_SHOW_SYSTEM=false

# ─── Right — Java version ───────────────────────────────────────────────────

typeset -g POWERLEVEL9K_JAVA_VERSION_BACKGROUND='#4c1f5e'
typeset -g POWERLEVEL9K_JAVA_VERSION_FOREGROUND='#E64747'
typeset -g POWERLEVEL9K_JAVA_VERSION_VISUAL_IDENTIFIER_EXPANSION='\uE738'  #
typeset -g POWERLEVEL9K_JAVA_VERSION_FULL=false

# ─── Right — Time ───────────────────────────────────────────────────────────

typeset -g POWERLEVEL9K_TIME_BACKGROUND='#4c1f5e'
typeset -g POWERLEVEL9K_TIME_FOREGROUND='#EFDCF9'
typeset -g POWERLEVEL9K_TIME_FORMAT='%D{%H:%M:%S}'
typeset -g POWERLEVEL9K_TIME_UPDATE_ON_COMMAND=false

# ─── Misc ────────────────────────────────────────────────────────────────────

# Add an extra blank line before each prompt (feels more spacious)
typeset -g POWERLEVEL9K_PROMPT_ADD_NEWLINE=false

# Instant prompt: suppress warnings for commands that produce output during init
typeset -g POWERLEVEL9K_INSTANT_PROMPT=verbose
