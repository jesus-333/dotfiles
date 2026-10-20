# hs-restore — Load banks backed up by hs-backup into a Hindsight instance,
# using only the Hindsight HTTP API.
#
# Usage:  hs-restore [<backup-folder|bank-zip>] [--bank <id>]... [--as <new-id>]
#                    [--replace] [--yes] [--dry-run]
#                    [--url <url>] [--token <t>] [--dir <path>]
#         hs-restore --list
#
#   (no path)        <dir>/hindsight_backup_latest
#   folder / zip     that backup; a bare folder name is looked up under <dir>.
#                    A single bank-<id>.zip has no manifest (no checksum):
#                    allowed, with a warning
#   --bank <id>      only these banks of the backup (repeatable)
#   --as <new-id>    import under another id (only with exactly one bank)
#   --replace        if the target id exists: safety backup
#                    (hs-backup <id> --timestamp --note pre-restore), then
#                    DELETE the bank, then import
#   --yes            no confirmation
#   --dry-run        print every request it would make, change nothing
#   --list           list the backups in <dir>
#   --url / --token / --dir   as in hs-backup ($HS_API_URL, $HS_API_TOKEN,
#                    $HS_BACKUP_DIR; defaults localhost:8888, none,
#                    ~/sbx-hindsight/backups)
#
# Why: hs-backup archives are portable, so they can be restored into any
# Hindsight instance (Docker, sbx, pip, remote). A restore never merges: the
# import creates the bank and FAILS if the id already exists. That is why an
# existing bank is only touched with --replace, and only after a safety backup.
#
# Moving to a new instance:
#   1. start the new instance (any install method)
#   2. run hs-restore --url <new-url> BEFORE any agent uses it: Hindsight
#      creates banks lazily on first use, and an empty bank created by an agent
#      blocks the import into that id (then: hs-restore --replace)
#   3. point the agents at it (apiUrl in ~/.hindsight/coding-agent.json, i.e.
#      the hindsight-memory kit)
# The embedding model of the TARGET computes the new embeddings (archives do
# not carry them); no LLM extraction runs, so the import costs no tokens.
#
# Steps:
#   1. check the target API (GET /health), read manifest.json, verify the
#      sha256 of every zip
#   2. print a summary: source -> target, banks and their counts
#   3. check which target ids already exist (abort without --replace)
#   4. confirm (y/N), naming the banks that will be deleted
#   5. safety backup, delete, import, wait, and compare the counts. The
#      imports go through a temporary empty bank hs-restore-tmp-<pid>
#      (the API needs an existing bank to record them on), deleted at the end
#   6. exit non-zero if any bank failed

