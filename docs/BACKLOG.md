# Backlog

Items are grouped by theme. Check them off as they ship.

---

## Container / Profile System

- [ ] **`profile.sh diff`** — compare two containers against each other, or a container against currently installed files; shows a per-file unified diff before committing to an install
- [ ] **`profile.sh push` / `profile.sh fetch <url>`** — round-trip through a GitHub Gist; `push` creates/updates a Gist and prints the URL, `fetch` downloads, shows `--info`, then prompts to install
- [ ] **Profile patches** — lightweight containers that only override specific files (e.g. just `.p10k.zsh`); same format as a full container but with a `PATCH=true` flag that merges rather than replaces
- [ ] **`profile.sh rollback`** — restore the most recent `.backup.*` set that was created during the last install; reads timestamps already written by the installer

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

- [ ] **Ghostty config** — add `profiles/*/ghostty.conf` alongside `iterm.json` so containers work across terminals (Ghostty has first-class config files that fit the copy-local model)
- [ ] **Kitty config** — same idea; `profiles/*/kitty.conf` per profile

---

## Dotfiles Lifecycle

- [ ] **`dotfiles update`** — `git pull` the repo, re-run profile install non-destructively (skip files that are newer than the profile source), report what changed; lets users stay in sync without losing personal edits
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
