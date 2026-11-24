# __sb_name — Sandbox name used by sb / sbk / sbs / sbr.
#
# Usage:  __sb_name <dir> <agent> [suffix]
#
# The name is <folder>-<agent>[-<suffix>], lowercase, only a-z 0-9 -.
# The suffix separates the sandboxes without memory from the Hindsight one of
# the same folder:
#   (none)   linked to the Hindsight bank       e.g. dotfiles-claude
#   tmp      throwaway, deleted on exit (sb -t) e.g. dotfiles-claude-tmp
#   nomem    no memory, kept (sb -n)            e.g. dotfiles-claude-nomem
function __sb_name --description 'Valid sandbox name for <dir> <agent> [suffix]: lowercase, only a-z 0-9 -'
    set -l base (string lower -- (basename $argv[1]))
    set base (string replace -ra -- '[^a-z0-9-]+' '-' $base)   # _ . spaces … → -
    set base (string trim -c '-' -- $base)
    set -l name $base-$argv[2]
    set -q argv[3]; and test -n "$argv[3]"; and set name $name-$argv[3]
    echo $name
end
