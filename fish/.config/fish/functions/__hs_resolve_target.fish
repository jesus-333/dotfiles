# __hs_resolve_target — Private helper of hs-backup / hs-restore: resolve ONE
# instance setting, in the order flag -> environment variable -> default.
#
# Usage:  set -l url   (__hs_resolve_target url   $_flag_url)
#         set -l token (__hs_resolve_target token $_flag_token)
#         set -l dir   (__hs_resolve_target dir   $_flag_dir)
#
#   setting  flag      env var        default
#   url      --url     HS_API_URL     http://localhost:8888
#   token    --token   HS_API_TOKEN   (none: no Authorization header is sent)
#   dir      --dir     HS_BACKUP_DIR  ~/sbx-hindsight/backups
#
# Why: the functions know nothing about how Hindsight is installed, only its
# API URL (and a token, if the server needs one). Keeping the resolution in
# one place makes hs-backup and hs-restore behave identically.

function __hs_resolve_target --description 'Resolve a Hindsight setting (url|token|dir): flag, then env var, then default'
    # $argv[1] is the setting name, $argv[2] the flag value (absent if the flag
    # was not given, because then $_flag_xxx is an empty list).
    set -l what $argv[1]
    set -l value $argv[2]

    # --- 1. Fall back to the environment variable, then to the default ----------
    switch $what
        case url
            test -n "$value"; or set value $HS_API_URL
            test -n "$value"; or set value http://localhost:8888
            # A trailing '/' would produce '//v1/...' when paths are appended.
            set value (string trim -r -c / -- $value)
        case token
            test -n "$value"; or set value $HS_API_TOKEN
        case dir
            test -n "$value"; or set value $HS_BACKUP_DIR
            test -n "$value"; or set value $HOME/sbx-hindsight/backups
            # An env var written as '~/x' is not expanded by fish: do it here.
            set value (string replace -r '^~(?=/|$)' $HOME -- $value)
        case '*'
            echo "__hs_resolve_target: unknown setting '$what'" >&2
            return 1
    end

    # --- 2. Print it (nothing at all for an unset token) ---------------------------
    test -n "$value"; and echo $value
    return 0
end
