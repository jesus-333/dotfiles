# hs-backup — Back up Hindsight memory banks to portable archives, using only
# the Hindsight HTTP API.
#
# Usage:  hs-backup [<bank-id>...] [--timestamp] [--note <text>]
#                   [--url <url>] [--token <t>] [--dir <path>]
#
#   (no bank id)   all the banks of the instance
#   <bank-id>...   only these banks (an unknown id stops before writing anything)
#   --timestamp    write a new folder hindsight_backup_<YYYY-MM-DD_HHMMSS>
#                  (never overwritten or pruned) instead of replacing
#                  hindsight_backup_latest
#   --note <text>  free text stored in manifest.json, e.g. pre-update
#   --url          API URL    (default: $HS_API_URL, then http://localhost:8888)
#   --token        API token  (default: $HS_API_TOKEN, then none)
#   --dir          backup root (default: $HS_BACKUP_DIR, then ~/sbx-hindsight/backups)
#
# Why: hs-snapshot archives the raw Docker volume, which only works with this
# exact installation (sbx sandbox -> Docker container) and can only be put
# back into the same one. hs-backup uses the bank transfer API instead, so the
# archives can be loaded (hs-restore) into ANY Hindsight instance: Docker,
# sbx, pip, a remote server, even one with another embedding model.
#
# Folder layout:
#   <dir>/hindsight_backup_latest/        (or hindsight_backup_<timestamp>/)
#     bank-<id>.zip     one transfer archive per bank
#     manifest.json     date, note, source URL, API version and, per bank:
#                       id, file, sha256, size, stats (format: __hs_manifest_write)
#
# What an archive carries: documents, facts, observations, mental models,
# knowledge pages, bank config, directives and webhooks. NOT the embeddings:
# the import re-embeds with the target's model (no LLM calls).
#
# Steps:
#   1. check that the API answers (GET /health)
#   2. resolve the list of banks
#   3. per bank: start the export, wait for it, download the zip, check it
#   4. write everything into a temporary folder, manifest.json last
#   5. only if ALL of it worked, swap the folder into place: a failed run
#      never destroys the previous good backup
#   6. print a summary
#
# Note: every export also leaves a copy of the archive in the server's own
# file storage (the API has no call to delete it).

