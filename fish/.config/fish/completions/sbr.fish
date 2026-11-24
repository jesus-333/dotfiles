# Tab completion for sbr: [-t | -n] <agent> [dir]
# The agent is completed until one is typed (flags may come before it), then
# folders. -t and -n are mutually exclusive, so each one is offered only if
# the other was not used yet.
complete -c sbr -f                                            # no file completion by default
complete -c sbr -s h -l help -d 'Show help'
complete -c sbr -s t -l tmp   -n 'not __fish_contains_opt -s n nomem' -d 'target the throwaway sandbox (<folder>-<agent>-tmp)'
complete -c sbr -s n -l nomem -n 'not __fish_contains_opt -s t tmp'   -d 'target the no-memory sandbox (<folder>-<agent>-nomem)'
complete -c sbr -n 'not __fish_seen_subcommand_from claude codex pi' -a 'claude codex pi' -d 'Agent'
complete -c sbr -n '__fish_seen_subcommand_from claude codex pi' -a '(__fish_complete_directories)'
