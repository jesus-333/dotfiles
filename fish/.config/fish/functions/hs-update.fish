# hs-update — Update the Hindsight server to the latest version published on
# ghcr.io, with a mandatory backup first.
#
# Usage:  hs-update [-y|--yes] [-f|--force]
#
# Why: the Hindsight server runs as the Docker container "hindsight" inside the
# sbx sandbox "hindsight", and it is managed by Docker Compose. Updating it by
# hand means several commands across two layers, and forgetting the backup is
# dangerous: Hindsight runs database migrations when it boots, and they cannot
# be undone. This function does all the steps in order:
#   1. make sure Hindsight is running (hs-up)
#   2. read the running version and pull :latest to read the newest version
#   3. stop if they are the same, or if :latest looks like a prerelease
#   4. ask for confirmation
#   5. back up the data with hs-backup (always, it cannot be skipped)
#   6. find docker-compose.yml from the container labels, back it up and pin
#      the image to the exact new version (ghcr.io/vectorize-io/hindsight:X.Y.Z)
#   7. recreate the container with docker compose up -d
#   8. wait until the API answers on localhost:8888/health
#
# Particular aspects of this setup:
#   compose file  it lives inside the sandbox (probably /home/agent/hindsight),
#                 but the path is never hardcoded: Docker Compose stores the
#                 project folder, the file(s) and the project name as labels
#                 on the container, and they are read from there.
#   pinning       after an update the compose file names an exact version,
#                 not :latest, so a restart never upgrades by surprise.
#                 hs-version keeps comparing against a freshly pulled :latest.
#   no rollback   if the new version does not start, nothing is undone
#                 automatically: the migrations may already have changed the
#                 data, so the old image alone could fail on it. The commands
#                 to restore the old compose file are printed instead.
#   plugin        the coding-agent plugin is not updated here: the
#                 hindsight-memory kit installs the latest one when an agent
#                 sandbox is created (sbk + sb).

