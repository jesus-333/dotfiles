# Tab completion for kcli (wrapper of karabiner_cli). The options come from the
# Karabiner-Elements documentation; `kcli --help` shows the full list.
complete -c kcli -f                                                   # no file completion by default
complete -c kcli -l help -d 'Show help'
complete -c kcli -l version -d 'Show version'
complete -c kcli -l version-number -d 'Show version number'
complete -c kcli -l show-current-profile-name -d 'Show the name of the current profile'
complete -c kcli -l list-profile-names -d 'List the names of all profiles'
# --select-profile takes a profile name: the names are read from Karabiner
# itself (kcli --list-profile-names). 2>/dev/null hides errors if it is not installed.
complete -c kcli -l select-profile -x -a '(kcli --list-profile-names 2>/dev/null)' -d 'Select a profile by name'
complete -c kcli -l set-variables -x -d 'Set variables (JSON), e.g. {"name":1}'
complete -c kcli -l copy-current-profile-to-system-default-profile -d 'Copy current profile to system default (login window)'
complete -c kcli -l remove-system-default-profile -d 'Remove the system default profile'
# --lint-complex-modifications takes JSON files, so here files are completed (-F)
complete -c kcli -l lint-complex-modifications -F -d 'Check complex modifications JSON files'
