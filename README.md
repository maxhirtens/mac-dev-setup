# macOS Clean Install for Development

**@maxhirtens** — last updated 08/2026

Start-to-finish setup for a fresh macOS machine: prep, system config, CLIs, editor, agent tooling.

> **This doc lives at https://github.com/maxhirtens/mac-dev-setup** — open it there on the fresh machine.

---

## Contents

1. [Prep the old machine](#1-prep-the-old-machine)
2. [Erase and reinstall](#2-erase-and-reinstall)
3. [First boot](#3-first-boot)
4. [Manual installs](#4-manual-installs)
5. [Claude Code](#5-claude-code)
6. [Machine name](#6-machine-name)
7. [macOS defaults](#7-macos-defaults)
8. [Homebrew and CLIs](#8-homebrew-and-clis)
9. [Node via fnm](#9-node-via-fnm)
10. [Shell config](#10-shell-config)
11. [GitHub auth](#11-github-auth)
12. [GUI apps (casks)](#12-gui-apps-casks)
13. [Cursor / VS Code](#13-cursor--vs-code)
14. [System Settings](#14-system-settings)
15. [Clone repos](#15-clone-repos)
16. [Remaining GUI installs](#16-remaining-gui-installs)

Appendices: [A. Claude skills](#appendix-a-claude-skills) · [B. Editor extensions](#appendix-b-editor-extensions)

---

## 1. Prep the old machine

Do all of this **before** wiping.

- [ ] Move desktop files to `temp/` on the SSD
- [ ] Push all branches to GitHub
- [ ] Save dev env vars to 1Password
- [ ] Update the IDE extension list ([Appendix B](#appendix-b-editor-extensions))
- [ ] Update the Claude skills/plugins list ([Appendix A](#appendix-a-claude-skills))
- [ ] Commit and push `maxhirtens-skills` — it carries the global `AGENTS.md`
- [ ] Save `~/.claude/settings.json` to 1Password (the only Claude config not in git)

## 2. Erase and reinstall

Consider booting into safe mode and/or resetting NVRAM first, then erase and reinstall macOS.

## 3. First boot

| Field        | Value  |
| ------------ | ------ |
| Full name    | `Main` |
| Account name | `main` |

**Skip iCloud during setup.** Sign in later, once the account is clean.

## 4. Manual installs

Install in this order — Chrome and 1Password first, so everything after can be logged into.

- [ ] Chrome
- [ ] 1Password
- [ ] 1Password Chrome extension
- [ ] Sign into Google account
- [ ] Sign into iCloud — confirm no duplicate contact card was created

## 5. Claude Code

Install this early — the native installer is a plain `curl` with no dependency on Homebrew or Node, so Claude can help run the rest of this doc.

```bash
curl -fsSL https://claude.ai/install.sh | bash
```

There is also a Homebrew cask (`brew install --cask claude-code`), deliberately not used here: it would push this step after [step 8](#8-homebrew-and-clis), and Homebrew installs don't auto-update. The native install updates itself in the background.

Verify before going further:

```bash
claude --version && claude doctor
```

`claude doctor` prints read-only install and settings diagnostics without starting a session. A clean machine ends with `No installation issues found.` Confirm it reports install method `native` — an npm install ties `claude` to whichever Node version fnm has active, so it vanishes from PATH in any repo pinning a different one.

If `claude --version` reports `command not found`, PATH is the reason. The installer places the launcher at `~/.local/bin/claude`, which is **not** on the default macOS PATH and which the installer does not add for you. [Step 10](#10-shell-config) adds it permanently. To unblock yourself before then:

```bash
export PATH="$HOME/.local/bin:$PATH"
```

Then start it and log in via the browser:

```bash
claude
```

Point it at this doc:

```
Walk me through https://github.com/maxhirtens/mac-dev-setup
```

Claude can run the `defaults`, Homebrew, fnm, and skills steps directly. It can't type a `sudo` password or complete a browser login — run those yourself with the `!` prefix so the output stays in the session.

Config restore:

- `settings.json` → `~/.claude/settings.json` — restore from the saved copy
- Global instructions are a symlink to `AGENTS.md` in `maxhirtens-skills`, not a saved copy — see [Appendix A](#appendix-a-claude-skills)
- `CLAUDE.md` for projects lives in each repo directly
- Skills need `npx`, so they come after Node — see [Appendix A](#appendix-a-claude-skills)
- Native installs auto-update, so `up` ([step 10](#10-shell-config)) doesn't cover Claude Code

## 6. Machine name

One short lowercase name, unique per machine, set in all three places so Finder, Bonjour, and the shell prompt agree. Pick it by hardware — the pattern is model plus a digit.

```bash
NAME="<machine-name>"

sudo scutil --set ComputerName "$NAME" &&
sudo scutil --set LocalHostName "$NAME" &&
sudo scutil --set HostName "$NAME" &&
dscacheutil -flushcache
```

Verify:

```bash
scutil --get ComputerName &&
scutil --get LocalHostName &&
scutil --get HostName
```

## 7. macOS defaults

```bash
defaults write com.apple.screencapture type jpg &&
defaults write com.apple.finder QLEnableTextSelection -bool true &&
defaults write com.apple.desktopservices DSDontWriteNetworkStores -bool true &&
defaults write com.apple.desktopservices DSDontWriteUSBStores -bool true &&
defaults write com.apple.TimeMachine DoNotOfferNewDisksForBackup -bool true &&
chflags nohidden ~/Library
```

Screenshots as JPG · text selection in Quick Look · no `.DS_Store` on network or USB volumes · no Time Machine prompts for new disks · `~/Library` visible.

## 8. Homebrew and CLIs

Homebrew installs the Xcode Command Line Tools as part of its own install — no separate step.

```bash
/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
brew update
```

All CLIs in one shot — Node is intentionally excluded, `fnm` owns it ([step 9](#9-node-via-fnm)):

```bash
brew install git gh stripe/stripe-cli/stripe awscli ffmpeg postgresql@17
```

`postgresql@17` is here for the client tools only — `pg_dump`, `pg_restore`, `psql`, which land on PATH despite the formula being keg-only. **Never `brew services start` it.** Nothing autostarts on install; confirm with:

```bash
brew services list | grep postgres   # expect "none"
```

Git config — identity, then the settings the `pull`/`push` workflow in [step 10](#10-shell-config) assumes. Idempotent:

```bash
git config --global user.name "Max Hirtenstein" &&
git config --global user.email "maxhirtens@gmail.com" &&
git config --global github.user "maxhirtens" &&
git config --global init.defaultBranch main &&
git config --global push.autoSetupRemote true &&
git config --global url."https://github.com/".insteadOf "git@github.com:" &&
git config --global core.excludesfile ~/.gitignore_global &&
{ grep -qs '^\.DS_Store$' ~/.gitignore_global || echo '.DS_Store' >> ~/.gitignore_global; } &&
{ grep -qs 'settings.local.json' ~/.gitignore_global || echo '**/.claude/settings.local.json' >> ~/.gitignore_global; } &&
git config --global --list
```

| Setting                 | Why                                                                                          |
| ----------------------- | -------------------------------------------------------------------------------------------- |
| `push.autoSetupRemote`  | A first `git push` on a new branch sets its upstream automatically — no `-u` to forget, so `pull all` on the other machine always sees it |
| `url.insteadOf`         | Rewrites `git@github.com:` URLs to HTTPS. `gh auth login` uses HTTPS ([step 11](#11-github-auth)) and there's no SSH key on this machine, so an SSH-form clone URL would otherwise fail |
| `core.excludesfile`     | Keeps `.DS_Store` out of every repo. [Step 7](#7-macos-defaults) only suppresses it on network and USB volumes, not local disk |
| `settings.local.json`   | Machine-local Claude Code permission grants — never belongs in a repo                          |

## 9. Node via fnm

Installs `fnm`, Node 24 (the Vercel prod runtime), sets it as the global default, and wires up auto-switching so any repo with a `.nvmrc` or `.node-version` picks up its version on `cd`.

Like [step 10](#10-shell-config), the `grep -qs 'fnm env'` guard makes this install-once: safe to paste twice, but it will not rewrite an existing `fnm env` line if the flags below change. Update those by hand on a machine that already ran this.

`--version-file-strategy=recursive` makes that work from subdirectories too. The default, `local`, only reads a version file in the directory you land in — so `cd apps/web` in a monorepo whose `.nvmrc` sits at the root silently keeps the global default. With no version file anywhere, fnm falls back to `engines.node` in `package.json`.

```bash
brew install fnm \
  && eval "$(fnm env --use-on-cd --version-file-strategy=recursive --shell zsh)" \
  && fnm install 24 \
  && fnm default 24 \
  && { grep -qs 'fnm env' ~/.zshrc \
       || printf '\n# fnm\neval "$(fnm env --use-on-cd --version-file-strategy=recursive --shell zsh)"\n' >> ~/.zshrc; }
```

Restart the terminal (or `source ~/.zshrc`), then verify — expect `v24.x`:

```bash
node -v && npm -v
```

## 10. Shell config

Everything else that belongs in `~/.zshrc`, on top of the fnm line from [step 9](#9-node-via-fnm) — PATH de-duplication, the `~/.local/bin` entry that makes `claude` resolvable, git branch helpers, and a one-shot update command.

**Install-once, not re-runnable.** The `grep` guard skips the whole block if it's already present, so this is safe to paste twice — but re-running it will *not* pick up later edits to `pull`, `plugup`, or `up`. To update an existing machine, edit `~/.zshrc` by hand, or delete the block and re-run.

```bash
grep -qs 'typeset -U path' ~/.zshrc || cat >> ~/.zshrc <<'EOF'

typeset -U path PATH

# claude (step 5) installs to ~/.local/bin, which is not on the default PATH.
# Harmless if the installer also adds it — typeset -U above collapses the duplicate.
export PATH="$HOME/.local/bin:$PATH"

# pull main | dev | all — refresh branches from origin
pull() {
  local target="$1"
  [[ "$target" == main || "$target" == dev || "$target" == all ]] \
    || { echo "usage: pull {main|dev|all}" >&2; return 1; }

  git rev-parse --git-dir >/dev/null 2>&1 \
    || { echo "pull: not a git repository" >&2; return 1; }
  git remote get-url origin >/dev/null 2>&1 \
    || { echo "pull: no 'origin' remote" >&2; return 1; }

  if [[ "$target" == all ]]; then
    git fetch --all --prune || return 1
    local cur b before gone
    cur="$(git branch --show-current)"

    # fast-forward branches we already have, reporting only the ones that moved
    if [[ -n "$cur" ]]; then
      before="$(git rev-parse HEAD)"
      git merge --ff-only '@{u}' >/dev/null 2>&1
      [[ "$(git rev-parse HEAD)" != "$before" ]] && echo "  ff  $cur (current)"
    fi
    for b in $(git for-each-ref --format='%(refname:short)' refs/heads); do
      [[ "$b" == "$cur" ]] && continue
      before="$(git rev-parse "$b")"
      git fetch -q origin "$b:$b" 2>/dev/null || continue
      [[ "$(git rev-parse "$b")" != "$before" ]] && echo "  ff  $b"
    done

    # create locals for branches pushed from elsewhere
    for b in $(git for-each-ref --format='%(refname:short)' refs/remotes/origin); do
      [[ "$b" == origin || "$b" == origin/HEAD ]] && continue
      b=${b#origin/}
      git show-ref --verify --quiet "refs/heads/$b" && continue
      git branch -q --track "$b" "origin/$b" && echo "  new $b"
    done

    # flag locals whose remote is gone, but don't delete them
    gone=$(git for-each-ref --format='%(refname:short) %(upstream:track)' refs/heads | awk '/\[gone\]/{print $1}')
    [[ -n "$gone" ]] && echo "  stale (remote deleted): ${gone//$'\n'/ }"
    return 0
  fi

  git checkout main && git pull origin main || return 1
  [[ "$target" == dev ]] || return 0
  git checkout development && git pull origin development
}

# plugup — refresh every marketplace, then update each installed plugin.
# `claude plugin update` takes one plugin at a time and has no --all, hence the loop.
plugup() {
  command -v claude >/dev/null 2>&1 || { echo "plugup: claude not on PATH" >&2; return 1; }
  claude plugin marketplace update || return 1
  local p
  for p in $(python3 -c 'import json,os
f = os.path.expanduser("~/.claude/plugins/installed_plugins.json")
print(" ".join(json.load(open(f)).get("plugins", {})) if os.path.exists(f) else "")'); do
    claude plugin update "$p"
  done
}

# up — update everything
alias up='brew update && brew upgrade --greedy && brew cleanup && brew autoremove; npm update -g; npx skills update -g -y; plugup; softwareupdate -l'
EOF
```

Restart the terminal (or `source ~/.zshrc`), then verify:

```bash
type pull | head -1 && type plugup | head -1 && alias up
```

| Command           | Does                                                                                   |
| ----------------- | -------------------------------------------------------------------------------------- |
| `typeset -U path` | Keeps PATH de-duplicated, so prepends can't stack up across nested shells                |
| `~/.local/bin` on PATH | Where [step 5](#5-claude-code) puts `claude`; not on the default macOS PATH          |
| `pull main`       | `checkout main` → `pull origin main`                                                     |
| `pull dev`        | Same, then `development` — ends on `development`                                         |
| `pull all`        | Fetches every branch, fast-forwards all locals, creates locals for branches pushed from another machine — never switches branches |
| `plugup`          | Refreshes every Claude Code marketplace, then updates each installed plugin              |
| `up`              | Brew update/upgrade/cleanup/autoremove, global npm, Claude skills, Claude plugins, lists macOS updates |

`pull` takes no default — a bare `pull` prints usage and exits 1 rather than guessing which of the three you meant.

`plugup` exists because plugin auto-update is per-marketplace and off by default for third-party ones ([Appendix A](#appendix-a-claude-skills)). Folding it into `up` makes that setting irrelevant: every marketplace and plugin is current after an `up`, whatever the toggles say. `claude plugin update` handles one plugin per call and has no `--all`, so the function reads the installed set out of `~/.claude/plugins/installed_plugins.json` and loops. Updates land on disk; a running session picks them up on `/reload-plugins` or next launch.

`--greedy` is load-bearing: without it `brew upgrade` skips every `auto_updates true` cask, which is nearly all of them, and `up` reports success having upgraded no apps at all.

`pull` bails with a readable message — before switching branches — if the directory isn't a git repo or has no `origin`. A missing local `development` is fine: git creates it tracking `origin/development`.

`pull all` is the one to run after pushing work from another machine. It prunes deleted remotes, fast-forwards local branches in place without checking them out, and creates a local tracking branch for anything new on `origin`. Branches whose remote was deleted are listed as `stale` rather than removed — deletion stays a manual call.

The output only lists branches that actually changed, so a repo already in sync prints nothing — apart from the `stale` line, which is a standing condition rather than a change and so reprints on every run until you delete the branch. Branches with no upstream, and any that have diverged rather than fast-forwarding, are left untouched and unreported.

> **`pull all` changed meaning.** It previously synced `main` → `development` and left you on `development`. It now sweeps every branch and never switches — `pull dev` is the new spelling of the old behavior. Worth unlearning deliberately if the old one is in muscle memory.

## 11. GitHub auth

```bash
gh auth login
```

Choose **HTTPS** when prompted.

Node and `gh` are both in place now — this is the point to come back and install skills from [Appendix A](#appendix-a-claude-skills).

## 12. GUI apps (casks)

Anything with a working cask goes through brew so `up` can see it. Only apps without one are installed by hand ([step 16](#16-remaining-gui-installs)).

```bash
brew install --cask vlc cursor zoom spotify superduper transmission \
  inngest/tap/inngest obs whatsapp appzapper loopback
```

`inngest` must be tap-qualified, for the same reason `stripe/stripe-cli/stripe` is in [step 8](#8-homebrew-and-clis): it lives in a third-party tap, so the bare name fails and `brew search inngest` reports nothing until the tap is added. Homebrew asks to trust the tap on first install. It's also the odd one out in this list — the Inngest CLI and dev server (`inngest dev`), not a GUI app — but Inngest ships it as a cask, so this is where brew wants it.

The install aborts with `It seems there is already a Binary at '/opt/homebrew/bin/inngest'` if a hand-downloaded copy is in the way. Delete that first; brew won't adopt a loose binary the way `--adopt` handles an app.

If an app is already in `/Applications` from a manual download, adopt it instead of reinstalling over it:

```bash
brew install --cask --adopt <cask>
```

`--adopt` shells out to `sudo chmod`, so run it with `!`. An unadopted app is invisible to `up`.

Verify and tidy up:

```bash
brew doctor && brew cleanup
```

## 13. Cursor / VS Code

Cursor is primary; VS Code is optional.

1. Install extensions — [Appendix B](#appendix-b-editor-extensions)
2. `Cmd+Shift+P` → **Preferences: Open User Settings (JSON)** → paste:

```json
{
  "workbench.colorTheme": "Night Owl",
  "editor.formatOnPaste": true,
  "editor.formatOnSave": true,
  "editor.formatOnType": true,
  "editor.defaultFormatter": "esbenp.prettier-vscode",
  "window.zoomLevel": 2,
  "files.trimTrailingWhitespace": true,
  "files.insertFinalNewline": true,
  "files.trimFinalNewlines": true,
  "editor.codeActionsOnSave": {
    "source.fixAll.eslint": "explicit",
    "source.organizeImports": "explicit"
  },
  "editor.bracketPairColorization.enabled": true,
  "editor.guides.bracketPairs": "active",
  "workbench.activityBar.orientation": "vertical",
  "workbench.editor.enablePreview": false,
  "search.exclude": {
    "**/node_modules": true,
    "**/.next": true,
    "**/dist": true,
    "**/coverage": true,
    "**/*.lock": true
  },
  "terminal.integrated.cursorBlinking": true,
  "files.associations": {
    "*.env": "plaintext",
    ".env*": "plaintext"
  },
  "cursor.composer.usageSummaryDisplay": "always",
  "explorer.confirmDelete": false,
  "redhat.telemetry.enabled": false,
  "yaml.disableSchemaDetection": [
    "**/docker-compose.yml",
    "**/docker-compose.yaml",
    "**/docker-compose.*.yml",
    "**/docker-compose.*.yaml",
    "**/compose.yml",
    "**/compose.yaml",
    "**/compose.*.yml",
    "**/compose.*.yaml"
  ]
}
```

## 14. System Settings

**Security**

- [ ] Turn off Time Machine
- [ ] Enable FileVault → store the recovery key in 1Password
- [ ] Enable Firewall → turn on Stealth Mode

**Mouse**

- [ ] Disable Natural Scroll
- [ ] Enable right secondary click

**Dock & Desktop**

- [ ] Disable "click wallpaper to show desktop"
- [ ] Turn off recents
- [ ] Disable show widgets
- [ ] Enable auto-hide and magnification
- [ ] Disable window title-bar double-click zoom
- [ ] Disable drag-windows-to-tile
- [ ] Set Hot Corners
- [ ] Desktop → View Options → Snap to Grid

**Other**

- [ ] Menu Bar → adjust to preference
- [ ] Finder → Settings → show hard disks

## 15. Clone repos

```bash
mkdir -p ~/Desktop/Code && cd ~/Desktop/Code
gh repo clone <owner>/<repo>
```

List what's available to work through:

```bash
gh repo list <owner> --limit 50
```

Add `.env` files back from 1Password.

## 16. Remaining GUI installs

Download and install by hand. SuperDuper, AppZapper, and Loopback moved to [step 12](#12-gui-apps-casks) — don't install those manually.

- Private Internet Access — approve the VPN system extension in **Settings → General → Login Items & Extensions** on first launch
- Titan Firmware and App _(optional)_
- GLM _(optional)_
- SoundID Reference _(optional)_

PIA has a cask but it always fails on macOS 26 — its installer can't strip the quarantine attribute from its own signed binaries, so brew purges the entry. Use the download from privateinternetaccess.com and let PIA self-update; `up` will never see it.

The other three have no cask (checked 08/2026). Before installing manually, check whether one has appeared since:

```bash
brew search --cask <name>
```

Chrome and 1Password are absent here because [step 4](#4-manual-installs) installs them before Homebrew exists. Both have casks and can be adopted after the fact.

---

## Appendix A: Claude skills

Skills arrive two ways, and it matters which owns a given skill:

| Mechanism | Installed by | Lives in | Updated by |
| --------- | ------------ | -------- | ---------- |
| **Plugins** | `/plugin install` in a session | `~/.claude/plugins/cache/` | `plugup` (part of `up`), plus Claude Code's own background updater — see below |
| **npx registry** | `npx skills add` in a shell | `~/.agents/skills/`, symlinked into `~/.claude/skills/` | `npx skills update -g` (part of `up`) |

Plugin skills are namespaced when invoked (`agent-skills:code-review-and-quality`); npx skills are bare (`neon-postgres`). Install each skill **one way only** — one present through both shows up twice in the picker.

`~/.agents/skills/` is the canonical store. `~/.claude/skills/` holds nothing but symlinks into it.

### Plugins

```
/plugin marketplace add anthropics/claude-plugins-official
/plugin marketplace add addyosmani/agent-skills

/plugin install agent-skills@addy-agent-skills
/plugin install vercel@claude-plugins-official
/plugin install stripe@claude-plugins-official
/plugin install code-simplifier@claude-plugins-official
```

| Plugin | Provides |
| ------ | -------- |
| `agent-skills@addy-agent-skills` | The addyosmani set — `code-review-and-quality`, `code-simplification`, `security-and-hardening`, `performance-optimization`, and ~20 more |
| `vercel@claude-plugins-official`  | Next.js, AI SDK, deployment, `react-best-practices` |
| `stripe@claude-plugins-official`  | All seven stripe skills — `stripe-best-practices`, `stripe-docs`, `stripe-projects`, `upgrade-stripe`, `stripe-apps`, `stripe-directory`, `connect-recommend` |
| `code-simplifier@claude-plugins-official` | The `code-simplifier` agent behind the `/simplify` step of the global workflow |

**Auto-update is per-marketplace, and the defaults differ.** Claude Code refreshes marketplaces and upgrades their installed plugins in the background shortly after a session starts — but only where auto-update is on. Official Anthropic marketplaces default to **on**; third-party ones default to **off**. So `claude-plugins-official` keeps `vercel`, `stripe`, and `code-simplifier` current by itself, while `addy-agent-skills` goes stale silently. Turn it on once per machine:

`/plugin` → **Marketplaces** → `addy-agent-skills` → **Enable auto-update**

That toggle is optional here, though: `up` runs `plugup` ([step 10](#10-shell-config)), which refreshes every marketplace and updates every installed plugin regardless of its auto-update setting. Between the two, plugins stay current the same way npx skills do.

### Global skills — npx registry

`npx skills` is a third-party CLI, not an Anthropic tool. Install for Claude Code only (`-a claude-code`) — never `-a '*'`, which fans the skill out into a dozen other agent directories.

```bash
npx skills add inngest/inngest-skills \
  --skill inngest-durable-functions \
  --skill inngest-events \
  --skill inngest-middleware \
  --skill inngest-setup \
  --skill inngest-steps \
  -g -a claude-code -y

npx skills add addyosmani/web-quality-skills \
  --skill seo \
  -g -a claude-code -y

npx skills add vercel-labs/skills \
  --skill find-skills \
  -g -a claude-code -y

npx skills add neondatabase/agent-skills \
  --skill neon-postgres \
  --skill neon-postgres-branches \
  -g -a claude-code -y
```

The addyosmani development set and every stripe skill are deliberately absent — the plugins above already provide them. The stripe plugin is built from the same `stripe/ai` repo the npx registry serves, so any `npx skills add stripe/ai` line duplicates it exactly.

**Check where each skill landed.** Recent CLI versions sometimes copy a skill straight into `~/.claude/skills/<name>/` rather than installing to `~/.agents/skills/` and symlinking. The install output says which (`→ ~/.claude/skills/seo` means it copied). Relocate anything misplaced:

```bash
for s in ~/.claude/skills/*/; do
  n=$(basename "$s")
  [ -L "${s%/}" ] && continue
  mv "${s%/}" ~/.agents/skills/"$n"
  ln -s ../../.agents/skills/"$n" ~/.claude/skills/"$n"
done
```

The lockfile keys skills by name, not path, so moving one is invisible to `npx skills update`. Verify:

```bash
find ~/.claude/skills -maxdepth 1 -mindepth 1 ! -type l    # expect no output
npx skills list
```

### Custom skills and global instructions

Both come from `maxhirtens-skills`, and nothing is a copy — every target symlinks back to the repo, so `git pull` updates the live config.

```bash
git clone https://github.com/maxhirtens/maxhirtens-skills.git ~/Desktop/Code/maxhirtens-skills
```

`AGENTS.md` in that repo is the canonical global instructions. Both agent locations point at it:

```bash
mkdir -p ~/.agents
ln -s ~/Desktop/Code/maxhirtens-skills/AGENTS.md ~/.claude/CLAUDE.md
ln -s ~/Desktop/Code/maxhirtens-skills/AGENTS.md ~/.agents/AGENTS.md
```

Edit the repo file, never `~/.claude/CLAUDE.md` directly. Per-project rules belong in that project's own `AGENTS.md`. Miss these links and there's no error — Claude Code just runs with no global instructions.

Custom skills, same idea:

```bash
mkdir -p ~/.agents/skills
ln -s ~/Desktop/Code/maxhirtens-skills/maxhirtens-fix-or-feature ~/.agents/skills/
ln -s ~/Desktop/Code/maxhirtens-skills/maxhirtens-ship-to-main ~/.agents/skills/

mkdir -p ~/.claude/skills
ln -s ../../.agents/skills/maxhirtens-fix-or-feature ~/.claude/skills/
ln -s ../../.agents/skills/maxhirtens-ship-to-main ~/.claude/skills/
```

Verify every link resolves:

```bash
readlink -f ~/.claude/CLAUDE.md ~/.agents/AGENTS.md
ls -l ~/.agents/skills ~/.claude/skills
```

## Appendix B: Editor extensions

Installs into Cursor. Swap `cursor` for `code` to target VS Code.

```bash
for ext in \
  aaron-bond.better-comments \
  sdras.night-owl \
  usernamehw.errorlens \
  tombonnike.vscode-status-bar-format-toggle \
  yoavbls.pretty-ts-errors \
  dbaeumer.vscode-eslint \
  esbenp.prettier-vscode \
  anysphere.cursorpyright \
  ms-python.python \
  ms-python.black-formatter \
  ms-python.debugpy \
  bradlc.vscode-tailwindcss \
  prisma.prisma \
  redhat.vscode-yaml \
  vitest.explorer \
  ms-playwright.playwright \
  anthropic.claude-code \
  anysphere.remote-containers \
  anysphere.remote-ssh \
  docker.docker \
  mechatroner.rainbow-csv \
  tomoki1207.pdf; do
  echo "=== $ext ==="
  cursor --install-extension "$ext" 2>&1 | tail -3
done
```

| Extension                                | Purpose                        |
| ---------------------------------------- | ------------------------------ |
| `sdras.night-owl`                        | Theme                          |
| `aaron-bond.better-comments`             | Color-coded comment tags       |
| `usernamehw.errorlens`                   | Inline diagnostics             |
| `yoavbls.pretty-ts-errors`               | Readable TS errors             |
| `tombonnike.vscode-status-bar-format-toggle` | Toggle format-on-save      |
| `dbaeumer.vscode-eslint`                 | Linting                        |
| `esbenp.prettier-vscode`                 | Formatting                     |
| `bradlc.vscode-tailwindcss`              | Tailwind IntelliSense          |
| `prisma.prisma`                          | Prisma schema support          |
| `vitest.explorer`                        | Test runner UI                 |
| `ms-playwright.playwright`               | E2E test runner                |
| `anysphere.cursorpyright` + `ms-python.*` | Python toolchain              |
| `redhat.vscode-yaml`                     | YAML schema validation         |
| `anthropic.claude-code`                  | Claude Code integration        |
| `anysphere.remote-containers` + `docker.docker` | Container development   |
| `anysphere.remote-ssh`                   | Editing over SSH               |
| `mechatroner.rainbow-csv`                | CSV column highlighting        |
| `tomoki1207.pdf`                         | PDF preview                    |
