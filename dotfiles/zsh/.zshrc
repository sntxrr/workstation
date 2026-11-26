# BEGIN ANSIBLE MANAGED BLOCK - asdf
# asdf configuration (v0.16.0+)
export ASDF_DATA_DIR="${HOME}/.asdf"
export PATH="${ASDF_DATA_DIR}/shims:$PATH"
# END ANSIBLE MANAGED BLOCK - asdf
export PATH="$HOME/.local/bin:$PATH"  # starship/lla live here on Linux
eval "$(starship init zsh)"
# BEGIN ANSIBLE MANAGED BLOCK - terminal aliases
# add some favorite aliases
alias gfp="git fetch && git pull -p"
alias cdg="cd ~/git"
# gcl/gcm used to checkout + `xargs git branch -D`; both now go through refresh_repo
alias gcl="refresh_repo"
alias gcm="refresh_repo"
alias ll="lla -l"
alias rr="refresh_repo"
if [[ "$OSTYPE" == darwin* ]]; then
  alias update='brew update && brew upgrade && brew cleanup'
else
  alias update='sudo apt update && sudo apt full-upgrade && flatpak update'
fi
# END ANSIBLE MANAGED BLOCK - terminal aliases
export PATH="$PATH:$HOME/.local/bin"
# BEGIN ANSIBLE MANAGED BLOCK - terminal zsh config
# remove compdef error
autoload -Uz compinit && compinit -u

# pipx autocompletion
command -v register-python-argcomplete >/dev/null && eval "$(register-python-argcomplete pipx)"

# run hyfetch on login. No runtime light/dark probe: it sends an OSC 11 query
# and reads stdin for the reply, swallowing anything typed ahead -- e.g. the
# `claude --resume <id>` herdr types into a fresh pane on restore.
command -v hyfetch >/dev/null && hyfetch --auto-detect-light-dark=false
# END ANSIBLE MANAGED BLOCK - terminal zsh config
# BEGIN ANSIBLE MANAGED BLOCK - terminal functions
# refresh the default branch and drop branches whose PR has merged
#
# Deliberately does NOT stash, checkout, or delete unconditionally:
#  - the stash stack is shared by every worktree of a repo, so a bare
#    `stash pop` can pop another session's work onto main;
#  - `git checkout` moves the shared tree under every other session;
#  - `git branch` marks worktree branches with a leading `+`, which the old
#    `| xargs git branch -D` passed to git as a branch called "+";
#  - a squash merge leaves no ancestry, so `--merged` never lists it; the PR
#    state is the only truthful gate, and without `gh` nothing is deleted.
refresh_repo() {
  emulate -L zsh -o pipefail
  local default_branch cur br wt state
  if git show-ref --verify --quiet refs/heads/main; then
    default_branch=main
  else
    default_branch=master
  fi
  cur=$(git branch --show-current)
  if [[ "$cur" != "$default_branch" ]]; then
    print -u2 "refresh_repo: tree is on '$cur', not '$default_branch' -- refusing to checkout under other sessions"
    return 1
  fi
  git pull --ff-only --prune || return
  git for-each-ref --format='%(refname:short)%09%(worktreepath)' refs/heads |
  while IFS=$'\t' read -r br wt; do
    [[ "$br" == "$default_branch" ]] && continue
    if [[ -n "$wt" ]]; then
      print "keep  $br  (worktree: $wt)"
      continue
    fi
    if ! command -v gh >/dev/null 2>&1; then
      print "keep  $br  (gh not installed; cannot confirm its PR merged)"
      continue
    fi
    state=$(gh pr view "$br" --json state --jq .state 2>/dev/null)
    if [[ "$state" == MERGED ]]; then
      git branch -D "$br"
    else
      print "keep  $br  (PR state: ${state:-none})"
    fi
  done
}
# END ANSIBLE MANAGED BLOCK - terminal functions
[[ "$OSTYPE" == darwin* ]] && alias tailscale="/Applications/Tailscale.app/Contents/MacOS/Tailscale"

