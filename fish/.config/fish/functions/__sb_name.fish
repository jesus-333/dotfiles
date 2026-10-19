function __sb_name --description 'Valid sandbox name for <dir> <agent>: lowercase, only a-z 0-9 -'
    set -l base (string lower -- (basename $argv[1]))
    set base (string replace -ra -- '[^a-z0-9-]+' '-' $base)   # _ . spaces … → -
    set base (string trim -c '-' -- $base)
    echo $base-$argv[2]
end
