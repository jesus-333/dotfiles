# Tab completion for sbk: first argument is the agent, second is a folder.
complete -c sbk -f                                            # no file completion by default
complete -c sbk -s h -l help -d 'Show help'
complete -c sbk -n '__fish_is_first_arg' -a 'claude codex pi' -d 'Agent'
complete -c sbk -n 'test (count (commandline -opc)) -eq 2' -a '(__fish_complete_directories)'
