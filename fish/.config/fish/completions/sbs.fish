# Tab completion for sbs: first argument is the agent, second is a folder.
complete -c sbs -f                                            # no file completion by default
complete -c sbs -s h -l help -d 'Show help'
complete -c sbs -n '__fish_is_first_arg' -a 'claude codex pi' -d 'Agent'
complete -c sbs -n 'test (count (commandline -opc)) -eq 2' -a '(__fish_complete_directories)'
