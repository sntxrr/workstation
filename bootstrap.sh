#!/bin/sh
# Swampstrap a fresh workstation. From a real terminal:
#
#   sh -c "$(curl -fsSL https://raw.githubusercontent.com/sntxrr/workstation/main/bootstrap.sh)"
#
# (`sh -c "$(curl ...)"`, not `curl ... | sh`: sudo, swamp, 1Password and gh all
# need to prompt on the terminal.) Safe to re-run: finished steps are skipped.
set -eu

REPO_URL="${REPO_URL:-https://github.com/sntxrr/workstation.git}"
REPO_DIR="${REPO_DIR:-$HOME/git/workstation}"
export PATH="$HOME/.local/bin:$PATH"

pause() { printf '\n%s\nPress Enter when done... ' "$1"; read -r _ </dev/tty; }

# Cache sudo once. The dotfiles extension uses `sudo -n` for apt and chsh,
# which then succeeds for the rest of this terminal session.
echo "==> sudo (for apt and chsh)"
sudo -v

need=""
command -v curl >/dev/null 2>&1 || need="$need curl"
command -v git  >/dev/null 2>&1 || need="$need git"
if [ -n "$need" ]; then
  echo "==> installing$need"
  sudo apt-get update -qq && sudo apt-get install -y $need
fi

if [ ! -f "$REPO_DIR/.swamp.yaml" ]; then
  echo "==> cloning $REPO_URL"
  mkdir -p "$(dirname "$REPO_DIR")"
  git clone "$REPO_URL" "$REPO_DIR"
fi
cd "$REPO_DIR"

if ! command -v swamp >/dev/null 2>&1; then
  echo "==> installing swamp into ~/.local/bin"
  mkdir -p "$HOME/.local/bin"
  curl -fsSL https://swamp-club.com/install.sh | sh -s -- -d "$HOME/.local/bin"
fi

if ! swamp auth whoami >/dev/null 2>&1; then
  echo "==> signing in to swamp-club"
  swamp auth login
fi

echo "==> restoring pinned extensions"
swamp extension install

# Stage 1: everything that doesn't need secrets (includes 1Password + gh).
echo "==> applying base workstation"
swamp behavior run workstation apply

# Stage 2: 1Password must be signed in for the vault-backed items.
if ! op whoami >/dev/null 2>&1; then
  pause "Open 1Password, sign in, then enable Settings > Developer > 'Integrate with 1Password CLI'."
  op whoami >/dev/null 2>&1 || op signin >/dev/null
fi
echo "==> applying private workstation settings (from 1Password)"
swamp behavior run workstation-private apply

if ! gh auth status >/dev/null 2>&1; then
  echo "==> signing in to GitHub"
  gh auth login
fi

echo "==> done. Log out and back in to pick up zsh as your login shell."
