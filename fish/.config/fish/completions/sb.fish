# Tab completion for sb: [-t | -n] <agent> [dir]
# The agent is completed until one is typed (flags may come before it), then
# folders. -t and -n are mutually exclusive, so each one is offered only if
# the other was not used yet.
complete -c sb -f                                            # no file completion by default
complete -c sb -s h -l help -d 'Show help'
complete -c sb -s t -l tmp   -n 'not __fish_contains_opt -s n nomem' -d 'throwaway sandbox without memory, deleted on exit'
complete -c sb -s n -l nomem -n 'not __fish_contains_opt -s t tmp'   -d 'sandbox without memory, kept'
complete -c sb -n 'not __fish_seen_subcommand_from claude codex pi' -a 'claude codex pi' -d 'Agent'
complete -c sb -n '__fish_seen_subcommand_from claude codex pi' -a '(__fish_complete_directories)'
