# sb — Start or re-attach a sandboxed coding agent (Docker sbx).
#
# Usage:  sb [-t | -n] claude|codex|pi [dir]
#
# Three kinds of sandbox, each with its own name, so they never collide even
# when they are opened on the same folder (see __sb_name):
#
#   sb claude       <folder>-claude        linked to the Hindsight memory bank:
#                                          the conversation ends up in long-term
#                                          memory. Refuses to start if the
#                                          Hindsight server is down.
#   sb -t claude    <folder>-claude-tmp    throwaway, NO memory: deleted as soon
#                                          as the agent exits. For quick jobs
#                                          (assess a codebase, summarise PDFs).
#   sb -n claude    <folder>-claude-nomem  NO memory, but kept: re-attach later
#                                          with the same command, delete it with
#                                          `sbk -n claude`. For work without
#                                          memory that spans several sittings.
#
# All of them get the base-tools kit (poppler-utils, WakaTime); only the first
# one also gets the hindsight-memory kit. Files written in [dir] are on the
# host, so they survive the deletion of any sandbox.

function sb --description 'Start or re-attach a sandboxed agent: sb [-t|-n] <claude|codex|pi> [dir]'
    # --- 1. Parse options ----------------------------------------------------
    # -x t,n: the two flags are mutually exclusive (argparse errors out).
    argparse -x t,n h/help t/tmp n/nomem -- $argv; or return 1

    if set -q _flag_help
        echo "usage: sb [-t | -n] claude|codex|pi [dir]"
        echo
        echo "Start (or re-attach) an agent sandbox on [dir] (default: current folder)."
        echo "  (no flag)    linked to Hindsight memory           -> <folder>-<agent>"
        echo "  -t, --tmp    no memory, deleted when agent exits  -> <folder>-<agent>-tmp"
        echo "  -n, --nomem  no memory, kept (delete: sbk -n)     -> <folder>-<agent>-nomem"
        echo
        echo "Settings: SB_CPUS (4), SB_MEMORY (6g), SBX_KITS (~/sbx-hindsight/kits), SB_PI_KIT"
        return 0
    end

    # --- 2. Arguments --------------------------------------------------------
    if not set -q argv[1]
        echo "usage: sb [-t | -n] claude|codex|pi [dir]   (sb --help for details)" >&2
        return 1
    end
    set -l agent $argv[1]
    if not contains -- $agent claude codex pi
        echo "sb: unknown agent '$agent' (use claude, codex or pi)" >&2
        return 1
    end
    set -l dir $PWD
    if set -q argv[2]
        set dir (realpath $argv[2]); or return 1
    end
    set -l suffix (__sb_suffix "$_flag_tmp" "$_flag_nomem")
    set -l name (__sb_name $dir $agent $suffix)

    # --- 3. Settings (override with: set -Ux SB_CPUS 2, set -Ux SB_MEMORY 4g, ...)
    set -l kits_dir ~/sbx-hindsight/kits
    set -q SBX_KITS; and set kits_dir $SBX_KITS
    set -l cpus 4
    set -q SB_CPUS; and set cpus $SB_CPUS
    set -l mem 6g
    set -q SB_MEMORY; and set mem $SB_MEMORY
    # Community kit for pi with ChatGPT OAuth (upstream avatsav: the rocknitive fork
    # is not publicly pullable from GHCR); pin a version once you have tested one
    # TODO: if sbx ever ships pi as a built-in agent (check `sbx run --help`), drop
    # the kit: remove pi_kit/SB_PI_KIT and the workload swap below, so pi is passed
    # to sbx create like claude and codex.
    set -l pi_kit ghcr.io/avatsav/pi-kit:latest
    set -q SB_PI_KIT; and set pi_kit $SB_PI_KIT

    # --- 4. Kits, and the memory server check (memory sandboxes only) ---------
    # base-tools for everyone; hindsight-memory only without -t / -n. Without
    # memory the Hindsight server is not needed, so it is not started/checked.
    set -l kits --kit $kits_dir/base-tools
    if test -z "$suffix"
        if not hs-up
            echo "sb: Hindsight is not running, agent NOT started." >&2
            echo "    Check with: sbx ls   and   sbx exec hindsight -- docker logs --tail 50 hindsight" >&2
            echo "    Or start without memory: sb -t $agent (throwaway) / sb -n $agent (kept)" >&2
            return 1
        end
        set -a kits --kit $kits_dir/hindsight-memory
    end

    # --- 5. The agent: built-in for claude/codex, kit image for pi ------------
    set -l workload $agent
    test "$agent" = pi; and set workload $pi_kit

    # --- 6. Create the sandbox if needed --------------------------------------
    # New sandbox: create it (kit installs run here) and add the WakaTime key.
    # Existing sandbox: skip straight to attaching.
    # `created` remembers whether THIS call made the sandbox: a -t sandbox is
    # deleted on exit only in that case (see step 8).
    set -l created 0
    if not sbx ls 2>/dev/null | string match -qr "^$name\s"
        sbx create --name $name --cpus $cpus --memory $mem \
            $kits $workload $dir; or return 1
        __sbx_wakatime $name
        set created 1
    else if test "$suffix" = tmp
        # Either another terminal is using it, or a previous `sb -t` was
        # interrupted before its cleanup. Deleting it on exit could kill the
        # other terminal's session, so attach and leave it alone.
        echo "sb: $name already exists (open in another terminal, or left over)." >&2
        echo "    Attaching; it will NOT be deleted on exit. Delete it with: sbk -t $agent $dir" >&2
    end

    # --- 7. Attach ------------------------------------------------------------
    sbx run --name $name
    set -l run_status $status

    # --- 8. Throwaway sandbox: delete it once the agent exits -----------------
    if test "$suffix" = tmp -a $created -eq 1
        echo "sb: deleting throwaway sandbox $name"
        sbx rm -f $name
    end
    return $run_status
end
