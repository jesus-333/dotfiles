# stow-factory-reset — Recreate from scratch the stow symlinks of all the tools
# listed in tools_list.txt, using the stow folder you are in.
#
# Usage:  cd <stow folder>; stow-factory-reset [-n|--dry-run]
#
# Why: when you switch to another stow folder (e.g. dotfiles -> dotconfig_V2),
# or when some links are broken, the old symlinks must be removed before the
# new ones can be created (stow refuses to overwrite anything it does not own,
# and a single conflict makes it abort ALL the packages). On top of that some
# tools recreate their config folder as soon as it disappears. This function
# does all the steps in one go:
#   1. read tools_list.txt (one tool per line, '#' starts a comment)
#   2. check that every listed tool has its folder (package) here
#   3. find the old symlinks of each tool, wherever they point to
#   4. stop, without changing anything, if a real file is in the way
#   5. remove the old symlinks and run stow to create the new ones
#
# Particular aspects of this config:
#   fish       a running fish shell recreates ~/.config/fish (with a default
#              config.fish) when it is missing. If ~/.config/fish is a real
#              folder it is moved to a backup folder. Your fish_variables
#              (universal variables, not tracked by git) is copied into the
#              new package, so it is not lost.
#   karabiner  Karabiner-Elements rewrites/recreates ~/.config/karabiner while
#              it runs and there is no reliable way to stop it from the shell,
#              so you are asked to confirm that it is closed. A recreated real
#              ~/.config/karabiner folder is moved to the backup folder as well.
#   ~/.config  always kept as a real folder, so stow links the single tool
#              folders inside it and not the whole ~/.config.

