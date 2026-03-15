# Quick project navigation
alias proj='cd ~/code'
alias dot='cd ~/code/dotfiles'

# Quick daily note (opens today's file in $EDITOR)
note() {
  local file="$HOME/notes/$(date +%Y-%m-%d).md"
  mkdir -p "$HOME/notes"
  "${EDITOR:-nvim}" "$file"
}

# Personal git identity reminder
# git config --global user.email "you@personal.com"
# git config --global user.name  "Your Name"
