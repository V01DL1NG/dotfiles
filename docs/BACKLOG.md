# Backlog

Items are grouped by theme. Check them off as they ship.

---

## Container / Profile System

- [x] **`profile.sh diff`** — compare two containers against each other, or a container against currently installed files; shows a per-file unified diff before committing to an install
- [x] **`profile.sh push` / `profile.sh fetch <url>`** — round-trip through a GitHub Gist; `push` creates/updates a Gist and prints the URL, `fetch` downloads, shows `--info`, then prompts to install
- [x] **Profile patches** — lightweight containers that only override specific files (e.g. just `.p10k.zsh`); `profile.sh patch <profile> --files ghostty,kitty`
- [x] **`profile.sh rollback`** — restore the most recent `.backup.*` set that was created during the last install; reads timestamps already written by the installer

---

## Onboarding

- [x] **`bootstrap.sh` / curl-to-install** — single command for a clean Mac (`curl -fsSL <url> | bash`); installs Xcode CLT → Homebrew → clones repo → runs `choose-profile.sh` + `install-all.sh`
- [x] **`doctor.sh`** — health-check command; reports missing tools, broken/symlinked configs, git identity, font, iTerm2 profiles, active roles

---

## Built-in Profiles

- [x] **`minimal` profile** — plain zsh prompt (no oh-my-posh or p10k), same aliases and tools; useful for servers or pairing sessions where Nerd Fonts aren't guaranteed
- [x] **`catppuccin` profile** — Catppuccin Mocha palette; reuses the p10k engine and shares ~90% of the existing `.p10k.zsh` config

---

## Terminal Support

- [x] **Ghostty config** — add `profiles/*/ghostty.conf` alongside `iterm.json` so containers work across terminals (Ghostty has first-class config files that fit the copy-local model)
- [x] **Kitty config** — same idea; `profiles/*/kitty.conf` per profile

---

## Dotfiles Lifecycle

- [x] **`update.sh`** — `git pull` the repo, re-run profile install non-destructively; three-way hash comparison skips user-modified files, auto-updates untouched ones, prompts on conflicts
- [x] **Machine roles** — `work`, `personal`, `server` variants that layer on top of a base profile via `role.sh apply/remove/list/status`

---

## Shipped

- [x] Multi-profile system (`choose-profile.sh`) — velvet + p10k-velvet, local file copies
- [x] Profile containers (`profile.sh`) — export, pack, import, info, list
- [x] p10k-velvet profile — Powerlevel10k blended with velvet/sakura palette
- [x] bootstrap.sh — curl-installable new-Mac setup
- [x] doctor.sh — comprehensive health check
- [x] minimal profile — plain zsh prompt, no engine
- [x] catppuccin profile — Catppuccin Mocha + Powerlevel10k
- [x] Machine roles — work / personal / server via role.sh
- [x] Ghostty + Kitty configs — all 4 profiles, auto-detected install, packed into containers
- [x] update.sh — non-destructive pull + re-apply with three-way conflict detection
- [x] profile.sh diff — container vs live or container vs container, per-file unified diff
- [x] profile.sh rollback — grouped backup sets, interactive picker, restore by timestamp
- [x] profile.sh push/fetch — GitHub Gist round-trip via gh CLI
- [x] profile.sh patch — lightweight containers with subset of files, interactive key picker
