# __hs_complete_banks — Private helper of the hs-backup / hs-restore
# completions: print the bank ids of the instance, one per line.
#
# Uses --url / --token from the command line being completed if present,
# otherwise $HS_API_URL / $HS_API_TOKEN / the default, like the functions.
# The 2 s timeout keeps TAB responsive: if the server is down nothing is shown.

function __hs_complete_banks --description 'Complete Hindsight bank ids (live from the API)'
    # commandline -opc gives the words typed so far; argparse with -i ignores
    # the unknown ones and picks out --url / --token.
    set -l words (commandline -opc)[2..-1]
    argparse -i 'url=' 'token=' -- $words 2>/dev/null
    set -l url (__hs_resolve_target url $_flag_url)
    set -l token (__hs_resolve_target token $_flag_token)

    # Only the first page (500 banks) and a short timeout: this runs on TAB.
    __hs_api $url "$token" GET '/v1/default/banks?limit=500' --max-time 2 2>/dev/null | jq -r '.banks[].bank_id' 2>/dev/null
end
