# Sourced from ~/.zshrc — see README step 10. Edit here, not in ~/.zshrc.

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

# nodeup — install the newest Node 24 and make it the default.
# fnm keeps global npm packages per version, so a new patch starts with none; copy them over from the old default.
nodeup() {
  local prev new pkgs
  prev=$(fnm list | awk '/default/ {print $2}')
  fnm install 24 && fnm default 24 && fnm use 24 || return 1
  new=$(fnm current)
  [[ -z "$prev" || "$prev" == system || "$prev" == "$new" ]] && return 0
  pkgs=$(fnm exec --using="$prev" npm ls -g --depth=0 --json | python3 -c 'import json,sys
print(" ".join(p for p in json.load(sys.stdin).get("dependencies", {}) if p not in ("npm", "corepack")))')
  [[ -n "$pkgs" ]] && npm install -g ${=pkgs}
  echo "nodeup: $prev -> $new. Remove the old one with: fnm uninstall $prev"
}

# up — update everything
alias up='brew update && brew upgrade --greedy && brew cleanup && brew autoremove; nodeup; npm update -g; npx skills update -g -y; plugup; softwareupdate -l'
