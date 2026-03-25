# AI launcher integration — Gwen (qwen2.5-coder:7b via Ollama) in the shell
#
# Requires: ~/code/ai-launcher to be cloned and set up.
# See: https://github.com/V01DL1NG/ai-launcher
#
# Usage:
#   ai "write a bash function that..."     one-shot code generation
#   cat broken.sh | ai "fix this"         pipe context + prompt
#   ai-chat                                interactive TUI chat with Gwen
#   ai-sanity                              run model reliability checks

_AI_LAUNCHER="$HOME/code/ai-launcher"

if [ -d "$_AI_LAUNCHER" ]; then
  # One-shot generation: ai "prompt"
  ai() {
    if [ -t 0 ]; then
      # No pipe — prompt only
      python3 -m launcher.generate "$*"
    else
      # Piped input — prepend to prompt as context
      local context
      context="$(cat)"
      python3 -m launcher.generate "$(printf '%s\n\n%s' "$context" "$*")"
    fi
  }

  # Interactive chat TUI
  alias ai-chat='python3 -m launcher.tui'

  # Sanity check suite
  alias ai-sanity='python3 "$_AI_LAUNCHER/scripts/sanity_check.py"'

  # Health check
  alias ai-health='python3 -m launcher.health'
else
  # Stub so shells don't break if the repo isn't cloned
  ai()       { echo "ai-launcher not found at $_AI_LAUNCHER"; }
  ai-chat()  { echo "ai-launcher not found at $_AI_LAUNCHER"; }
fi

unset _AI_LAUNCHER