function hs-update --description 'Back up and update the Hindsight server to the latest version'
    # --- 1. Parse options ------------------------------------------------------
    # argparse removes recognised flags from $argv and sets $_flag_help,
    # $_flag_yes and $_flag_force. Unknown flags make argparse fail.
    argparse h/help y/yes f/force -- $argv; or return 1

    if set -q _flag_help
        echo "usage: hs-update [-y|--yes] [-f|--force]"
        echo
        echo "Pull ghcr.io/vectorize-io/hindsight:latest and, if it is newer than the"
        echo "running server, back up the data (hs-backup), pin the new version in"
        echo "docker-compose.yml and recreate the container."
        echo
        echo "  -y, --yes     do not ask for confirmation (the backup is still done)"
        echo "  -f, --force   install :latest even if it looks like a prerelease"
        return 0
    end

    # Names used below, kept in one place.
    set -l repo ghcr.io/vectorize-io/hindsight
    set -l label '{{index .Config.Labels "org.opencontainers.image.version"}}'

    # --- 2. Make sure Hindsight is running -----------------------------------------
    # hs-up starts the sandbox and the container if needed, and fails if the
    # sandbox does not exist. The container labels read below need it.
    hs-up; or return 1

    # --- 3. Running version and latest version ----------------------------------
    set -l current (sbx exec hindsight -- docker inspect hindsight --format $label 2>/dev/null)
    if test -z "$current"
        echo "hs-update: could not read the version of the 'hindsight' container" >&2
        return 1
    end

    # Pulling only downloads the image: the running container is not touched.
    echo "hs-update: pulling $repo:latest ..." >&2
    if not sbx exec hindsight -- docker pull -q $repo:latest >/dev/null
        echo "hs-update: could not pull $repo:latest" >&2
        return 1
    end
    set -l latest (sbx exec hindsight -- docker image inspect $repo:latest --format $label 2>/dev/null)
    if test -z "$latest"
        echo "hs-update: could not read the version of $repo:latest" >&2
        return 1
    end

    # --- 4. Anything to do? ---------------------------------------------------------
    if test "$current" = "$latest"
        echo "hs-update: Hindsight is already up to date ($current)"
        return 0
    end

    # A stable version is only numbers (e.g. 0.10.3). If :latest is something
    # else (0.11.0-rc1, a dev build, ...) stop, unless --force is given.
    if not string match -qr '^\d+\.\d+\.\d+$' -- $latest
        and not set -q _flag_force
        echo "hs-update: :latest is $latest, which looks like a prerelease" >&2
        echo "Use hs-update --force to install it anyway." >&2
        return 1
    end

    # --- 5. Confirmation ------------------------------------------------------------
    # read -P shows the prompt; the answer goes in $answer. Anything that is
    # not y/yes (case insensitive) cancels, so pressing Enter means "no".
    if not set -q _flag_yes
        read -l -P "Update Hindsight $current -> $latest? A backup is made first. [y/N] " answer
        if not string match -qir '^y(es)?$' -- $answer
            echo "hs-update: cancelled"
            return 1
        end
    end

    # --- 6. Find the compose file ---------------------------------------------------
    # Docker Compose writes these labels on every container it creates:
    #   project.working_dir   the folder of the project
    #   project.config_files  the compose file(s), comma separated
    #   project               the project name (needed so `up` recreates the
    #                         same container instead of creating a new project)
    # This is done BEFORE the backup, so that a container not managed by
    # compose is detected without stopping anything.
    set -l compose_label '{{index .Config.Labels "com.docker.compose.project.working_dir"}}|{{index .Config.Labels "com.docker.compose.project.config_files"}}|{{index .Config.Labels "com.docker.compose.project"}}'
    set -l parts (sbx exec hindsight -- docker inspect hindsight --format $compose_label 2>/dev/null | string split '|')
    set -l workdir $parts[1]
    set -l files (string split ',' -- $parts[2])
    set -l project $parts[3]

    if test -z "$workdir"; or test -z "$files[1]"; or test -z "$project"
        echo "hs-update: the 'hindsight' container has no Docker Compose labels" >&2
        echo "Is it still managed with docker compose?" >&2
        return 1
    end
    # Only one compose file is expected. With more, the image line could be in
    # any of them, so stop instead of guessing.
    if test (count $files) -gt 1
        echo "hs-update: the project uses several compose files, expected one:" >&2
        printf '  %s\n' $files >&2
        return 1
    end
    set -l compose_file $files[1]

    # --- 7. Back up the data (mandatory) ----------------------------------------
    # hs-backup stops the container, archives the hindsight-data volume to
    # ~/sbx-hindsight/backups and starts the container again.
    echo "hs-update: backing up the data ..." >&2
    if not hs-backup
        echo "hs-update: backup failed, nothing was updated" >&2
        return 1
    end

    # --- 8. Back up the compose file and pin the new version --------------------
    # cp -p keeps permissions and dates. The backup stays next to the original.
    set -l compose_backup $compose_file.bak-(date +%Y%m%d-%H%M%S)
    if not sbx exec hindsight -- cp -p $compose_file $compose_backup
        echo "hs-update: could not back up $compose_file" >&2
        return 1
    end

    # sed -E (extended regex) replaces the image reference, with any tag or
    # with no tag at all, by the exact new version. The tag is everything up
    # to a quote or a space, so quoted and unquoted image: lines both work.
    # '#' is used as separator because the image name contains '/'.
    set -l sed_expr 's#'(string escape --style=regex $repo)'(:[^"\'[:space:]]*)?#'$repo:$latest'#'
    sbx exec hindsight -- sed -i -E $sed_expr $compose_file

    # Check that the pinned line is really there (grep -F = literal text). If
    # not, the image line has an unexpected format: restore and stop.
    if not sbx exec hindsight -- grep -qF $repo:$latest $compose_file
        echo "hs-update: could not pin the image in $compose_file, restoring it" >&2
        sbx exec hindsight -- cp -p $compose_backup $compose_file
        return 1
    end
    echo "hs-update: pinned $repo:$latest in $compose_file" >&2

    # --- 9. Recreate the container ----------------------------------------------
    # -p, --project-directory and -f repeat exactly what compose recorded, so
    # the same project is updated. up -d recreates only the containers whose
    # configuration changed (here: the image) and returns immediately.
    if not sbx exec hindsight -- docker compose -p $project --project-directory $workdir -f $compose_file up -d
        echo "hs-update: docker compose up failed" >&2
        echo "Old compose file: $compose_backup" >&2
        return 1
    end

    # --- 10. Wait for the API ---------------------------------------------------
    # The first boot of a new version runs the migrations, so it can take
    # longer than a normal start: wait up to 180 s.
    echo "hs-update: waiting for Hindsight on localhost:8888 ..." >&2
    set -l healthy 0
    for i in (seq 180)
        if curl -fsS --max-time 2 http://localhost:8888/health >/dev/null 2>&1
            set healthy 1
            break
        end
        sleep 1
    end

    if test $healthy -eq 0
        echo "hs-update: Hindsight did not answer within 180 s" >&2
        echo "Check the logs:   sbx exec hindsight docker logs hindsight" >&2
        echo "To go back, restore the compose file AND the data backup (the migrations" >&2
        echo "may already have changed the data):" >&2
        echo "  sbx exec hindsight cp -p $compose_backup $compose_file" >&2
        echo "  latest data backup: ~/sbx-hindsight/backups/" >&2
        return 1
    end

    # --- 11. Done ---------------------------------------------------------------
    set -l now (sbx exec hindsight -- docker inspect hindsight --format $label 2>/dev/null)
    echo "hs-update: Hindsight updated $current -> $now"
    echo "Agent sandboxes get the latest plugin when they are recreated (sbk + sb)."
end