function hs-restore --description 'Restore Hindsight banks from an hs-backup folder or archive via the HTTP API'
    # --- 1. Parse options ------------------------------------------------------
    # bank=+ can be repeated (all values end up in $_flag_bank). as=, url=,
    # token= and dir= take a value. What is left in $argv is the backup path.
    argparse h/help 'bank=+' as= replace y/yes n/dry-run list url= token= dir= -- $argv; or return 1

    if set -q _flag_help
        echo "usage: hs-restore [<backup-folder|bank-zip>] [--bank <id>]... [--as <new-id>] [--replace]"
        echo "                  [--yes] [--dry-run] [--url <url>] [--token <t>] [--dir <path>]"
        echo "       hs-restore --list"
        echo
        echo "Import the banks of a backup made by hs-backup (default: <dir>/hindsight_backup_latest)."
        echo
        echo "  --bank <id>     only this bank of the backup (repeatable)"
        echo "  --as <new-id>   import under another id (exactly one bank)"
        echo "  --replace       existing bank: safety backup, delete, then import"
        echo "  -y, --yes       do not ask for confirmation"
        echo "  -n, --dry-run   print the requests, change nothing"
        echo "  --list          list the backups in <dir>"
        echo "  --url <url>     API URL     (\$HS_API_URL, default http://localhost:8888)"
        echo "  --token <t>     API token   (\$HS_API_TOKEN, default none)"
        echo "  --dir <path>    backup root (\$HS_BACKUP_DIR, default ~/sbx-hindsight/backups)"
        return 0
    end

    # --- 2. Check the tools -----------------------------------------------------
    for tool in curl jq unzip
        if not type -q $tool
            echo "hs-restore: $tool is not installed" >&2
            return 1
        end
    end

    # --- 3. Resolve the instance (flag -> env var -> default) ---------------------
    # "$token" is always passed quoted to the helpers, so an empty token stays
    # one (empty) argument.
    set -l url (__hs_resolve_target url $_flag_url)
    set -l token (__hs_resolve_target token $_flag_token)
    set -l dir (__hs_resolve_target dir $_flag_dir)

    # --- 4. --list: show the backups and stop ---------------------------------------
    # Only folders with a valid manifest are listed (an interrupted hs-backup
    # leaves a hidden .hs-backup-tmp-* folder, which the glob skips anyway).
    if set -q _flag_list
        set -l found 0
        for d in $dir/hindsight_backup_*/
            set -l m (__hs_manifest_read $d 2>/dev/null); or continue
            set found 1
            printf '%s\n' $m | jq -r --arg name (basename $d) \
                '"\($name)\n    date: \(.created_at)   note: \(.note // "-")\n    banks: \([.banks[].bank_id] | join(", "))\n    source: \(.source_url) (API \(.server.api_version))"'
        end
        test $found -eq 1; or echo "hs-restore: no backups in $dir"
        return 0
    end

    if test (count $argv) -gt 1
        echo "hs-restore: give at most one backup folder or zip" >&2
        return 1
    end

    # --- 5. Resolve the backup ------------------------------------------------------
    # The path is taken as given if it exists, otherwise looked up under <dir>
    # (so `hs-restore hindsight_backup_2026-10-20_160653` works from anywhere).
    set -l src $dir/hindsight_backup_latest
    if test (count $argv) -eq 1
        if test -e $argv[1]
            set src $argv[1]
        else if test -e $dir/$argv[1]
            set src $dir/$argv[1]
        else
            echo "hs-restore: '$argv[1]' not found (nor under $dir)" >&2
            return 1
        end
    end

    # Each selected bank is described by three parallel lists, same index:
    #   $ids    bank id in the backup
    #   $zips   path of its archive
    #   $shas   expected sha256 ('' if unknown, i.e. a single zip)
    set -l ids
    set -l zips
    set -l shas
    set -l source_url unknown
    set -l source_api unknown
    set -l note ''

    if test -d $src
        # 5a. A backup folder: the manifest lists the banks and their checksums.
        set -l manifest (__hs_manifest_read $src)
        or begin
            echo "hs-restore: $src is not an hs-backup folder" >&2
            return 1
        end
        set source_url (printf '%s\n' $manifest | jq -r '.source_url')
        set source_api (printf '%s\n' $manifest | jq -r '.server.api_version // "unknown"')
        set note (printf '%s\n' $manifest | jq -r '.note // ""')
        # jq prints "id<TAB>file<TAB>sha" per bank; string split cuts it.
        for row in (printf '%s\n' $manifest | jq -r '.banks[] | [.bank_id, .file, .sha256] | @tsv')
            set -l f (string split \t -- $row)
            set -a ids $f[1]
            set -a zips $src/$f[2]
            set -a shas $f[3]
        end
    else
        # 5b. A single archive: the bank id comes from the manifest.json the
        # export put INSIDE the zip. No checksum to compare with.
        set -l inner (unzip -p $src manifest.json 2>/dev/null | jq -r '.source_bank_id // empty' 2>/dev/null)
        if test -z "$inner"
            echo "hs-restore: $src is not a Hindsight transfer archive" >&2
            return 1
        end
        echo "hs-restore: warning: single archive without hs-backup manifest, its checksum cannot be verified" >&2
        set ids $inner
        set zips $src
        set shas ''
    end

    # 5c. --bank: keep only the requested banks, each must be in the backup.
    if set -q _flag_bank
        set -l keep_ids
        set -l keep_zips
        set -l keep_shas
        for b in $_flag_bank
            # contains -i prints the index of $b in $ids (and fails if absent).
            set -l i (contains -i -- $b $ids)
            or begin
                echo "hs-restore: bank '$b' is not in the backup (it has: "(string join ', ' -- $ids)")" >&2
                return 1
            end
            set -a keep_ids $ids[$i]
            set -a keep_zips $zips[$i]
            set -a keep_shas $shas[$i]
        end
        set ids $keep_ids
        set zips $keep_zips
        set shas $keep_shas
    end

    if test (count $ids) -eq 0
        echo "hs-restore: the backup contains no banks" >&2
        return 1
    end

    # 5d. Target ids: the original ones, or --as for a single bank.
    set -l targets $ids
    if set -q _flag_as
        if test (count $ids) -ne 1
            echo "hs-restore: --as needs exactly one bank (use --bank <id>)" >&2
            return 1
        end
        set targets $_flag_as
    end

    # --- 6. Verify the archives ----------------------------------------------------
    # The checksum proves the file is the one hs-backup wrote; unzip -tq
    # checks that the zip itself is intact.
    for i in (seq (count $ids))
        if not test -f $zips[$i]
            echo "hs-restore: missing archive $zips[$i]" >&2
            return 1
        end
        if test -n "$shas[$i]"
            set -l sum (__hs_sha256 $zips[$i]); or return 1
            if test "$sum" != "$shas[$i]"
                echo "hs-restore: checksum mismatch for $zips[$i], the archive is damaged or was changed" >&2
                return 1
            end
        end
        if not unzip -tq $zips[$i] >/dev/null
            echo "hs-restore: $zips[$i] is not a valid zip" >&2
            return 1
        end
    end

    # --- 7. Check the target -----------------------------------------------------------
    if not __hs_api $url "$token" GET /health --max-time 5 >/dev/null
        echo "hs-restore: Hindsight is not answering at $url (on this Mac: hs-up)" >&2
        return 1
    end
    set -l target_api (__hs_api $url "$token" GET /version --max-time 10 | jq -r '.api_version // empty')
    test -n "$target_api"; or set target_api unknown

    # Archives from a newer server may not import into an older one. Only the
    # API version can be compared (the release version is not exposed over
    # HTTP). sort -V sorts version numbers: if the target comes first and
    # differs from the source, it is older.
    if test $source_api != unknown; and test $target_api != unknown; and test $source_api != $target_api
        set -l oldest (printf '%s\n' $source_api $target_api | sort -V | head -n1)
        if test "$oldest" = "$target_api"
            echo "hs-restore: warning: target API $target_api is older than the source API $source_api, the import may fail" >&2
        end
    end

    # Which target ids already exist? Read from the bank LIST, which never
    # creates a bank (see __hs_bank_ids).
    set -l existing (__hs_bank_ids $url "$token")
    or begin
        echo "hs-restore: could not list the banks of $url" >&2
        return 1
    end
    set -l to_delete
    for t in $targets
        contains -- $t $existing; and set -a to_delete $t
    end

    # --- 8. Summary ----------------------------------------------------------------------
    echo "hs-restore: $src"
    echo "  from  $source_url (API $source_api)"
    test -n "$note"; and echo "  note  $note"
    echo "  to    $url (API $target_api)"
    for i in (seq (count $ids))
        set -l c (unzip -p $zips[$i] manifest.json 2>/dev/null | jq -r '"\(.document_count // "?") documents, \(.fact_count // "?") facts, \(.observation_count // "?") observations"')
        set -l action import
        contains -- $targets[$i] $to_delete; and set action 'REPLACE (delete + import)'
        echo "  $ids[$i] -> $targets[$i]  [$action]  ($c)"
    end

    # --- 9. Existing banks need --replace ------------------------------------------------
    if test (count $to_delete) -gt 0; and not set -q _flag_replace
        echo "hs-restore: these banks already exist on $url: "(string join ', ' -- $to_delete) >&2
        echo "An import never merges. Use --as <new-id> to import under another id," >&2
        echo "or --replace to back them up, delete them and import." >&2
        return 1
    end

    # --- 10. Dry run: print the plan and stop ---------------------------------------
    # The token is never printed, only masked.
    set -l auth ''
    test -n "$token"; and set auth " -H 'Authorization: Bearer ***'"
    if set -q _flag_dry_run
        echo
        echo "hs-restore: dry run, these requests would be made:"
        if test (count $to_delete) -gt 0
            echo "  hs-backup $to_delete --timestamp --note pre-restore --url $url --dir $dir"
        end
        set -l apath /v1/default/banks/hs-restore-tmp-$fish_pid
        echo "  curl -X PUT$auth -H 'Content-Type: application/json' -d '{}' $url$apath"
        for i in (seq (count $ids))
            set -l tid (string escape --style=url -- $targets[$i])
            if contains -- $targets[$i] $to_delete
                echo "  curl -X DELETE$auth $url/v1/default/banks/$tid"
            end
            echo "  curl -X POST$auth -F file=@$zips[$i] '$url$apath/transfer/import?mode=restore&target_bank_id=$tid'"
            echo "  curl$auth $url$apath/operations/<operation_id>   (until completed)"
            echo "  curl$auth $url/v1/default/banks/$tid/stats"
        end
        echo "  curl -X DELETE$auth $url$apath"
        return 0
    end

    # --- 11. Confirmation ------------------------------------------------------------------
    if not set -q _flag_yes
        if test (count $to_delete) -gt 0
            echo
            echo "WARNING: these banks will be DELETED on $url (after a safety backup):"
            printf '  %s\n' $to_delete
        end
        read -l -P "Restore "(count $ids)" bank(s) into $url? [y/N] " answer
        if not string match -qir '^y(es)?$' -- $answer
            echo "hs-restore: cancelled"
            return 1
        end
    end

    # --- 12. Safety backup of the banks that will be deleted --------------------
    # One timestamped backup for all of them, before ANY delete. If it fails,
    # nothing is deleted or imported.
    if test (count $to_delete) -gt 0
        echo "hs-restore: safety backup of "(string join ', ' -- $to_delete)" ..." >&2
        set -l backup_args --timestamp --note pre-restore --url $url --dir $dir
        test -n "$token"; and set -a backup_args --token $token
        if not hs-backup $to_delete $backup_args
            echo "hs-restore: safety backup failed, nothing was deleted or imported" >&2
            return 1
        end
    end

    # --- 13. Temporary anchor bank -------------------------------------------------------
    # The import endpoint is POST /banks/{bank_id}/transfer/import, and
    # {bank_id} must be a bank that ALREADY exists: the operation is recorded
    # against it, while target_bank_id is the bank that gets created. On a
    # fresh instance (or after deleting the only bank) there is none, so an
    # empty bank is created just for this and deleted at the end. It also
    # keeps the import operations out of the operation log of real banks.
    # PUT with an empty JSON body creates a bank with the default settings.
    set -l anchor hs-restore-tmp-$fish_pid
    set -l apath /v1/default/banks/$anchor
    if contains -- $anchor $existing
        echo "hs-restore: a bank named $anchor already exists (left by an interrupted run?), delete it first" >&2
        return 1
    end
    if not __hs_api $url "$token" PUT $apath -H 'Content-Type: application/json' -d '{}' --max-time 30 >/dev/null
        echo "hs-restore: could not create the temporary bank $anchor" >&2
        return 1
    end

    # --- 14. Restore every bank ------------------------------------------------------------
    set -l ok
    set -l failed
    set -l still_running 0
    for i in (seq (count $ids))
        set -l t $targets[$i]
        set -l tid (string escape --style=url -- $t)
        set -l tpath /v1/default/banks/$tid

        # 14a. --replace: delete the existing bank (cannot be undone, but the
        # safety backup above has it).
        if contains -- $t $to_delete
            echo "hs-restore: deleting $t ..." >&2
            if not __hs_api $url "$token" DELETE $tpath --max-time 300 >/dev/null
                echo "hs-restore: could not delete $t" >&2
                set -a failed $t; continue
            end
        end

        # 14b. Upload the archive (multipart form field "file") to the anchor
        # bank. mode=restore creates target_bank_id, which must not exist.
        echo "hs-restore: importing $ids[$i] as $t ..." >&2
        set -l op (__hs_api $url "$token" POST "$apath/transfer/import?mode=restore&target_bank_id=$tid" -F file=@$zips[$i] | jq -r '.operation_id // empty')
        if test -z "$op"
            echo "hs-restore: could not start the import of $t" >&2
            set -a failed $t; continue
        end

        # 14c. Wait (30 min at most: every fact is re-embedded). The
        # operation belongs to the anchor bank, so it is polled there.
        # Exit status 2 = timed out: the import may still be running.
        __hs_wait_op $url "$token" $anchor $op 1800 hs-restore $t >/dev/null
        set -l wrc $status
        if test $wrc -ne 0
            test $wrc -eq 2; and set still_running 1
            set -a failed $t; continue
        end

        # 14d. Compare the counts of the archive with the new bank. Facts
        # (world + experience) should match; observations can differ.
        set -l expected (unzip -p $zips[$i] manifest.json 2>/dev/null | jq -r '"\(.fact_count // "?") facts, \(.observation_count // "?") observations, \(.document_count // "?") documents"')
        set -l now (__hs_api $url "$token" GET $tpath/stats --max-time 30 | jq -r '"\((.nodes_by_fact_type.world // 0) + (.nodes_by_fact_type.experience // 0)) facts, \(.total_observations // 0) observations, \(.total_documents // 0) documents"')
        echo "hs-restore: restored $t"
        echo "    backup : $expected"
        echo "    now    : $now"
        set -a ok $t
    end

    # --- 15. Remove the anchor bank ---------------------------------------------------
    # Only after every import finished (a timed-out import may still be
    # running on it: then it is kept, to be deleted by hand later).
    if test $still_running -eq 1
        echo "hs-restore: keeping the temporary bank $anchor (an import may still be running), delete it later" >&2
    else if not __hs_api $url "$token" DELETE $apath --max-time 60 >/dev/null
        echo "hs-restore: warning: could not delete the temporary bank $anchor, delete it by hand" >&2
    end

    # --- 16. Result ----------------------------------------------------------------------
    test (count $ok) -gt 0; and echo "hs-restore: succeeded: "(string join ', ' -- $ok)
    if test (count $failed) -gt 0
        echo "hs-restore: FAILED: "(string join ', ' -- $failed) >&2
        return 1
    end
end
