# Tab completion for stow-factory-reset: it takes only options, no files.
complete -c stow-factory-reset -f                                                   # no file completion
complete -c stow-factory-reset -s h -l help -d 'Show help'
complete -c stow-factory-reset -s n -l dry-run -d 'Only show what would be done'
