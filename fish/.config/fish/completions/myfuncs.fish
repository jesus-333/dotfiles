# Tab completion for myfuncs: it takes only options, no files.
complete -c myfuncs -f                                                   # no file completion
complete -c myfuncs -s a -l all -d 'Also list the private helpers (names starting with _)'
complete -c myfuncs -s h -l help -d 'Show help'