function hs-backup --description 'Back up Hindsight banks to portable archives via the HTTP API'
    # --- 1. Parse options ------------------------------------------------------
    # argparse removes recognised flags from $argv (what is left are the bank
    # ids). note=, url=, token= and dir= take a value, stored in $_flag_note,
    # $_flag_url, ... Unknown flags make argparse fail with an error.
    argparse h/help timestamp note= url= token= dir= -- $argv; or return 1

    if set -q _flag_help
        echo "usage: hs-backup [<bank-id>...] [--timestamp] [--note <text>] [--url <url>] [--token <t>] [--dir <path>]"
        echo
        echo "Export Hindsight banks (all by default) through the HTTP API into"
        echo "<dir>/hindsight_backup_latest (replaced on every run)."
        echo
        echo "  --timestamp     write <dir>/hindsight_backup_<YYYY-MM-DD_HHMMSS> instead"
        echo "  --note <text>   note stored in manifest.json"
        echo "  --url <url>     API URL     (\$HS_API_URL, default http://localhost:8888)"
        echo "  --token <t>     API token   (\$HS_API_TOKEN, default none)"
        echo "  --dir <path>    backup root (\$HS_BACKUP_DIR, default ~/sbx-hindsight/backups)"
        return 0
    end

    # --- 2. Check the tools -----------------------------------------------------
    for tool in curl jq unzip
        if not type -q $tool
            echo "hs-backup: $tool is not installed" >&2
            return 1
        end
    end

    # --- 3. Resolve the instance (flag -> env var -> default) ---------------------
    # "$token" is always passed quoted to the helpers: an empty token must stay
    # ONE (empty) argument, otherwise the following arguments would shift.
    set -l url (__hs_resolve_target url $_flag_url)
    set -l token (__hs_resolve_target token $_flag_token)
    set -l dir (__hs_resolve_target dir $_flag_dir)

    # --- 4. Is the API answering? ---------------------------------------------------
    if not __hs_api $url "$token" GET /health --max-time 5 >/dev/null
        echo "hs-backup: Hindsight is not answering at $url (on this Mac: hs-up)" >&2
        return 1
    end

    # API version, stored in the manifest (only for information: the release
    # version of the server is not exposed over HTTP).
    set -l api_version (__hs_api $url "$token" GET /version --max-time 10 | jq -r '.api_version // empty')
    test -n "$api_version"; or set api_version unknown

    # --- 5. Resolve the bank list -------------------------------------------------
    set -l all_banks (__hs_bank_ids $url "$token")
    or begin
        echo "hs-backup: could not list the banks of $url" >&2
        return 1
    end

    set -l banks $argv
    if test (count $banks) -eq 0
        set banks $all_banks
    else
        # Every requested id must exist, checked BEFORE anything is written.
        # contains -- is true if the first word is among the following ones.
        for b in $banks
            if not contains -- $b $all_banks
                echo "hs-backup: unknown bank '$b' on $url" >&2
                echo "Banks: "(string join ', ' -- $all_banks) >&2
                return 1
            end
        end
    end

    if test (count $banks) -eq 0
        echo "hs-backup: $url has no banks, nothing to back up" >&2
        return 1
    end

    # --- 6. Temporary folder ------------------------------------------------------
    # Everything is written here first. $fish_pid (the pid of this shell) makes
    # the name unique; a leftover from an interrupted run with the same pid is
    # removed. The leading '.' keeps it out of hs-restore --list.
    if not mkdir -p $dir
        echo "hs-backup: could not create $dir" >&2
        return 1
    end
    set -l tmp $dir/.hs-backup-tmp-$fish_pid
    rm -rf $tmp
    if not mkdir $tmp
        echo "hs-backup: could not create $tmp" >&2
        return 1
    end

    # --- 7. Export every bank --------------------------------------------------------
    # $entries collects one JSON object per bank for the manifest. On the
    # first failure $failed is set and the loop stops: the temporary folder is
    # removed below and the previous backup stays as it was.
    set -l entries
    set -l failed 0
    for b in $banks
        # The id is URL-encoded for the path (ids could contain e.g. spaces).
        set -l bpath /v1/default/banks/(string escape --style=url -- $b)
        echo "hs-backup: exporting $b ..." >&2

        # 7a. Stats at backup time (counts and pending operations).
        set -l stats (__hs_api $url "$token" GET $bpath/stats --max-time 30 | jq -c .)
        if test -z "$stats"
            echo "hs-backup: could not read the stats of $b" >&2
            set failed 1; break
        end
        # Pending or running operations (e.g. memories still being retained)
        # are not in the archive yet: the export captures what is committed
        # right now. pending_operations does not count the running ones, so
        # operations_by_status.processing is added.
        set -l pending (printf '%s\n' $stats | jq -r '(.pending_operations // 0) + (.operations_by_status.processing // 0)')
        if test "$pending" -gt 0
            echo "hs-backup: warning: $b has $pending pending/running operation(s), the backup holds only what is committed now" >&2
        end

        # 7b. Start the export: the answer only contains an operation id.
        set -l op (__hs_api $url "$token" POST $bpath/transfer/export --max-time 60 | jq -r '.operation_id // empty')
        if test -z "$op"
            echo "hs-backup: could not start the export of $b" >&2
            set failed 1; break
        end

        # 7c. Wait for it (10 min at most). The final operation JSON has the
        # archive's download_url in result_metadata.
        set -l done (__hs_wait_op $url "$token" $b $op 600 hs-backup)
        or begin
            set failed 1; break
        end
        set -l download (printf '%s\n' $done | jq -r '.result_metadata.download_url // empty')
        if test -z "$download"
            echo "hs-backup: the export of $b finished without a download_url" >&2
            set failed 1; break
        end

        # 7d. Download the archive and check that it is a complete zip
        # (unzip -tq tests every entry without extracting anything).
        set -l zip bank-$b.zip
        if not __hs_api $url "$token" GET $download -o $tmp/$zip
            echo "hs-backup: could not download the archive of $b" >&2
            set failed 1; break
        end
        if not unzip -tq $tmp/$zip >/dev/null
            echo "hs-backup: the archive of $b is not a valid zip" >&2
            set failed 1; break
        end

        # 7e. Manifest entry. The archive has its own manifest.json (counts of
        # documents, facts, observations...), copied as "archive". wc -c < file
        # gives the size in bytes on both macOS and Linux; string trim removes
        # the spaces macOS puts in front of the number.
        set -l sha (__hs_sha256 $tmp/$zip)
        or begin
            set failed 1; break
        end
        set -l size (wc -c < $tmp/$zip | string trim)
        set -l archive (unzip -p $tmp/$zip manifest.json 2>/dev/null | jq -c . 2>/dev/null)
        test -n "$archive"; or set archive null

        set -a entries (jq -n -c --arg id $b --arg file $zip --arg sha $sha \
            --argjson size $size --argjson stats "$stats" --argjson archive "$archive" \
            '{bank_id: $id, file: $file, sha256: $sha, size_bytes: $size, stats: $stats, archive: $archive}')
    end

    # --- 8. Manifest, written last ------------------------------------------------
    # Its presence marks a complete backup.
    if test $failed -eq 0
        if not __hs_manifest_write $tmp/manifest.json "$_flag_note" $url $api_version $entries
            echo "hs-backup: could not write manifest.json" >&2
            set failed 1
        end
    end

    if test $failed -ne 0
        rm -rf $tmp
        echo "hs-backup: backup FAILED, previous backups were not touched" >&2
        return 1
    end

    # --- 9. Move the folder into place -------------------------------------------
    set -l final
    if set -q _flag_timestamp
        # A dated folder is never overwritten: two runs in the same second fail.
        set final $dir/hindsight_backup_(date +%Y-%m-%d_%H%M%S)
        if test -e $final
            echo "hs-backup: $final already exists" >&2
            rm -rf $tmp
            return 1
        end
        if not mv $tmp $final
            echo "hs-backup: could not move the backup to $final" >&2
            rm -rf $tmp
            return 1
        end
    else
        # Swap: latest -> latest.old, new -> latest, then delete .old. If the
        # second rename fails, the old backup is put back.
        set final $dir/hindsight_backup_latest
        set -l old $final.old
        rm -rf $old
        if test -e $final; and not mv $final $old
            echo "hs-backup: could not move the old $final aside" >&2
            rm -rf $tmp
            return 1
        end
        if not mv $tmp $final
            echo "hs-backup: could not move the new backup into place, keeping the old one" >&2
            test -e $old; and mv $old $final
            rm -rf $tmp
            return 1
        end
        rm -rf $old
    end

    # --- 10. Summary ------------------------------------------------------------------
    # du -h prints the size in human units (K, M, G); string split keeps it.
    echo "hs-backup: saved $final"
    for e in $entries
        set -l id (printf '%s\n' $e | jq -r '.bank_id')
        set -l file (printf '%s\n' $e | jq -r '.file')
        set -l human (du -h $final/$file | string split -f1 \t)
        set -l counts (printf '%s\n' $e | jq -r '"\(.archive.document_count // "?") documents, \(.archive.fact_count // "?") facts, \(.archive.observation_count // "?") observations, \(.archive.mental_model_count // "?") mental models"')
        echo "  $id  $human  ($counts)"
    end
end
