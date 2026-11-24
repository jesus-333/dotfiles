# __sb_suffix — Sandbox name suffix from the -t / -n flags parsed by argparse.
#
# Called right after `argparse ... t/tmp n/nomem -- $argv` inside sb / sbk /
# sbs / sbr: argparse sets $_flag_tmp / $_flag_nomem in the CALLER's scope, and
# fish functions do not see the caller's local variables, so the caller passes
# them explicitly:
#     set -l suffix (__sb_suffix "$_flag_tmp" "$_flag_nomem")
# Prints "tmp", "nomem" or nothing (Hindsight sandbox).
function __sb_suffix --description 'Sandbox name suffix (tmp|nomem|"") from the -t/-n flag values'
    if test -n "$argv[1]"
        echo tmp
    else if test -n "$argv[2]"
        echo nomem
    end
end
