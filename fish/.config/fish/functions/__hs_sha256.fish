# __hs_sha256 — Private helper of hs-backup / hs-restore: print the SHA-256 of
# a file (only the hex digest).
#
# Usage:  set -l sum (__hs_sha256 <file>)
#
# Why: macOS has `shasum -a 256`, most Linux systems `sha256sum`. Using
# whichever exists keeps the backups checkable on both.

function __hs_sha256 --description 'Print the SHA-256 hex digest of a file'
    # Both tools print "<digest>  <file>": string split keeps the first word.
    if type -q sha256sum
        sha256sum $argv[1] | string split -f1 ' '
    else if type -q shasum
        shasum -a 256 $argv[1] | string split -f1 ' '
    else
        echo "__hs_sha256: neither sha256sum nor shasum is installed" >&2
        return 1
    end
end
