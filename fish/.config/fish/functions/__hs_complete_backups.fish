# __hs_complete_backups — Private helper of the hs-restore completion: print
# the names of the backup folders under the backup root (--dir on the command
# line, else $HS_BACKUP_DIR, else ~/sbx-hindsight/backups), with their note.

function __hs_complete_backups --description 'Complete hs-backup folder names'
    set -l words (commandline -opc)[2..-1]
    argparse -i 'dir=' -- $words 2>/dev/null
    set -l dir (__hs_resolve_target dir $_flag_dir)

    # "name<TAB>description": fish shows the text after the TAB as description.
    for d in $dir/hindsight_backup_*/
        set -l m (__hs_manifest_read $d 2>/dev/null); or continue
        printf '%s\t%s\n' (basename $d) (printf '%s\n' $m | jq -r '"\(.created_at) \(.note // "")"')
    end
end
