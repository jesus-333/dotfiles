# sbk — Delete an agent sandbox created by `sb`.
#
# Usage:  sbk [-t | -n] claude|codex|pi [dir]
#
# The flags select the same sandbox `sb` would use:
#   sbk claude      <folder>-claude        (Hindsight memory)
#   sbk -t claude   <folder>-claude-tmp    (throwaway; normally already deleted
#                                           by sb, needed only for leftovers)
#   sbk -n claude   <folder>-claude-nomem  (no memory, kept)
# Files in [dir] are on the host and are not touched. Save the agent sessions
# first with `sbs` if you want to restore them later.

function sbk --description 'Delete an agent sandbox: sbk [-t|-n] <claude|codex|pi> [dir]'
    argparse -x t,n h/help t/tmp n/nomem -- $argv; or return 1

    if set -q _flag_help
        echo "usage: sbk [-t | -n] claude|codex|pi [dir]"
        echo
        echo "Delete the sandbox 'sb' created for [dir] (default: current folder)."
        echo "  -t, --tmp    the throwaway one   (<folder>-<agent>-tmp)"
        echo "  -n, --nomem  the no-memory one   (<folder>-<agent>-nomem)"
        return 0
    end

    if not contains -- "$argv[1]" claude codex pi
        echo "usage: sbk [-t | -n] claude|codex|pi [dir]   (sbk --help for details)" >&2
        return 1
    end
    set -l dir $PWD
    if set -q argv[2]
        set dir (realpath $argv[2]); or return 1
    end
    set -l suffix (__sb_suffix "$_flag_tmp" "$_flag_nomem")
    sbx rm -f (__sb_name $dir $argv[1] $suffix)
end
