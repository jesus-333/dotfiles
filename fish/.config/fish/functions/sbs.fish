# sbs — Save the conversation history (sessions) of an agent sandbox.
#
# Usage:  sbs claude|codex|pi [dir]
#
# Why: the agent keeps its sessions in its home directory inside the sandbox
# (/home/agent), which is destroyed together with the sandbox. The workspace
# folder, instead, is a host folder mounted into the sandbox, so it survives.
# This function copies the sessions into <dir>/.agent-sessions/<agent>/, where
# they can be restored later with `sbr` into a recreated sandbox.

function sbs --description 'Save agent sessions of sandbox <agent> [dir] into <dir>/.agent-sessions/<agent>'
    # --- 1. Parse options ----------------------------------------------------
    # argparse removes recognised flags from $argv and sets $_flag_help if
    # -h or --help was given. Unknown flags make argparse fail with an error.
    argparse h/help -- $argv; or return 1

    if set -q _flag_help
        echo "usage: sbs claude|codex|pi [dir]"
        echo
        echo "Save the agent sessions of the sandbox for <dir> (default: current folder)"
        echo "into <dir>/.agent-sessions/<agent>/, so they survive deleting the sandbox."
        echo "Restore them later with: sbr <agent> [dir]"
        return 0
    end

    # --- 2. Validate the agent -------------------------------------------------
    # The first positional argument must be one of the three supported agents.
    set -l agent $argv[1]
    if not contains -- "$agent" claude codex pi
        echo "usage: sbs claude|codex|pi [dir]   (sbs --help for details)" >&2
        return 1
    end

    # --- 3. Resolve the workspace folder and the sandbox name -----------------
    # The folder defaults to the current directory. realpath turns it into an
    # absolute path, which matters because the same path is used inside the
    # sandbox (the workspace is mounted at the same absolute path).
    set -l dir (realpath (test -n "$argv[2]"; and echo $argv[2]; or echo .))

    # __sb_name builds the same sanitised name that `sb` uses (<folder>-<agent>,
    # lowercase, only a-z 0-9 -), so we target exactly the sandbox `sb` created.
    set -l name (__sb_name $dir $agent)

    # --- 4. Check that the sandbox exists -------------------------------------
    # `sbx ls` prints one sandbox per line, starting with its name. The regex
    # "^name\s" matches the name exactly (not e.g. "name-old").
    if not sbx ls 2>/dev/null | string match -qr "^$name\s"
        echo "sbs: no sandbox named $name" >&2
        return 1
    end

    # --- 5. Copy the sessions from inside the sandbox -------------------------
    # `sbx exec <name> -- sh -c '<script>' sh <arg1> <arg2>` runs a POSIX shell
    # script inside the sandbox. The extra "sh" becomes $0 of the script, so
    # $dir and $agent arrive as $1 and $2. Passing them as arguments (instead
    # of pasting them into the script text) avoids quoting problems with paths.
    #
    # Inside the script:
    #   set -e        stop at the first failing command
    #   dst=...       destination: <workspace>/.agent-sessions/<agent>
    #   rm -rf/mkdir  start from an empty destination, so an old backup never
    #                 mixes with the new one
    #   cd /home/agent  the home directory of the agent user in the sandbox
    #   for d in ...  the session folders of the three agents:
    #                   .claude/projects     Claude Code (one subfolder per cwd)
    #                   .codex/sessions      Codex (YYYY/MM/DD/rollout-*.jsonl)
    #                   .pi/agent/sessions   Pi
    #                 only the ones that exist are copied; the parent path is
    #                 recreated (mkdir -p dirname) so the layout mirrors $HOME,
    #                 which makes the restore a plain copy back into $HOME
    #   cp -a         copy recursively, keeping timestamps and permissions
    sbx exec $name -- sh -c '
        set -e
        dst="$1/.agent-sessions/$2"
        rm -rf "$dst"
        mkdir -p "$dst"
        cd /home/agent
        for d in .claude/projects .codex/sessions .pi/agent/sessions; do
            if [ -d "$d" ]; then
                mkdir -p "$dst/$(dirname "$d")"
                cp -a "$d" "$dst/$(dirname "$d")/"
            fi
        done' sh $dir $agent; or return 1

    # --- 6. Verify on the host -------------------------------------------------
    # If the workspace were mounted at a different path inside the sandbox, the
    # copy would land somewhere the host cannot see. Checking here turns that
    # silent failure into an explicit error before you delete the sandbox.
    if not test -d $dir/.agent-sessions/$agent
        echo "sbs: backup not visible on host at $dir/.agent-sessions/$agent" >&2
        return 1
    end

    # --- 7. Keep the backup out of git ----------------------------------------
    # If the folder is a git repo, add .agent-sessions/ to .git/info/exclude.
    # That file works like .gitignore but is local and never committed, so the
    # shared .gitignore stays untouched. grep -qxF checks for the exact line, so
    # running sbs repeatedly does not add duplicates.
    if test -d $dir/.git
        grep -qxF '.agent-sessions/' $dir/.git/info/exclude 2>/dev/null
        or echo '.agent-sessions/' >> $dir/.git/info/exclude
    end

    echo "saved: $dir/.agent-sessions/$agent"
end
