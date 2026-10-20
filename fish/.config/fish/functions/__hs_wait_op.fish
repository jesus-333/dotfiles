# __hs_wait_op — Private helper of hs-backup / hs-restore: wait for a Hindsight
# async operation (export, import, ...) to finish.
#
# Usage:  set -l op_json (__hs_wait_op <url> <token> <bank-id> <operation-id> <timeout-s> <prefix> [<label>])
#
# Polls GET /v1/default/banks/<bank>/operations/<op> every 2 s. The status is
# one of pending, processing, completed, failed, cancelled.
#   completed           -> prints the final operation JSON on stdout (it holds
#                          result_metadata, e.g. the export's download_url), returns 0
#   failed / cancelled  -> prints the server's error_message to stderr, returns 1
#   timeout             -> returns 2 (the operation may still finish later)
# While it waits, a progress line goes to stderr every time the status or the
# progress counters change, prefixed with <prefix> (e.g. "hs-backup") and
# <label> (default: the bank id; hs-restore passes the target bank, because
# its operations are recorded on a temporary bank).

function __hs_wait_op --description 'Wait for a Hindsight async operation to complete, fail or time out'
    # --- 1. Arguments -------------------------------------------------------------
    set -l url $argv[1]
    set -l token $argv[2]
    set -l bank $argv[3]
    set -l op $argv[4]
    set -l timeout $argv[5]
    set -l prefix $argv[6]
    set -l label $bank
    set -q argv[7]; and set label $argv[7]

    # The bank id goes into the URL path: string escape --style=url encodes
    # characters that are not allowed there.
    set -l path /v1/default/banks/(string escape --style=url -- $bank)/operations/$op

    # --- 2. Poll ------------------------------------------------------------------------
    # $last remembers the last progress line printed, so the same line is not
    # repeated every 2 s. date +%s is "seconds since 1970": the difference
    # with $start is the time waited so far.
    set -l last ''
    set -l start (date +%s)
    while true
        set -l json (__hs_api $url "$token" GET $path --max-time 30)
        or return 1

        set -l state (printf '%s\n' $json | jq -r '.status')
        switch $state
            case completed
                printf '%s\n' $json
                return 0
            case failed cancelled
                set -l msg (printf '%s\n' $json | jq -r '.error_message // "no error message"')
                echo "$prefix: operation $op $state: $msg" >&2
                return 1
        end

        # Still pending/processing. progress (when present) has a stage name
        # and processed/total counters; // "" gives an empty string if absent.
        set -l line (printf '%s\n' $json | jq -r '[.status, (.progress.stage // empty), (if .progress.total then "\(.progress.processed)/\(.progress.total)" else empty end)] | join(" ")')
        if test "$line" != "$last"
            echo "$prefix:   $label: $line" >&2
            set last $line
        end

        if test (math (date +%s) - $start) -ge $timeout
            echo "$prefix: operation $op on $label still '$state' after $timeout s, giving up" >&2
            return 2
        end
        sleep 2
    end
end
