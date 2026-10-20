# __hs_manifest_write — Private helper of hs-backup: write manifest.json of a
# backup folder.
#
# Usage:  __hs_manifest_write <file> <note> <source-url> <api-version> <bank-json>...
#   <bank-json>  one compact JSON object per bank, as built by hs-backup:
#                {bank_id, file, sha256, size_bytes, stats, archive}
#
# Resulting manifest.json:
#   {
#     "format": "hs-backup", "format_version": 1,
#     "created_at": "2026-10-20T14:03:23Z",       (UTC)
#     "note": "pre-update",                       (null when not given)
#     "source_url": "http://localhost:8888",
#     "server": { "api_version": "1.0.0" },
#     "banks": [ { "bank_id", "file", "sha256", "size_bytes",
#                  "stats",      <- GET .../stats at backup time
#                  "archive" },  <- manifest.json found INSIDE the zip
#                ... ]
#   }
# Only the API version is recorded: the HTTP API does not expose the release
# version (e.g. 0.10.3) of the server.

function __hs_manifest_write --description 'Write manifest.json of a Hindsight backup folder'
    set -l file $argv[1]
    set -l note $argv[2]
    set -l source_url $argv[3]
    set -l api_version $argv[4]
    set -l banks $argv[5..-1]

    # --- 1. Build the JSON with jq ---------------------------------------------------
    # jq -n starts from nothing. --arg passes strings, --argjson passes JSON:
    # the bank objects (one per line) are collected into an array by jq -s.
    # ($note | if . == "" then null ...) stores a missing note as null.
    set -l banks_json (printf '%s\n' $banks | jq -s -c '.')
    or return 1

    jq -n \
        --arg created (date -u +%Y-%m-%dT%H:%M:%SZ) \
        --arg note "$note" \
        --arg url $source_url \
        --arg api "$api_version" \
        --argjson banks "$banks_json" \
        '{format: "hs-backup", format_version: 1, created_at: $created,
          note: ($note | if . == "" then null else . end),
          source_url: $url, server: {api_version: $api}, banks: $banks}' >$file
end
