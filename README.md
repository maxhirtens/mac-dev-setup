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
- [ ] Update global `CLAUDE.md` and `settings.json`

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

Install this early — it's a plain `curl`, with no dependency on Homebrew or Node — so Claude can help run the rest of this doc.

```bash
curl -fsSL https://claude.ai/install.sh | bash
claude
```

Run `claude` once to log in via the browser. Then point it at this doc:

```
Walk me through https://github.com/maxhirtens/mac-dev-setup
```

Claude can run the `defaults`, Homebrew, fnm, and skills steps directly. It can't type a `sudo` password or complete a browser login — run those yourself with the `!` prefix so the output stays in the session.

Config restore:

- Global `CLAUDE.md` and `settings.json` — restore from the saved copies
- `CLAUDE.md` for projects lives in each repo directly
- Skills need `npx`, so they come after Node — see [Appendix A](#appendix-a-claude-skills)

## 6. Machine name

```bash
sudo scutil --set ComputerName "mbp1" &&
sudo scutil --set LocalHostName "mbp1" &&
sudo scutil --set HostName "mbp1" &&
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
brew install git gh stripe/stripe-cli/stripe
```

Git config:

```bash
git config --global user.name "Max Hirtenstein" &&
git config --global user.email "maxhirtens@gmail.com" &&
git config --global github.user "maxhirtens" &&
git config --global init.defaultBranch main &&
git config --global --list
```

## 9. Node via fnm

Installs `fnm`, Node 24 (the Vercel prod runtime), sets it as the global default, and wires up auto-switching so any repo with a `.nvmrc` or `.node-version` picks up its version on `cd`. Idempotent — safe to re-run.

```bash
brew install fnm \
  && eval "$(fnm env --use-on-cd --shell zsh)" \
  && fnm install 24 \
  && fnm default 24 \
  && { grep -qs 'fnm env' ~/.zshrc \
       || printf '\n# fnm\neval "$(fnm env --use-on-cd --shell zsh)"\n' >> ~/.zshrc; }
```

Restart the terminal (or `source ~/.zshrc`), then verify — expect `v24.x`:

```bash
node -v && npm -v
```

## 10. Shell config

Everything else that belongs in `~/.zshrc`, on top of the fnm line from [step 9](#9-node-via-fnm) — PATH de-duplication, git branch helpers, and a one-shot update command. Idempotent — safe to re-run.

```bash
grep -qs 'typeset -U path' ~/.zshrc || cat >> ~/.zshrc <<'EOF'

typeset -U path PATH

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
    local cur b gone
    cur="$(git branch --show-current)"

    # fast-forward branches we already have
    [[ -n "$cur" ]] && git merge --ff-only '@{u}' >/dev/null 2>&1 && echo "  ff  $cur (current)"
    for b in $(git for-each-ref --format='%(refname:short)' refs/heads); do
      [[ "$b" == "$cur" ]] && continue
      git fetch -q origin "$b:$b" 2>/dev/null && echo "  ff  $b"
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
    [[ -n "$gone" ]] && echo "  stale (remote deleted): $(echo $gone | tr '\n' ' ')"
    return 0
  fi

  git checkout main && git pull origin main || return 1
  [[ "$target" == dev ]] || return 0
  git checkout development && git pull origin development
}

# up — update everything
alias up='brew update && brew upgrade && brew cleanup && brew autoremove; npm update -g; npx skills update -g; softwareupdate -l'
EOF
```

Restart the terminal (or `source ~/.zshrc`), then verify:

```bash
type pull | head -1 && alias up
```

| Command           | Does                                                                                   |
| ----------------- | -------------------------------------------------------------------------------------- |
| `typeset -U path` | Keeps PATH de-duplicated, so prepends can't stack up across nested shells                |
| `pull main`       | `checkout main` → `pull origin main`                                                     |
| `pull dev`        | Same, then `development` — ends on `development`                                         |
| `pull all`        | Fetches every branch, fast-forwards all locals, creates locals for branches pushed from another machine — never switches branches |
| `up`              | Brew update/upgrade/cleanup/autoremove, global npm, Claude skills, lists macOS updates   |

`pull` bails with a readable message — before switching branches — if the directory isn't a git repo or has no `origin`. A missing local `development` is fine: git creates it tracking `origin/development`.

`pull all` is the one to run after pushing work from another machine. It prunes deleted remotes, fast-forwards local branches in place without checking them out, and creates a local tracking branch for anything new on `origin`. Branches whose remote was deleted are listed as `stale` rather than removed — deletion stays a manual call.

## 11. GitHub auth

```bash
gh auth login
```

Choose **HTTPS** when prompted.

Node and `gh` are both in place now — this is the point to come back and install skills from [Appendix A](#appendix-a-claude-skills).

## 12. GUI apps (casks)

```bash
brew install --cask vlc cursor zoom spotify superduper transmission private-internet-access
```

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
  }
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

- SuperDuper
- Loopback
- AppZapper
- Titan Firmware and App _(optional)_
- GLM _(optional)_
- SoundID Reference _(optional)_

---

## Appendix A: Claude skills

### Global skills — npx registry

Each block installs one source repo globally for Claude Code. Run them together or one at a time.

```bash
npx skills add inngest/inngest-skills \
  --skill inngest-durable-functions \
  --skill inngest-events \
  --skill inngest-middleware \
  --skill inngest-setup \
  --skill inngest-steps \
  -g -a claude-code -y

npx skills add addyosmani/agent-skills \
  --skill api-and-interface-design \
  --skill code-review-and-quality \
  --skill code-simplification \
  --skill frontend-ui-engineering \
  --skill security-and-hardening \
  --skill performance-optimization \
  -g -a claude-code -y

npx skills add addyosmani/web-quality-skills \
  --skill seo \
  -g -a claude-code -y

npx skills add coreyhaines31/marketingskills \
  --skill copywriting \
  --skill marketing-ideas \
  --skill marketing-psychology \
  -g -a claude-code -y

npx skills add stripe/ai \
  --skill stripe-best-practices \
  --skill upgrade-stripe \
  -g -a claude-code -y

npx skills add vercel-labs/agent-skills \
  --skill react-best-practices \
  -g -a claude-code -y

npx skills add vercel-labs/skills \
  --skill find-skills \
  -g -a claude-code -y

npx skills add neondatabase/agent-skills \
  --skill neon-postgres \
  -g -a claude-code -y
```

### Custom skills

Source of truth is the repo in `Code/` — symlink each skill into `~/.agents/skills` so edits flow both ways. Clone first, then link:

```bash
git clone https://github.com/maxhirtens/maxhirtens-skills.git ~/Desktop/Code/maxhirtens-skills

mkdir -p ~/.agents/skills
ln -s ~/Desktop/Code/maxhirtens-skills/maxhirtens-fix-or-feature ~/.agents/skills/
ln -s ~/Desktop/Code/maxhirtens-skills/maxhirtens-ship-to-main ~/.agents/skills/
```

Then link the same directories into the global Claude skills dir:

```bash
mkdir -p ~/.claude/skills
ln -s ~/Desktop/Code/maxhirtens-skills/maxhirtens-fix-or-feature ~/.claude/skills/
ln -s ~/Desktop/Code/maxhirtens-skills/maxhirtens-ship-to-main ~/.claude/skills/
```

Verify both sets of links resolve:

```bash
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
| `mechatroner.rainbow-csv`                | CSV column highlighting        |
| `tomoki1207.pdf`                         | PDF preview                    |
