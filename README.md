# dotfiles
Repo with the configs for several tools. Built around [GNU Stow](https://www.gnu.org/software/stow/).

Each top-level folder is a **stow package** whose content mirrors the home folder.
Running `stow <package>` creates the symlinks in `~` that point back to this repo.

| Package         | Linked to                    |
|-----------------|------------------------------|
| `nvim`          | `~/.config/nvim`             |
| `vim`           | `~/.vimrc`                   |
| `fish`          | `~/.config/fish`             |
| `yazi`          | `~/.config/yazi`             |
| `karabiner`     | `~/.config/karabiner`        |
| `starship`      | `~/.config/starship.toml`    |
| `ghostty`       | `~/.config/ghostty/config`   |
| `sbx-hindsight` | `~/sbx-hindsight/kits`       |

`extras/` is **not** a stow package. It contains files that are not configs (nerd fonts, keyboard layout).

<!-- - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -  -->

# Install
```bash
brew install stow
git clone https://github.com/jesus-333/dotfiles.git
cd dotfiles

mkdir -p ~/.config   # so stow links the single tool folders and not the whole ~/.config
stow nvim vim fish yazi karabiner starship ghostty sbx-hindsight
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
If a single conflict is found, stow aborts **all** the packages.
Some tools recreate their config folder as soon as it is missing (e.g. a running fish shell recreates `~/.config/fish`, Karabiner-Elements recreates `~/.config/karabiner`). Quit them, or move the folder and stow in a single command line
```fish
mv ~/.config/fish ~/.config/fish.bak; and stow fish
```

## Reset all the links (`stow-factory-reset`)
The fish function `stow-factory-reset` (in the `fish` package) recreates the links of all the tools listed in `tools_list.txt` (one per line). Run it from the stow folder, e.g. to switch to another stow folder or to fix broken links
```fish
cd ~/Desktop/Projects/dotfiles
stow-factory-reset -n   # dry run: show what would be done
stow-factory-reset
```
It removes the old links (even if they point to another stow folder), moves real `~/.config/fish` / `~/.config/karabiner` folders recreated by the tools to `~/.stow-factory-reset-backup/`, keeps `fish_variables`, and stops without changing anything if a real file is in the way. Karabiner-Elements must be closed.

## Fonts
Install the nerd fonts by copying them to the fonts folder
```bash
cp extras/nerdfonts/* ~/Library/Fonts/
```

<!-- - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -  -->

# Add a new tool
1. Create a folder with the name of the tool and reproduce the path relative to `~` inside it, e.g. `btop/.config/btop/btop.conf`
2. Move the existing config inside it
3. Run `stow <tool>`
4. If the tool writes machine-specific/generated files inside its config folder, add them to `.gitignore`

<!-- - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -  -->

# Notes on the packages

## nvim
`nvim/.config/nvim` is the only source of truth for the Neovim config. It is also published in the standalone [neovim-config](https://github.com/jesus-333/neovim-config) repo, so it can be installed on machines where only Neovim is needed.
Keep the folder self-contained (no references to the rest of this repo).
`nvim/.config/nvim/other` contains extra material for the nvim config (screenshots, keybindings, LSP notes) and the old `.tmux.conf` (not used anymore, kept as reference).

## vim
Single-file config (`.vimrc`, no plugins) used as a backup editor in case the Neovim config breaks. It mirrors the options and the main keymaps (movement, buffers, save/close) of the Neovim config. Colorscheme: built-in `habamax` (needs vim >= 9).
Plugin features replaced with built-in vim (leader = space):

| Keys | Action | Neovim equivalent |
|------|--------|-------------------|
| `<leader>f` | `:find` file in subfolders (Tab completes) | Telescope find_files |
| `<leader>t` / `<leader>gs` | `:Grep {pattern}` / word under cursor, results in quickfix | Telescope live_grep / grep_string |
| `<leader>bb` / `<leader>bo` / `<leader>br` | buffers / old files / registers | Telescope pickers |
| `<leader>e` | netrw file explorer | Yazi |
| `<leader>r1` / `<leader>r2` | replace in file / line | same |
| `<leader>cn` | open the Neovim config | alpha `cn` button |
| `((` `""` `''` ` `` ` `))` `"(` `("` `"'` `'"` | surround word / remove / replace | nvim-surround |
| `gcc` / `gc` | toggle comments | Comment.nvim |

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

## ghostty
On macOS Ghostty reads both `~/.config/ghostty/config` (XDG path, used here) and `~/Library/Application Support/com.mitchellh.ghostty/config`. The second one is loaded **after** and overrides the first, so it must not exist (or must be empty).

### Problem with ssh 

From Ghostty [website](https://ghostty.org/docs/help/terminfo#ssh) :

> If you use SSH to connect to other machines that do not have Ghostty's terminfo entry, you will see error messages like missing or unsuitable terminal: xterm-ghostty, Error opening terminal: xterm-ghostty. or WARNING: terminal is not fully functional.
> Hopefully someday Ghostty will have terminfo entries pre-distributed everywhere, but in the meantime there are two ways to resolve the situation:
> 1 - Copy Ghostty's terminfo entry to the remote machine.
> 2 - Configure SSH to fall back to a known terminfo entry.

Between the two solution proposed I like this one :
```bash
infocmp -x xterm-ghostty | ssh YOUR-SERVER -- tic -x -
```

## sbx-hindsight
Kits used to create the docker sandboxes (`sbx`). Only `kits/` is tracked; the Hindsight backups (`~/sbx-hindsight/backups`, created by `hs-backup` and `hs-snapshot`) are not.

### Check and update the Hindsight server (`hs-version`, `hs-update`)
```fish
hs-version      # running version, latest on ghcr.io (pulls :latest), latest plugin on npm
hs-update       # volume snapshot (hs-snapshot) + pin the new version in docker-compose.yml + recreate the container
hs-update -y    # same, without the confirmation (the snapshot is always done)
```
`hs-update` reads the compose file location from the container labels, keeps a `.bak-<timestamp>` copy of it next to the original, and refuses prerelease versions unless `--force` is given. If the new version does not start, nothing is rolled back automatically (migrations may have changed the data): restore the compose backup **and** the data backup.
The coding-agent plugin is not updated by `hs-update`: the `hindsight-memory` kit installs the latest one when an agent sandbox is created (`sbk` + `sb`).

### Back up and restore the memory banks (`hs-backup`, `hs-restore`)
They use only the Hindsight HTTP API (`curl` + `jq`), so the archives can be restored into **any** Hindsight instance (Docker, sbx, pip, remote), even one with another embedding model.
```fish
hs-backup                       # all banks -> ~/sbx-hindsight/backups/hindsight_backup_latest (replaced)
hs-backup --timestamp --note x  # new hindsight_backup_<YYYY-MM-DD_HHMMSS> folder, never overwritten
hs-restore --list               # list the backups
hs-restore --dry-run            # show what restoring the latest backup would do
hs-restore --bank <id> --as <new-id>   # load one bank under another id
hs-restore --replace            # overwrite existing banks (a pre-restore backup is made first)
```
`--url`, `--token` and `--dir` (or `HS_API_URL`, `HS_API_TOKEN`, `HS_BACKUP_DIR`) select another instance / backup folder; the defaults are `http://localhost:8888`, no token, `~/sbx-hindsight/backups`.
Each folder holds one `bank-<id>.zip` per bank and a `manifest.json` (date, note, source, sha256 and counts). Archives carry documents, facts, observations, mental models, knowledge pages and bank config, not the embeddings: the import re-embeds them (no LLM calls).
To move to a new instance, run `hs-restore --url <new-url>` **before** any agent uses it: banks are created on first use, and an existing bank blocks the import.

`hs-snapshot` (used by `hs-update`) is the old raw copy of the `hindsight-data` Docker volume: it only works with this sbx/Docker installation.
