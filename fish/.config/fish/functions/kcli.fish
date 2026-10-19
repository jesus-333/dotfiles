# kcli — Short name for the Karabiner-Elements command line tool (karabiner_cli).
#
# Usage:  kcli [karabiner_cli options]     e.g. kcli --help
#                                               kcli --select-profile Default
#
# Why: karabiner_cli is not in the PATH. It lives in
#   /Library/Application Support/org.pqrs/Karabiner-Elements/bin/karabiner_cli
# and the space in "Application Support" forces you to quote the whole path
# every time. This function stores the path once and forwards all arguments.

function kcli --description 'Run the Karabiner-Elements CLI (karabiner_cli), passing all arguments'
    # --- 1. Path of the real program --------------------------------------------
    # Single quotes keep the path as ONE word despite the space. Once it is in
    # a variable, fish never splits it again (fish does not split variables
    # on spaces), so $cli can be used without quotes below.
    set -l cli '/Library/Application Support/org.pqrs/Karabiner-Elements/bin/karabiner_cli'

    # --- 2. Check that it exists ------------------------------------------------
    # test -x is true if the file exists and can be executed. If Karabiner-
    # Elements is not installed, print a clear error (>&2 = to stderr) instead
    # of fish's generic "unknown command".
    if not test -x $cli
        echo "kcli: karabiner_cli not found at $cli (is Karabiner-Elements installed?)" >&2
        return 1
    end

    # --- 3. Run it ---------------------------------------------------------------
    # $argv contains all the arguments given to kcli, forwarded unchanged.
    # The exit status of karabiner_cli becomes the exit status of kcli.
    $cli $argv
end
