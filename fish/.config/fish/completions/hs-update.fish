# Tab completion for hs-update: it takes only options, no files.
complete -c hs-update -f                                                    # no file completion
complete -c hs-update -s h -l help -d 'Show help'
complete -c hs-update -s y -l yes -d 'Do not ask for confirmation (backup is still done)'
complete -c hs-update -s f -l force -d 'Install :latest even if it looks like a prerelease'
