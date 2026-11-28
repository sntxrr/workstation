# workstation

My Pop!_OS workstation as a [swamp](https://swamp-club.com) repo: shell, prompt,
fonts, CLIs, git identity, and 1Password-backed private settings, all declared
with [`@puddleworks/dotfiles`](https://swamp-club.com) and re-runnable with
`plan` / `apply` / `verify`.

## Swampstrap a fresh machine

From a real terminal (sudo, swamp, 1Password and gh all need to prompt):

```sh
sh -c "$(curl -fsSL https://raw.githubusercontent.com/sntxrr/workstation/main/bootstrap.sh)"
```

`bootstrap.sh` is the only part that isn't swamp: it installs swamp (which
can't install itself), signs in, restores the pinned extensions, applies the
base setup, waits for you to sign in to 1Password, then applies the private
setup. Every step is skipped if it's already done.

## What's managed

| Behavior | Manages |
|---|---|
| `workstation` | swamp, 1Password app + CLI, gh, starship + CaskaydiaCove Nerd Font, zsh + `.zshrc`, lla + synthwave_84 theme, exe.dev host key + agent skill, git config, Scaleway CLI, Beeper Desktop (AppImage repackaged as a `.deb`), Claude Code status line, Herdr nightwire layout |
| `workstation-private` | `~/.zshrc.local`, written from 1Password at apply time |
| `ufo` | The Mac mini, over ssh from here: starship config, Claude Code status line, Herdr nightwire layout |

The Herdr layout is [jpisgeek/nightwire](https://github.com/jpisgeek/nightwire),
installed by its own `install.sh` from a pinned commit; nothing of it is kept
in this repo. A `jq` step then applies my two size tweaks to the layout.

Source files live in `dotfiles/`; the item lists are in
`models/@puddleworks/dotfiles/`.

```sh
swamp behavior run workstation plan     # what would change
swamp behavior run workstation apply    # make it so
swamp behavior run workstation verify   # fail if the machine has drifted
```

## Secrets

None in this repo. Private values come from 1Password through a swamp vault
(`@swamp/1password`), and CLI credentials stay as `op://` references resolved
per call by `op run`.

## Notes

- Commands are guarded by `unless`; a guard that only checks "is it installed?"
  won't upgrade. lla and scw pin versions, so bumping the pin reinstalls them.
- Managed files are copies: edit them here, not in `~`, or the next `apply`
  overwrites your change (keeping one `.bak`).
- Removing an item stops managing it; it doesn't uninstall anything.
