# hs-version — Show the running Hindsight server version, the latest one
# published, and the latest version of the coding-agent plugin.
#
# Usage:  hs-version [-h|--help]
#
# Why: the Hindsight server runs as the Docker container "hindsight" inside the
# sbx sandbox "hindsight" (Mac -> sandbox -> container), so checking its
# version means typing long `sbx exec hindsight docker inspect ...` commands.
# This function does it in one go:
#   1. read the version of the running container
#   2. pull ghcr.io/vectorize-io/hindsight:latest and read its version
#      (pulling only downloads the image, the running container is untouched)
#   3. read the latest version of the plugin @vectorize-io/hindsight-coding-agents
#      from the npm registry (only for information: the hindsight-memory kit
#      installs the latest plugin every time an agent sandbox is created)
#   4. print a summary and tell you if `hs-update` has something to do
#
# The versions are read from the OCI label org.opencontainers.image.version,
# which is set on every Hindsight image. The comparison is always against a
# freshly pulled :latest, NOT against the tag written in docker-compose.yml
# (after the first hs-update the compose file is pinned to an exact version).

function hs-version --description 'Show the running Hindsight version, the latest available one and the latest plugin version'
    # --- 1. Parse options ------------------------------------------------------
    # argparse removes recognised flags from $argv and sets $_flag_help when
    # -h/--help is given. Unknown flags make argparse fail with an error.
    argparse h/help -- $argv; or return 1

    if set -q _flag_help
        echo "usage: hs-version"
        echo
        echo "Show the version of the running Hindsight server, the latest version"
        echo "published on ghcr.io (the :latest image is pulled, the running container"
        echo "is not touched) and the latest version of the coding-agent plugin on npm."
        return 0
    end

    # Names used below, kept in one place.
    set -l image ghcr.io/vectorize-io/hindsight:latest
    set -l label '{{index .Config.Labels "org.opencontainers.image.version"}}'
    set -l plugin_url https://registry.npmjs.org/@vectorize-io/hindsight-coding-agents/latest

    # --- 2. Version of the running container -------------------------------------
    # docker inspect works on the container even if it is stopped. sbx exec
    # starts the sandbox if it is stopped. 2>/dev/null hides docker's own error,
    # an empty result is handled below with a clearer message.
    set -l current (sbx exec hindsight -- docker inspect hindsight --format $label 2>/dev/null)
    if test -z "$current"
        echo "hs-version: could not read the version of the 'hindsight' container" >&2
        echo "Does the sandbox exist? (sbx ls)" >&2
        return 1
    end

    # --- 3. Latest version published -----------------------------------------------
    # docker image inspect on :latest reads the LOCAL copy of the image, which
    # can be old. Pulling first makes sure it is the one currently on ghcr.io.
    # -q prints only the image name; the output is discarded.
    echo "hs-version: pulling $image ..." >&2
    if not sbx exec hindsight -- docker pull -q $image >/dev/null
        echo "hs-version: could not pull $image" >&2
        return 1
    end
    set -l latest (sbx exec hindsight -- docker image inspect $image --format $label 2>/dev/null)

    # --- 4. Latest plugin version (npm registry) -----------------------------------
    # The registry returns the package.json of the latest release as JSON.
    # string match -r -g prints only the captured group of the first
    # "version": "..." it finds, i.e. the version number. No npm needed.
    # If the request fails the variable stays empty and "unavailable" is shown.
    set -l plugin (curl -fsS --max-time 5 $plugin_url 2>/dev/null | string match -r -g '"version"\s*:\s*"([^"]+)"')
    test -n "$plugin"; or set plugin unavailable

    # --- 5. Summary ---------------------------------------------------------------
    # A stable version is only numbers (e.g. 0.10.3). Anything else (0.11.0-rc1,
    # dev builds, ...) is marked as a prerelease, which hs-update refuses to
    # install without --force.
    set -l latest_note ''
    if not string match -qr '^\d+\.\d+\.\d+$' -- $latest
        set latest_note ' (prerelease?)'
    end

    echo "Hindsight server (running) : $current"
    echo "Hindsight server (latest)  : $latest$latest_note"
    echo "Coding-agent plugin (npm)  : $plugin  (installed when an agent sandbox is created)"
    echo

    if test "$current" = "$latest"
        echo "The server is up to date."
    else
        echo "An update is available: $current -> $latest (run hs-update)"
    end
end