export NVM_DIR="$HOME/.nvm"
[ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh"  # This loads nvm
[ -s "$NVM_DIR/bash_completion" ] && \. "$NVM_DIR/bash_completion"  # This loads nvm bash_completion

# Resolve op:// secret references in ~/.hermes/.env (e.g. OPENROUTER_API_KEY)
# at launch time instead of storing plaintext keys on disk.
# --no-masking: op run's stdout/stderr secret-scanning buffers output and
# mangles hermes's ANSI redraws (color/formatting break); the key itself
# is still only ever passed via env, never printed by hermes.
alias hermes="op run --no-masking --env-file ~/.hermes/.env -- $HOME/.local/bin/hermes"

# claude is NOT wrapped in `op run` (since 2026-10-09). The home-assistant and n8n-mcp
# MCP tokens come from 1Password per connection via headersHelper
# (~/.claude/mcp-headers/op-bearer.sh, set in ~/.claude.json), so a locked 1Password
# costs those two MCP servers, not the session, and herdr's typed
# `claude --resume <id>` starts without waiting for an approval.
# opencode: plain `opencode` has NO models (~/.config/opencode: enabled_providers ["none"]),
# so it can neither load local Ollama on ufo nor reach a remote provider.
# `ocfree`: free no-training remote models, only for public/throwaway code. It uses its own
# config home (~/.config/opencode-free: remote providers only, skills/outside-dir/execute/
# subagent denied, shell/web ask) and a scrubbed env (no ssh agent, gh/op config, or tokens
# beyond the free-LLM keys from op://homelab/free-llm-* via op.env). --standalone so a keyless
# background service is never reused.
OCFREE_DIRS=("$HOME/git/scratch")
ocfree() {
    local here="${PWD:A}" d ok=""
    for d in "${OCFREE_DIRS[@]}"; do
        [[ "$here/" == "${d:A}/"* ]] && ok=1
    done
    if [[ -z "$ok" ]]; then
        print -u2 "ocfree: refusing in $here; free remote models only run under: ${OCFREE_DIRS[*]}"
        return 1
    fi
    local sub=()
    case "${1:-}" in
        run|mini|models) sub=("$1"); shift ;;
        ""|-*) ;;
        *) print -u2 "ocfree: unsupported subcommand '$1' (use plain opencode)"; return 1 ;;
    esac
    # SHELL wrapper unsets the provider keys for the model's shell tool (measured: printenv
    # read them otherwise). MODELS_FETCH off: all models are defined in the profile, and the
    # models.dev fetch hung every opencode start on 2026-10-09.
    local keep=(HOME="$HOME" USER="$USER" LOGNAME="$LOGNAME" PATH="$PATH"
                SHELL="$HOME/.config/opencode-free/shell.sh" OPENCODE_DISABLE_MODELS_FETCH=1
                TERM="$TERM" LANG="${LANG:-en_US.UTF-8}" TMPDIR="$TMPDIR")
    [[ -n "${COLORTERM:-}" ]] && keep+=(COLORTERM="$COLORTERM")
    [[ -n "${TERM_PROGRAM:-}" ]] && keep+=(TERM_PROGRAM="$TERM_PROGRAM")
    keep+=(${(M)${(@f)"$(env)"}:#HERDR_*})   # herdr pane integration
    env -i "${keep[@]}" op run --no-masking --env-file ~/.config/opencode/op.env -- \
        env XDG_CONFIG_HOME="$HOME/.config/opencode-free" opencode "${sub[@]}" --standalone "$@"
}
# herdr: verified snapshot -> stop -> relaunch (run from a NON-herdr tab)
alias herdr-restart="herdr-down --restart"

# swamp: wire 1Password (Private vault) into the current swamp repo as `secrets`.
# Usage: cd <swamp-repo> && swamp-1p   →   reference secrets via ${{ vault.get(secrets, KEY) }}
swamp-1p() {
  [ -f .swamp.yaml ] || { echo "swamp-1p: not a swamp repo (no .swamp.yaml here)"; return 1; }
  swamp extension pull @swamp/1password &&
  swamp vault create @swamp/1password secrets --config '{"op_vault":"Private"}'
}
# reminder: store a secret → `swamp vault put secrets KEY` (prompts) · use it → ${{ vault.get(secrets, KEY) }}

# SNTXRR truecolor login banner
[[ -r ~/.hermes/assets/sntxrr_banner.zsh ]] && source ~/.hermes/assets/sntxrr_banner.zsh

# Scaleway CLI: credentials resolved from 1Password per call (see ~/.config/scw/op.env)
scw() { op run --env-file "$HOME/.config/scw/op.env" -- command scw "$@"; }


# Added by Antigravity CLI installer
export PATH="$HOME/.local/bin:$PATH"

# Private, per-machine settings (hostnames etc.). Not in the public repo:
# swamp writes it from 1Password (item "zshrc-local") via the workstation-private behavior.
[[ -r ~/.zshrc.local ]] && source ~/.zshrc.local
