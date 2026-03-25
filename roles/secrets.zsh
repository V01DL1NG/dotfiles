# Secret injection — op (1Password CLI) with GPG fallback
# Usage: secret <name>   — returns the secret value or empty string on failure
#
# To enable:
#   1Password: install op CLI, sign in (op signin), then:
#              export ANTHROPIC_API_KEY="$(secret anthropic-api-key)"
#   GPG:       gpg --symmetric --cipher-algo AES256 -o ~/.secrets/<name>.gpg
#              then the same export line below will pick it up automatically.
#
# Secrets are lazy-evaluated — a missing tool or missing secret returns "" silently.

secret() {
  local name="${1:?secret: name required}"

  # Try 1Password first (op CLI)
  if command -v op >/dev/null 2>&1; then
    local val
    val="$(op read "op://Personal/${name}/password" 2>/dev/null)" && {
      printf '%s' "$val"
      return 0
    }
  fi

  # Fall back to GPG-encrypted file at ~/.secrets/<name>.gpg
  local gpg_file="$HOME/.secrets/${name}.gpg"
  if command -v gpg >/dev/null 2>&1 && [ -f "$gpg_file" ]; then
    gpg --quiet --decrypt "$gpg_file" 2>/dev/null
    return 0
  fi

  # Not found — return empty string silently (don't break shell startup)
  return 0
}

# ── Load secrets into the environment ─────────────────────────────────────────
# Uncomment and rename to match your 1Password items / GPG file names.
# The secret() function is lazy — missing entries resolve to "" with no error.

# export ANTHROPIC_API_KEY="$(secret anthropic-api-key)"
# export GITHUB_TOKEN="$(secret github-token)"
# export OPENAI_API_KEY="$(secret openai-api-key)"
# export AWS_ACCESS_KEY_ID="$(secret aws-access-key-id)"
# export AWS_SECRET_ACCESS_KEY="$(secret aws-secret-access-key)"
# export ATUIN_KEY="$(secret atuin-key)"
