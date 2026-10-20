# __hs_complete_backup_banks — Private helper of the hs-restore completion:
# print the bank ids contained in the backup typed on the command line (or in
# hindsight_backup_latest if none was typed yet).

function __hs_complete_backup_banks --description 'Complete the bank ids of an hs-backup folder'
    set -l words (commandline -opc)[2..-1]
    # argparse -i leaves the positional words (the backup path) in $argv.
    argparse -i 'dir=' 'bank=+' 'as=' 'url=' 'token=' -- $words 2>/dev/null
    set -l dir (__hs_resolve_target dir $_flag_dir)

    # Same lookup as hs-restore: path as typed, else under <dir>, else latest.
    set -l src $dir/hindsight_backup_latest
    set -l pos (string match -v -- '-*' $argv)
    if set -q pos[1]
        if test -d $pos[1]
            set src $pos[1]
        else if test -d $dir/$pos[1]
            set src $dir/$pos[1]
        end
    end

    __hs_manifest_read $src 2>/dev/null | jq -r '.banks[].bank_id' 2>/dev/null
end
