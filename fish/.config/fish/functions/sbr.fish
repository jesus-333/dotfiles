# sbr — Restore the conversation history (sessions) saved by `sbs` into a
# (re)created agent sandbox.
#
# Usage:  sbr claude|codex|pi [dir]
#
# Typical flow when a sandbox has to be recreated (e.g. after a kit update):
#   sbs claude [dir]   save sessions
#   sbk claude [dir]   delete the sandbox
#   sb  claude [dir]   recreate it
#   sbr claude [dir]   restore sessions (from a second terminal)
# then resume inside the agent: claude --resume | codex resume | pi --resume

function sbr --description 'Restore agent sessions from <dir>/.agent-sessions/<agent> into sandbox <agent> [dir]'
    # --- 1. Parse options ----------------------------------------------------
    # Same as in sbs: argparse handles -h/--help and rejects unknown flags.
    argparse h/help -- $argv; or return 1

    if set -q _flag_help
        echo "usage: sbr claude|codex|pi [dir]"
        echo
        echo "Copy the sessions saved by 'sbs' from <dir>/.agent-sessions/<agent>/"
        echo "back into the sandbox for <dir> (default: current folder)."
        echo "The sandbox must already exist (create it with: sb <agent> [dir])."
        echo "Afterwards resume with: claude --resume | codex resume | pi --resume"
        return 0
    end

    # --- 2. Validate the agent -------------------------------------------------
    set -l agent $argv[1]
    if not contains -- "$agent" claude codex pi
        echo "usage: sbr claude|codex|pi [dir]   (sbr --help for details)" >&2
        return 1
    end

    # --- 3. Resolve the workspace folder and the sandbox name -----------------
    # Same logic as sbs/sb: absolute path of [dir] (default: current folder)
    # and the sanitised sandbox name <folder>-<agent>.
    set -l dir (realpath (test -n "$argv[2]"; and echo $argv[2]; or echo .))
    set -l name (__sb_name $dir $agent)

    # --- 4. Check that there is something to restore --------------------------
    if not test -d $dir/.agent-sessions/$agent
        echo "sbr: no backup at $dir/.agent-sessions/$agent" >&2
        return 1
    end

    # --- 5. Check that the target sandbox exists ------------------------------
    # sbr does not create sandboxes: creation goes through `sb`, so that the
    # kits (Hindsight, WakaTime) and resources are applied consistently.
    if not sbx ls 2>/dev/null | string match -qr "^$name\s"
        echo "sbr: no sandbox named $name (create it with: sb $agent $dir)" >&2
        return 1
    end

    # --- 6. Copy the sessions back into the sandbox ---------------------------
    # As in sbs, the script runs inside the sandbox with $1 = dir, $2 = agent.
    #
    # Inside the script:
    #   set -e        stop at the first failing command
    #   cp -a src/. /home/agent/
    #                 the backup mirrors the layout of $HOME (.claude/projects,
    #                 .codex/sessions, .pi/agent/sessions), so copying its
    #                 contents ("/." = contents, not the folder itself) into
    #                 /home/agent puts every file back where the agent expects
    #                 it; existing files with the same name are overwritten,
    #                 other files in $HOME are left alone
    #   chown -R 1000:1000
    #                 sbx exec may run as root, so the copied files could end up
    #                 owned by root and be unreadable/unwritable for the agent
    #                 (uid 1000). Same precaution as in __sbx_wakatime. Errors
    #                 are ignored ("|| true") because a missing folder or an
    #                 already-correct owner is not a problem.
    sbx exec $name -- sh -c '
        set -e
        cp -a "$1/.agent-sessions/$2/." /home/agent/
        for d in .claude .codex .pi; do
            [ -d "/home/agent/$d" ] && chown -R 1000:1000 "/home/agent/$d" 2>/dev/null || true
        done' sh $dir $agent; or return 1

    echo "restored into $name; resume with: claude --resume | codex resume | pi --resume"
end
