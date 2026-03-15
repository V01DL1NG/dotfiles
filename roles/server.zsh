# Larger history for long-running server sessions
HISTSIZE=200000
SAVEHIST=200000

# Graceful fallbacks when GUI tools are not installed on the server
if ! command -v eza >/dev/null 2>&1; then
  alias ls='ls --color=auto 2>/dev/null || command ls'
  alias ll='ls -la'
  unalias lt 2>/dev/null || true
fi
if ! command -v bat >/dev/null 2>&1; then
  alias cat='command cat'
  unalias catp 2>/dev/null || true
fi
if ! command -v btop >/dev/null 2>&1; then
  unalias top 2>/dev/null || true
fi
if ! command -v lazygit >/dev/null 2>&1; then
  unalias lg 2>/dev/null || true
fi

# ASCII-safe prompt override — set SERVER_ASCII_PROMPT=1 before sourcing to activate
if [ "${SERVER_ASCII_PROMPT:-0}" = "1" ]; then
  PROMPT='[%n@%m %~]%(!.#.$) '
fi
