# Tab completion for hs-version: it takes only options, no files.
complete -c hs-version -f                                                   # no file completion
complete -c hs-version -s h -l help -d 'Show help'
