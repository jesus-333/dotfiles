# Tab completion for hs-restore: options, bank ids and backup folder names.
complete -c hs-restore -f                                                   # no file completion by default
complete -c hs-restore -s h -l help -d 'Show help'
complete -c hs-restore -l list -d 'List the backups in the backup root'
# --bank: banks contained in the backup (read from manifest.json, or from the
# latest backup when no path was typed yet).
complete -c hs-restore -l bank -x -a '(__hs_complete_backup_banks)' -d 'Only this bank of the backup'
# --as: a new id; the existing banks are offered for reference.
complete -c hs-restore -l as -x -a '(__hs_complete_banks)' -d 'Import under this id'
complete -c hs-restore -l replace -d 'Safety backup, delete the existing bank, then import'
complete -c hs-restore -s y -l yes -d 'Do not ask for confirmation'
complete -c hs-restore -s n -l dry-run -d 'Print the requests, change nothing'
complete -c hs-restore -l url -x -a 'http://localhost:8888' -d 'Hindsight API URL'
complete -c hs-restore -l token -x -d 'API token (Authorization: Bearer)'
complete -c hs-restore -l dir -x -a '(__fish_complete_directories)' -d 'Backup root folder'
# Argument: backup folder names under the backup root, plus files (-F) for
# a single bank-<id>.zip or a folder elsewhere.
complete -c hs-restore -F -a '(__hs_complete_backups)' -d 'Backup'
