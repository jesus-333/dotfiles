This folder contains material related to the nvim config (screenshots, keybindings, LSP notes, colors).
The configs of the other tools (fish, yazi, starship, ...) now live in their own stow package in the [dotfiles](https://github.com/jesus-333/dotfiles) repository.

<!-- - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -  -->

# tmux
**No longer used.** `.tmux.conf` is kept only as an old reference.

## Load  config
The tmux config are saved in .tmux.conf
To load the configuration run the command
```
tmux source .config/nvim/other/.tmux.conf
```

<!-- - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -  -->

# Ghostty

## Problem with ssh 

From Ghostty [website](https://ghostty.org/docs/help/terminfo#ssh) :

> If you use SSH to connect to other machines that do not have Ghostty's terminfo entry, you will see error messages like missing or unsuitable terminal: xterm-ghostty, Error opening terminal: xterm-ghostty. or WARNING: terminal is not fully functional.
> Hopefully someday Ghostty will have terminfo entries pre-distributed everywhere, but in the meantime there are two ways to resolve the situation:
> 1 - Copy Ghostty's terminfo entry to the remote machine.
> 2 - Configure SSH to fall back to a known terminfo entry.

Between the two solution proposed I like this one :
```bash
infocmp -x xterm-ghostty | ssh YOUR-SERVER -- tic -x -
```
