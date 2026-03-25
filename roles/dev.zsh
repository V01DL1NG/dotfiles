# Developer workflow acceleration
# proj-new, proj-clone, and tmux layout shortcuts

# ── proj-new — scaffold a new project ─────────────────────────────────────────
# Usage: proj-new <name> [python|node|go|generic]
proj-new() {
  local name="${1:?proj-new: project name required}"
  local lang="${2:-generic}"
  local base="${PROJ_DIR:-$HOME/code}"
  local dir="$base/$name"

  if [ -d "$dir" ]; then
    echo "Already exists: $dir"
    return 1
  fi

  mkdir -p "$dir" && cd "$dir" || return 1
  git init -q

  # direnv layout for the requested language
  case "$lang" in
    python) echo "layout python3"  > .envrc ;;
    node)   echo "layout node"     > .envrc ;;
    go)     echo "export GOPATH=$dir/.gopath\nexport PATH=\$GOPATH/bin:\$PATH" > .envrc ;;
    *)      echo "# project: $name" > .envrc ;;
  esac
  direnv allow . 2>/dev/null || true

  echo "# $name" > README.md
  git add . && git commit -qm "init: $name"
  echo "✓ $name ready at $dir"
}

# ── proj-clone — clone + cd + direnv allow ────────────────────────────────────
# Usage: proj-clone <git-url> [dest-name]
proj-clone() {
  local url="${1:?proj-clone: git URL required}"
  local name="${2:-$(basename "$url" .git)}"
  local base="${PROJ_DIR:-$HOME/code}"

  git clone "$url" "$base/$name" && cd "$base/$name" || return 1
  [ -f .envrc ] && direnv allow . 2>/dev/null || true
  echo "✓ cloned to $base/$name"
}
