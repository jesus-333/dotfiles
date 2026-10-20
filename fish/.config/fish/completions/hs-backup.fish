# Tab completion for hs-backup: options, and bank ids as arguments.
# Bank ids are read live from the API (__hs_complete_banks), backup roots are
# folders.
complete -c hs-backup -f                                                    # no file completion by default
complete -c hs-backup -s h -l help -d 'Show help'
complete -c hs-backup -l timestamp -d 'Write a new dated folder instead of replacing latest'
complete -c hs-backup -l note -x -d 'Note stored in manifest.json (e.g. pre-update)'
complete -c hs-backup -l url -x -a 'http://localhost:8888' -d 'Hindsight API URL'
complete -c hs-backup -l token -x -d 'API token (Authorization: Bearer)'
complete -c hs-backup -l dir -x -a '(__fish_complete_directories)' -d 'Backup root folder'
# Arguments: the banks of the instance (2 s timeout, nothing if it is down).
complete -c hs-backup -a '(__hs_complete_banks)' -d 'Bank'
