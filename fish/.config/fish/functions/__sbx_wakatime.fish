function __sbx_wakatime --description 'Write ~/.wakatime.cfg into sandbox <name> from the macOS Keychain'
    set -l name $argv[1]
    set -l key (security find-generic-password -s wakatime-api-key -w 2>/dev/null)
    test -n "$key"; or return 0          # no key, no tracking; don't fail
    # chown in case sbx exec runs as root: the agent (uid 1000) must read the file
    sbx exec $name -- sh -c "umask 077; printf '[settings]\napi_key = %s\n' '$key' > /home/agent/.wakatime.cfg; chown 1000:1000 /home/agent/.wakatime.cfg 2>/dev/null || true"
end
