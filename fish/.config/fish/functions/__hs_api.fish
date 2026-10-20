# __hs_api — Private helper of hs-backup / hs-restore: one call to the
# Hindsight HTTP API with curl.
#
# Usage:  __hs_api <url> <token> <METHOD> <path> [extra curl args...]
#   e.g.  __hs_api $url "$token" GET /v1/default/banks | jq ...
#         __hs_api $url "$token" GET $download_url -o archive.zip
#         __hs_api $url "$token" POST "$path?x=1" -F file=@archive.zip
#
# The response body goes to stdout (or to the file given with -o). On any
# failure (connection error, timeout, HTTP status >= 400) a message with the
# method, the path and the server's answer goes to stderr, and the exit
# status is non-zero, so every caller can simply check $status.
#
# The token (pass "" when there is none) is sent as "Authorization: Bearer"
# only if it is set. It is handed to curl on stdin (-H @-), never as a
# command-line argument, so it does not show up in `ps` and is never printed.

function __hs_api --description 'Call the Hindsight HTTP API: __hs_api <url> <token> <METHOD> <path> [curl args]'
    # --- 1. Arguments -------------------------------------------------------------
    set -l url $argv[1]
    set -l token $argv[2]
    set -l method $argv[3]
    set -l path $argv[4]
    # Everything after the path is passed to curl unchanged (-o, -F, --max-time).
    set -l extra $argv[5..-1]

    # --- 2. Common curl options -------------------------------------------------
    #   -sS               no progress bar, but still print curl's own errors
    #   --fail-with-body  exit non-zero on HTTP >= 400 AND keep the body, which
    #                     holds the server's explanation (FastAPI "detail")
    #   --connect-timeout fail fast when nothing listens on the URL
    #   --max-time        upper bound for a whole call (archives can be large);
    #                     a later --max-time in $extra overrides it
    set -l opts -sS --fail-with-body --connect-timeout 5 --max-time 1800 -X $method

    # --- 3. Run curl ----------------------------------------------------------------
    # The output is captured so it can be shown in the error message. With -o
    # in $extra the body goes to the file and $body stays empty.
    set -l body
    if test -n "$token"
        # -H @- reads the header from stdin: the token never appears in argv.
        set body (printf 'Authorization: Bearer %s\n' $token | curl $opts -H @- $extra $url$path)
    else
        set body (curl $opts $extra $url$path)
    end
    set -l rc $status

    # --- 4. Report --------------------------------------------------------------------
    if test $rc -ne 0
        # curl exit 22 = HTTP error (the body has the reason), 7 = no server,
        # 28 = timeout. string join keeps a multi-line body on one message.
        echo "$method $path failed (curl exit $rc): "(string join ' ' -- $body | string sub -l 500) >&2
        return $rc
    end
    test (count $body) -gt 0; and printf '%s\n' $body
    return 0
end
