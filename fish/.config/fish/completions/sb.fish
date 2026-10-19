# Tab completion for sb: first argument is the agent, second is a folder.
complete -c sb -f                                            # no file completion by default
complete -c sb -s h -l help -d 'Show help'
complete -c sb -n '__fish_is_first_arg' -a 'claude codex pi' -d 'Agent'
complete -c sb -n 'test (count (commandline -opc)) -eq 2' -a '(__fish_complete_directories)'
