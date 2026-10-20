# __hs_bank_ids — Private helper of hs-backup / hs-restore (and of their
# completions): print the ids of all the banks of an instance, one per line.
#
# Usage:  set -l ids (__hs_bank_ids <url> <token>)
#
# Why the bank LIST and not GET .../banks/<id>/stats to test if a bank exists:
# Hindsight creates banks lazily on first use, so touching an unknown id could
# create an empty bank, which would then block a restore into that id.
# Listing never creates anything.

function __hs_bank_ids --description 'Print the ids of all the banks of a Hindsight instance'
    set -l url $argv[1]
    set -l token $argv[2]

    # --- 1. Page through GET /v1/default/banks ------------------------------------
    # The list is paginated (limit/offset). Ask for big pages and stop when
    # the offset reaches the total announced by the server.
    set -l limit 500
    set -l offset 0
    while true
        set -l page (__hs_api $url "$token" GET "/v1/default/banks?limit=$limit&offset=$offset" --max-time 30)
        or return 1

        printf '%s\n' $page | jq -r '.banks[].bank_id'
        set -l total (printf '%s\n' $page | jq -r '.total')
        set -l got (printf '%s\n' $page | jq -r '.banks | length')

        set offset (math $offset + $limit)
        # Stop when everything was seen, or if a page came back empty (avoids
        # an endless loop if total and the page sizes ever disagree).
        if test $offset -ge $total; or test $got -eq 0
            break
        end
    end
end
