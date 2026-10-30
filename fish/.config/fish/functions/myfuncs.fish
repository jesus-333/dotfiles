# myfuncs — List the custom fish functions of this repo, each with its short
# description.
#
# Usage:  myfuncs [-a|--all] [-h|--help]
#
# Why: there are many custom functions (sb, sbs, hs-backup, ...) and it is easy
# to forget their names. This prints a one-line summary for each of them; the
# details of a single function are in its own help (e.g. `hs-backup --help`).
#
# The list is built from the files in the folder that contains this file
# (the functions/ folder of the fish package), so new functions show up
# automatically: nothing has to be registered here. The description printed is
# the one given with `function <name> --description '...'`.
# Private helpers (names starting with "_", e.g. __hs_api) are hidden unless
# -a/--all is given.

function myfuncs --description 'List the custom fish functions with a short description'
    # --- 1. Parse options ------------------------------------------------------
    # argparse removes recognised flags from $argv and sets $_flag_all /
    # $_flag_help when they are given. Unknown flags make argparse fail.
    argparse a/all h/help -- $argv; or return 1

    if set -q _flag_help
        echo "usage: myfuncs [-a|--all]"
        echo
        echo "List the custom fish functions with their short description."
        echo "Use <function> --help for the details of a single function."
        echo
        echo "  -a, --all    also list the private helpers (names starting with _)"
        return 0
    end

    # --- 2. Find the function files ----------------------------------------------
    # `status current-filename` is the path of this file, so its folder is the
    # functions/ folder of the fish package (wherever it is linked from).
    set -l dir (path dirname (status current-filename))

    # `path basename -E` drops the folder and the .fish extension: one name per file.
    set -l names (path basename -E $dir/*.fish)

    # Without --all, keep only the names that do NOT start with "_".
    # string match -v inverts the match; -r uses a regular expression.
    if not set -q _flag_all
        set names (string match -v -r '^_' -- $names)
    end

    # --- 3. Column width -------------------------------------------------------------
    # Width of the longest name, so the descriptions start in the same column.
    # string length prints one length per name; math max takes the largest.
    set -l width (math max (string length -- $names | string join ,))

    # --- 4. Print name + description ----------------------------------------------------
    for name in $names
        # `functions -q` is true if the function exists; it also autoloads it
        # from its file (this only defines it, nothing is run).
        functions -q $name; or continue

        # `functions --details --verbose` prints 5 lines about the function;
        # the 5th is its description, or "n/a" when it has none.
        set -l desc (functions --details --verbose $name)[5]
        test "$desc" = n/a; and set desc ''

        # %-*s pads the name with spaces up to $width characters.
        printf "%-*s  %s\n" $width $name $desc
    end
end
