# Tab completion for sbr: first argument is the agent, second is a folder.
complete -c sbr -f                                            # no file completion by default
complete -c sbr -s h -l help -d 'Show help'
complete -c sbr -n '__fish_is_first_arg' -a 'claude codex pi' -d 'Agent'
complete -c sbr -n 'test (count (commandline -opc)) -eq 2' -a '(__fish_complete_directories)'
