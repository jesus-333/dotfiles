# __hs_manifest_read — Private helper of hs-restore (and of hs-restore --list):
# print the manifest.json of a backup folder, after checking it.
#
# Usage:  set -l manifest (__hs_manifest_read <backup-folder>)
#
# Fails (non-zero, message on stderr) if the file is missing, is not valid
# JSON, or was not written by hs-backup (no "banks" array). The format is
# described in __hs_manifest_write.

function __hs_manifest_read --description 'Print and validate manifest.json of a Hindsight backup folder'
    set -l file $argv[1]/manifest.json

    if not test -f $file
        echo "no manifest.json in $argv[1]" >&2
        return 1
    end

    # jq -e exits non-zero when the last value is false/null, so this both
    # checks that the JSON parses and that it looks like an hs-backup manifest.
    if not jq -e '.format == "hs-backup" and (.banks | type) == "array"' $file >/dev/null 2>&1
        echo "$file is not a valid hs-backup manifest" >&2
        return 1
    end

    jq -c . $file
end