function stow-factory-reset --description 'Remove the old stow links of the tools in tools_list.txt and stow them from the current folder'
    # --- 1. Parse options ------------------------------------------------------
    # argparse removes recognised flags from $argv and sets $_flag_help /
    # $_flag_dry_run when -h/--help or -n/--dry-run are given. Unknown flags
    # make argparse fail with an error.
    argparse h/help n/dry-run -- $argv; or return 1

    if set -q _flag_help
        echo "usage: stow-factory-reset [-n|--dry-run]"
        echo
        echo "Run it inside a stow folder that contains tools_list.txt (one tool per line)."
        echo "Removes the old symlinks of the listed tools (wherever they point to) and"
        echo "creates the new ones with stow from the current folder."
        echo
        echo "  -n, --dry-run   only show what would be done, change nothing"
        return 0
    end

    # Tools that recreate their folder in ~/.config while running (see header).
    set -l recreating_tools fish karabiner

    # The stow folder is the current folder. $PWD is always an absolute path.
    set -l stow_dir $PWD

    # --- 2. Check that stow is installed -----------------------------------------
    if not type -q stow
        echo "stow-factory-reset: stow is not installed (brew install stow)" >&2
        return 1
    end

    # --- 3. Read tools_list.txt --------------------------------------------------
    # The file must exist in the current folder, otherwise this is probably not
    # a stow folder and nothing is done.
    if not test -f $stow_dir/tools_list.txt
        echo "stow-factory-reset: tools_list.txt not found in $stow_dir" >&2
        echo "Run the command inside your stow folder." >&2
        return 1
    end

    # string trim removes spaces at the start/end of each line.
    # string match -v -r '^(#|$)' drops the lines that are empty or start with
    # '#', so the file can contain comments and blank lines.
    set -l tools (string trim < $stow_dir/tools_list.txt | string match -v -r '^(#|$)')

    if test (count $tools) -eq 0
        echo "stow-factory-reset: tools_list.txt does not contain any tool" >&2
        return 1
    end

    # --- 4. Check that every tool has its folder ---------------------------------
    # All the tools are checked before stopping, so you see every missing
    # folder at once instead of one per run. A tool name must be a plain
    # folder name (no '/'), because it is used to recognise the old links.
    set -l missing
    for tool in $tools
        if string match -q -- '*/*' $tool; or not test -d $stow_dir/$tool
            set -a missing $tool
        end
    end
    if test (count $missing) -gt 0
        echo "stow-factory-reset: these tools have no folder in $stow_dir:" >&2
        printf '  %s\n' $missing >&2
        return 1
    end

    # --- 5. Karabiner must be closed ---------------------------------------------
    # There is no reliable way to stop Karabiner-Elements and its background
    # services from here, so ask the user. read -P shows the prompt; only an
    # explicit y/Y continues. In dry-run mode nothing is changed, so no question.
    if contains -- karabiner $tools
        echo "Karabiner-Elements must be closed before running this command"
        echo "(menu bar icon -> Quit Karabiner-Elements)."
        if not set -q _flag_dry_run
            read -l -P "Is Karabiner-Elements closed? [y/N] " answer
            if not string match -q -r '^[yY]$' -- $answer
                echo "Aborted: nothing was changed."
                return 1
            end
        end
    end

    # --- 6. Find the old links, the folders to back up and the conflicts ---------
    # For every file of a package (e.g. nvim/.config/nvim/init.lua) the path
    # relative to the package (.config/nvim/init.lua) is where stow wants it
    # in ~. Stow creates ONE link at the first missing folder of that path
    # (e.g. ~/.config/nvim -> .../nvim/.config/nvim), so we walk the path one
    # piece at a time: .config, .config/nvim, .config/nvim/init.lua.
    # For each piece, ~/<piece> can be:
    #   - a symlink: if it ends with /<tool>/<piece> it is a stow link of this
    #     tool, created from ANY stow folder with this layout (this is how the
    #     links of the old folder are found) -> remove it. Any other symlink is
    #     not ours -> conflict.
    #   - a real folder: shared folder (e.g. ~/.config), go one level deeper.
    #     Exception: ~/.config/fish and ~/.config/karabiner, recreated by the
    #     tools -> back them up (see header).
    #   - a real file: stow cannot put its link there -> conflict.
    #   - missing: nothing to remove, stow will create the link here.
    set -l old_links        # symlinks to remove
    set -l backup_dirs      # real folders recreated by fish/karabiner
    set -l conflicts        # things in the way that we do not touch

    for tool in $tools
        # find lists all files and symlinks of the package. .DS_Store files are
        # skipped because stow ignores them too (see .stowrc).
        for file in (find $stow_dir/$tool -mindepth 1 \( -type f -o -type l \) ! -name .DS_Store)
            # Path relative to the package, e.g. .config/nvim/init.lua
            set -l rel (string replace -- "$stow_dir/$tool/" '' $file)

            set -l piece ''
            for part in (string split / -- $rel)
                # Add the next folder/file name to the piece of path
                if test -z "$piece"
                    set piece $part
                else
                    set piece $piece/$part
                end
                set -l target $HOME/$piece

                # test -L must come first: test -d/-e follow the symlinks
                if test -L $target
                    # readlink prints where the link points, e.g.
                    # ../Desktop/Projects/dotfiles/nvim/.config/nvim
                    set -l dest (readlink $target)
                    if string match -q -- "*/$tool/$piece" $dest
                        contains -- $target $old_links; or set -a old_links $target
                    else
                        contains -- "$target -> $dest" $conflicts
                        or set -a conflicts "$target -> $dest"
                    end
                    break
                else if test -d $target
                    if test "$piece" = ".config/$tool"; and contains -- $tool $recreating_tools
                        contains -- $target $backup_dirs; or set -a backup_dirs $target
                        break
                    end
                    continue
                else if test -e $target
                    contains -- $target $conflicts; or set -a conflicts $target
                    break
                else
                    break
                end
            end
        end
    end

    # If something is in the way, stop BEFORE changing anything.
    if test (count $conflicts) -gt 0
        echo "stow-factory-reset: these files are in the way and are not stow links:" >&2
        printf '  %s\n' $conflicts >&2
        echo "Move them away (or delete them) and run the command again. Nothing was changed." >&2
        return 1
    end

    # --- 7. fish_variables -------------------------------------------------------
    # fish_variables is not in git, it only lives inside the package folder
    # that ~/.config/fish points to. When switching stow folder, copy it into
    # the new package so the universal variables are kept. If the new package
    # already has one (e.g. it is the same folder) it is left untouched.
    set -l fish_vars_src $HOME/.config/fish/fish_variables
    set -l fish_vars_dst $stow_dir/fish/.config/fish/fish_variables
    set -l copy_fish_vars 0
    if contains -- fish $tools; and test -f $fish_vars_src; and not test -e $fish_vars_dst
        set copy_fish_vars 1
    end

    # Folder where the recreated fish/karabiner folders are moved,
    # e.g. ~/.stow-factory-reset-backup/20261019-153000/.config/fish
    set -l backup_root $HOME/.stow-factory-reset-backup/(date +%Y%m%d-%H%M%S)

    # --- 8. Dry run: show the plan and stop --------------------------------------
    if set -q _flag_dry_run
        echo "Stow folder: $stow_dir"
        echo "Tools:       $tools"
        echo
        echo "Old links to remove:"
        test (count $old_links) -gt 0; and printf '  %s -> %s\n' (for l in $old_links; echo $l; readlink $l; end)
        or echo "  (none)"
        echo "Real folders to move to $backup_root:"
        test (count $backup_dirs) -gt 0; and printf '  %s\n' $backup_dirs
        or echo "  (none)"
        test $copy_fish_vars -eq 1; and echo "Copy fish_variables into $fish_vars_dst"
        echo
        echo "Then run: stow --dir=$stow_dir --target=$HOME -v $tools"
        return 0
    end

    # --- 9. Apply: copy fish_variables, remove links, back up, stow --------------
    # These steps run one right after the other, so fish has no time to
    # recreate ~/.config/fish between the removal and the new links.
    if test $copy_fish_vars -eq 1
        cp $fish_vars_src $fish_vars_dst; or return 1
    end

    for link in $old_links
        # rm on a symlink removes only the link, never the folder it points to
        command rm -- $link; or return 1

        # Old links made file by file leave empty folders behind (e.g. an empty
        # ~/.config/fish/functions). Remove them, otherwise stow would see a
        # real folder and link file by file again. rmdir only removes EMPTY
        # folders, and folders directly in ~ (~/.config, ~/sbx-hindsight) are
        # always kept.
        set -l dir (path dirname $link)
        while test (path dirname $dir) != $HOME; and test $dir != $HOME
            rmdir $dir 2>/dev/null; or break
            set dir (path dirname $dir)
        end
    end

    # Move the recreated fish/karabiner folders out of the way (nothing is
    # deleted: you can find them in the backup folder).
    for dir in $backup_dirs
        # The dir may have been emptied and removed by the rmdir loop above
        test -d $dir; or continue
        set -l dest $backup_root/(path dirname (string replace -- "$HOME/" '' $dir))
        mkdir -p $dest; and mv $dir $dest/; or return 1
        echo "Moved $dir to $dest/"
    end

    # ~/.config must stay a real folder (see header)
    mkdir -p $HOME/.config

    # --dir/--target are given explicitly, so the command works even in a
    # stow folder without .stowrc. -v prints every link that is created.
    stow --dir=$stow_dir --target=$HOME --ignore='\.DS_Store' -v $tools
    or begin
        echo "stow-factory-reset: stow failed. The old links were already removed;" >&2
        echo "fix the problem above and run stow-factory-reset again." >&2
        return 1
    end

    # --- 10. What to do next -----------------------------------------------------
    echo
    echo "Done. Next steps:"
    contains -- fish $tools; and echo "  - open a new terminal tab (this shell still uses the old fish config)"
    contains -- karabiner $tools; and echo "  - start Karabiner-Elements again"
    contains -- ghostty $tools; and echo "  - quit Ghostty (Cmd+Q) and open it again"
    return 0
end
