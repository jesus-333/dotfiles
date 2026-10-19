# dotfiles
Repo with the configs for several tools. Built around [GNU Stow](https://www.gnu.org/software/stow/).

Each top-level folder is a **stow package** whose content mirrors the home folder.
Running `stow <package>` creates the symlinks in `~` that point back to this repo.

| Package         | Linked to                    |
|-----------------|------------------------------|
| `nvim`          | `~/.config/nvim`             |
| `fish`          | `~/.config/fish`             |
| `yazi`          | `~/.config/yazi`             |
| `karabiner`     | `~/.config/karabiner`        |
| `starship`      | `~/.config/starship.toml`    |
| `sbx-hindsight` | `~/sbx-hindsight/kits`       |

`extras/` is **not** a stow package. It contains files that are not configs (nerd fonts, keyboard layout).

<!-- - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -  -->

# Install
```bash
brew install stow
git clone https://github.com/jesus-333/dotfiles.git
cd dotfiles

mkdir -p ~/.config   # so stow links the single tool folders and not the whole ~/.config
stow nvim fish yazi karabiner starship sbx-hindsight
```
The target (`~`) is set in `.stowrc`, so `stow` must be run from the repo root. `.DS_Store` files are ignored.

Other useful commands
```bash
stow -n -v nvim     # dry run: show what would be linked
stow -D nvim        # remove the symlinks of a package
stow -R nvim        # restow (e.g. after adding new files to a package)
```

## Replacing an existing config
Stow refuses to overwrite real files. If a config already exists (e.g. `~/.config/nvim`), move it away first and then stow the package
```bash
mv ~/.config/nvim ~/.config/nvim.bak
stow nvim
```

## Fonts
Install the nerd fonts by copying them to the fonts folder
```bash
cp extras/nerdfonts/* ~/Library/Fonts/
```

<!-- - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -  -->

# Add a new tool
1. Create a folder with the name of the tool and reproduce the path relative to `~` inside it, e.g. `ghostty/.config/ghostty/config.ghostty`
2. Move the existing config inside it
3. Run `stow <tool>`
4. If the tool writes machine-specific/generated files inside its config folder, add them to `.gitignore`

<!-- - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -  -->

# Notes on the packages

## nvim
`nvim/.config/nvim` is the only source of truth for the Neovim config. It is also published in the standalone [neovim-config](https://github.com/jesus-333/neovim-config) repo, so it can be installed on machines where only Neovim is needed.
Keep the folder self-contained (no references to the rest of this repo).
`nvim/.config/nvim/other` contains extra material for the nvim config (screenshots, keybindings, LSP notes) and the old `.tmux.conf` (not used anymore, kept as reference).

## fish
`fish_variables` is not tracked: fish rewrites it continuously and it contains machine state (universal variables).

## yazi
Install/Update
```bash
rustup update
cargo install --locked yazi-fm yazi-cli
```
Plugins are saved in `plugins/` and listed in `package.toml`.

## karabiner
Karabiner-Elements rewrites `karabiner.json` by replacing the file, which would break a symlink pointing to the single file.
For this reason the **whole** `~/.config/karabiner` folder must be a symlink. This is what stow does by default if `~/.config/karabiner` does not exist when running `stow karabiner`.
The automatic backups created by Karabiner are not tracked.

## sbx-hindsight
Kits used to create the docker sandboxes (`sbx`). Only `kits/` is tracked; the Hindsight backups (`~/sbx-hindsight/backups`, created by `hs-backup`) are not.
