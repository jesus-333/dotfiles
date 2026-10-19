function texc --description 'Compile LaTeX with sandbox-safe settings (file or folder)'
    if test (count $argv) -lt 1
        echo "usage: texc FILE.tex|FOLDER [extra latexmk args]"
        return 1
    end
    set -l target $argv[1]
    set -l extra $argv[2..-1]

    if test -d $target
        # .tex files with an uncommented \documentclass
        set -l mains (grep -rlE --include='*.tex' '^[^%]*\\\\documentclass' $target | sort)
        switch (count $mains)
            case 0
                echo "no main .tex file found in $target"
                return 1
            case 1
                set target $mains[1]
            case '*'
                for i in (seq (count $mains))
                    echo "  [$i] $mains[$i]"
                end
                read -l -P "select file: " n
                if not string match -qr '^[0-9]+$' -- $n; or test $n -lt 1 -o $n -gt (count $mains)
                    echo "invalid choice"
                    return 1
                end
                set target $mains[$n]
        end
    end

    echo "compiling $target"
    env shell_escape=f openin_any=p openout_any=p \
        latexmk -norc -pdf -cd -interaction=nonstopmode -file-line-error $extra $target
end
